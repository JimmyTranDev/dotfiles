// ==UserScript==
// @name         Single Active Tab
// @namespace    https://github.com/JimmyTranDev/dotfiles
// @version      1.0.0
// @description  Keep only one tab of a site active at a time. Later duplicate tabs of the same origin are blocked behind an overlay until you switch to the active tab or take over.
// @author       Jimmy Tran
// @match        *://*/*
// @run-at       document-start
// @grant        none
// @license      MIT
// @noframes
// ==/UserScript==

/*
 * Single Active Tab
 * =================
 * Enforces that, per origin (scheme + host + port), only ONE browser tab is the
 * "active" owner. The first tab to claim an origin owns it; any later tab of the
 * same origin is treated as a duplicate and covered with a full-page overlay.
 *
 * Why an overlay instead of auto-closing the tab: browsers block
 * `window.close()` for tabs the script did not open, so reliably closing a
 * duplicate is impossible. Blocking it visibly is the honest, reversible option.
 *
 * Install:
 *   1. Install a userscript manager (Tampermonkey, Violentmonkey, Greasemonkey).
 *   2. Open this .user.js file in the browser so the manager offers to install
 *      it, or create a new script and paste these contents.
 *   3. Scope it via the CONFIG block below.
 *
 * Scope with CONFIG.MODE:
 *   'all'    - govern every site (default).
 *   'only'   - govern ONLY the hostnames in CONFIG.HOSTS.
 *   'except' - govern every site EXCEPT the hostnames in CONFIG.HOSTS.
 * A host entry also matches its subdomains: 'example.com' covers 'app.example.com'.
 */

(function () {
  'use strict';

  // ----- CONFIG -------------------------------------------------------------
  // Edit only this block to scope the script; the logic below never needs to change.
  const CONFIG = {
    MODE: 'all', // 'all' | 'only' | 'except'
    HOSTS: [
      // 'mail.google.com',
      // 'web.whatsapp.com',
    ],
  };

  // A freshly-opened tab waits this long for an existing owner to answer before
  // assuming it is the first tab and claiming ownership itself.
  const CLAIM_TIMEOUT_MS = 400;
  // The owner re-announces on this interval so duplicates can detect an owner
  // that was force-closed or crashed without sending a clean RELEASE.
  const HEARTBEAT_MS = 1000;
  // A duplicate promotes itself if it has heard nothing from the owner for this long.
  const OWNER_TIMEOUT_MS = 3000;

  // ----- host matching (pure) ----------------------------------------------
  // Decide whether the current hostname is governed. Kept pure so the scoping
  // rule is trivial to reason about and change.
  function isGoverned(hostname) {
    const inList = CONFIG.HOSTS.some(function (entry) {
      const host = String(entry).trim().toLowerCase().replace(/^\.+/, '');
      if (!host) return false;
      return hostname === host || hostname.endsWith('.' + host);
    });
    switch (CONFIG.MODE) {
      case 'only':
        return inList;
      case 'except':
        return !inList;
      case 'all':
      default:
        return true;
    }
  }

  if (!isGoverned(location.hostname)) return;

  // ----- identity & messaging ----------------------------------------------
  // Channel is per-origin so tabs of different sites never coordinate with each other.
  const CHANNEL = 'single-active-tab::' + location.origin;
  const TAB_ID = (function () {
    try {
      if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
    } catch (_) {
      /* crypto unavailable; fall through to a good-enough random id */
    }
    return 'tab-' + Date.now() + '-' + Math.random().toString(36).slice(2);
  })();

  const MSG = {
    PING: 'ping', // a new tab asking "is anyone the owner?"
    PONG: 'pong', // the owner replying "yes, me"
    HEARTBEAT: 'heartbeat', // the owner announcing it is still alive
    RELEASE: 'release', // the owner leaving cleanly
    TAKEOVER: 'takeover', // a duplicate seizing ownership on the user's request
    FOCUS_OWNER: 'focus-owner', // ask the owner tab to focus itself
  };

  // Transport: prefer BroadcastChannel; fall back to localStorage "storage"
  // events, which fire only in OTHER tabs of the same origin -- exactly the
  // cross-tab semantics we need. Both expose post() + onMessage().
  const bus = createBus();

  function createBus() {
    try {
      if (typeof BroadcastChannel === 'function') {
        const bc = new BroadcastChannel(CHANNEL);
        return {
          post: function (msg) {
            bc.postMessage(msg);
          },
          onMessage: function (cb) {
            bc.onmessage = function (event) {
              cb(event.data);
            };
          },
        };
      }
    } catch (_) {
      /* BroadcastChannel blocked/unavailable; use the storage fallback */
    }

    const KEY = CHANNEL;
    return {
      post: function (msg) {
        try {
          // The nonce forces a value change so repeated identical messages still
          // dispatch a storage event in the other tabs.
          localStorage.setItem(KEY, JSON.stringify({ msg: msg, nonce: Math.random() }));
        } catch (_) {
          /* storage unavailable (private mode / blocked); messaging degrades */
        }
      },
      onMessage: function (cb) {
        window.addEventListener('storage', function (event) {
          if (event.key !== KEY || !event.newValue) return;
          try {
            cb(JSON.parse(event.newValue).msg);
          } catch (_) {
            /* malformed payload; ignore */
          }
        });
      },
    };
  }

  function send(type) {
    bus.post({ type: type, from: TAB_ID, origin: location.origin });
  }

  // ----- state machine ------------------------------------------------------
  let isOwner = false;
  let lastOwnerSeen = 0;
  let heartbeatTimer = null;
  let ownerWatchTimer = null;
  let overlay = null;

  bus.onMessage(function (data) {
    // Ignore malformed payloads, other origins, and our own echoed messages.
    if (!data || data.origin !== location.origin || data.from === TAB_ID) return;

    switch (data.type) {
      case MSG.PING:
        // Only the owner answers, so a new tab learns whether an owner exists.
        if (isOwner) send(MSG.PONG);
        break;

      case MSG.PONG:
      case MSG.HEARTBEAT:
        lastOwnerSeen = Date.now();
        if (isOwner) {
          // Two owners (a race after a release). The lower tab id wins
          // deterministically so the split brain always converges.
          if (data.from < TAB_ID) becomeDuplicate();
        } else {
          showOverlay();
        }
        break;

      case MSG.TAKEOVER:
        // Another tab seized ownership at the user's request; yield to it.
        lastOwnerSeen = Date.now();
        becomeDuplicate();
        break;

      case MSG.RELEASE:
        // Owner left cleanly; a blocked duplicate can claim the origin now.
        if (!isOwner) claim();
        break;

      case MSG.FOCUS_OWNER:
        if (isOwner) {
          try {
            window.focus();
          } catch (_) {
            /* cross-tab focus is browser-limited; best effort only */
          }
        }
        break;
    }
  });

  function becomeOwner() {
    if (isOwner) return;
    isOwner = true;
    hideOverlay();
    stopOwnerWatch();
    startHeartbeat();
  }

  function becomeDuplicate() {
    isOwner = false;
    stopHeartbeat();
    showOverlay();
    startOwnerWatch();
  }

  // Election: announce ourselves, then wait briefly for an owner to answer.
  function claim() {
    const startedSeen = lastOwnerSeen;
    send(MSG.PING);
    setTimeout(function () {
      // If lastOwnerSeen never advanced, no owner answered -> we are first.
      if (!isOwner && lastOwnerSeen <= startedSeen) becomeOwner();
    }, CLAIM_TIMEOUT_MS);
  }

  function startHeartbeat() {
    stopHeartbeat();
    send(MSG.HEARTBEAT);
    heartbeatTimer = setInterval(function () {
      send(MSG.HEARTBEAT);
    }, HEARTBEAT_MS);
  }

  function stopHeartbeat() {
    if (heartbeatTimer) {
      clearInterval(heartbeatTimer);
      heartbeatTimer = null;
    }
  }

  // A duplicate watches for a silent owner (crash / force-close) and self-promotes.
  function startOwnerWatch() {
    stopOwnerWatch();
    ownerWatchTimer = setInterval(function () {
      if (Date.now() - lastOwnerSeen > OWNER_TIMEOUT_MS) claim();
    }, HEARTBEAT_MS);
  }

  function stopOwnerWatch() {
    if (ownerWatchTimer) {
      clearInterval(ownerWatchTimer);
      ownerWatchTimer = null;
    }
  }

  function takeOver() {
    send(MSG.TAKEOVER);
    becomeOwner();
  }

  // Leaving cleanly lets a waiting duplicate take over instantly.
  window.addEventListener('pagehide', function () {
    if (isOwner) send(MSG.RELEASE);
  });

  // ----- overlay UI (Catppuccin Mocha) -------------------------------------
  function showOverlay() {
    if (overlay || isOwner) return;

    const root = document.createElement('div');
    root.id = 'single-active-tab-overlay';
    // Inline styles only, so the page's own CSS cannot hide or restyle the block.
    Object.assign(root.style, {
      position: 'fixed',
      inset: '0',
      zIndex: '2147483647',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'rgba(17, 17, 27, 0.92)', // crust, dimmed
      backdropFilter: 'blur(4px)',
      webkitBackdropFilter: 'blur(4px)',
      fontFamily: 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
      color: '#cdd6f4', // text
    });

    const card = document.createElement('div');
    Object.assign(card.style, {
      maxWidth: '440px',
      width: 'calc(100% - 48px)',
      boxSizing: 'border-box',
      background: '#1e1e2e', // base
      border: '1px solid #313244', // surface0
      borderRadius: '16px',
      padding: '28px 28px 22px',
      boxShadow: '0 20px 60px rgba(0, 0, 0, 0.5)',
      textAlign: 'center',
    });

    const title = document.createElement('h1');
    title.textContent = 'This site is already open';
    Object.assign(title.style, {
      margin: '0 0 10px',
      fontSize: '20px',
      fontWeight: '600',
      color: '#f38ba8', // red
    });

    const message = document.createElement('p');
    message.textContent =
      'Another tab of ' +
      location.host +
      ' is active. Keeping a single tab open avoids duplicate sessions and conflicting state.';
    Object.assign(message.style, {
      margin: '0 0 22px',
      fontSize: '14px',
      lineHeight: '1.5',
      color: '#bac2de', // subtext1
    });

    const hint = document.createElement('p');
    Object.assign(hint.style, {
      margin: '16px 0 0',
      fontSize: '12px',
      minHeight: '1em',
      color: '#6c7086', // overlay0
    });

    const switchBtn = makeButton('Switch to the active tab', '#89b4fa', '#1e1e2e');
    switchBtn.addEventListener('click', function () {
      send(MSG.FOCUS_OWNER); // ask the owner tab to focus itself (best effort)
      try {
        window.close(); // usually blocked for user-opened tabs
      } catch (_) {
        /* ignore */
      }
      hint.textContent =
        'If nothing happened, your browser blocked tab switching - close this tab manually.';
    });

    const takeoverBtn = makeButton('Use this tab instead', 'transparent', '#cdd6f4', '#585b70');
    takeoverBtn.addEventListener('click', function () {
      takeOver();
    });

    const buttons = document.createElement('div');
    Object.assign(buttons.style, { display: 'flex', flexDirection: 'column', gap: '10px' });
    buttons.appendChild(switchBtn);
    buttons.appendChild(takeoverBtn);

    card.appendChild(title);
    card.appendChild(message);
    card.appendChild(buttons);
    card.appendChild(hint);
    root.appendChild(card);

    // documentElement exists at document-start even before <body> does.
    (document.body || document.documentElement).appendChild(root);
    overlay = root;

    // Stop the blocked page from scrolling underneath the overlay.
    try {
      document.documentElement.style.overflow = 'hidden';
    } catch (_) {
      /* ignore */
    }
  }

  function makeButton(label, background, color, border) {
    const button = document.createElement('button');
    button.textContent = label;
    Object.assign(button.style, {
      appearance: 'none',
      cursor: 'pointer',
      font: 'inherit',
      fontSize: '14px',
      fontWeight: '600',
      width: '100%',
      padding: '11px 16px',
      borderRadius: '10px',
      border: border ? '1px solid ' + border : 'none',
      background: background,
      color: color,
    });
    return button;
  }

  function hideOverlay() {
    if (overlay && overlay.parentNode) overlay.parentNode.removeChild(overlay);
    overlay = null;
    try {
      document.documentElement.style.overflow = '';
    } catch (_) {
      /* ignore */
    }
  }

  // ----- bootstrap ----------------------------------------------------------
  // Try to claim ownership; the overlay appears if an existing owner answers.
  claim();
})();
