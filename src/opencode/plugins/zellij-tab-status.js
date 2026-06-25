import fs from "node:fs"
import path from "node:path"
import { execFileSync } from "node:child_process"

import { STATE_DIR, parseStateEntries, findTab, desiredName } from "../lib/zellij-tab-status.mjs"
import { createTabStatus } from "../lib/zellij-tab-status-core.mjs"

// Surface each opencode session's processing state as a glyph suffix on its
// zellij TAB name (⚙ working, ✓ finished-while-you-were-away, none when idle) —
// the tab-level companion to zellij-pane-status.js. All transition logic lives
// in the unit-tested core (lib/zellij-tab-status-core.mjs); this adapter only
// supplies real I/O: per-pane state files at STATE_DIR/<tab_id>/<pid>, a
// portable mkdir render lock, `zellij action` calls, a focus poll, and exit
// cleanup. No-op outside zellij.
export const ZellijTabStatus = async ({ $ }) => {
  if (!process.env.ZELLIJ) {
    return {}
  }

  const pid = process.pid
  const pollMs = Number(process.env.OPENCODE_ZELLIJ_POLL_MS) || 250
  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

  const dirFor = (tabId) => path.join(STATE_DIR, String(tabId))
  const fileFor = (tabId) => path.join(dirFor(tabId), String(pid))

  // Is a pane process still running? ESRCH -> gone; EPERM -> alive but not ours
  // to signal. Lets a render prune crashed panes' stale badges.
  const isAlive = (probePid) => {
    try {
      process.kill(probePid, 0)
      return true
    } catch (err) {
      return Boolean(err) && err.code === "EPERM"
    }
  }

  // Read every pane's status file in this tab's state dir. Dot-prefixed names
  // (the lock dir, temp files) are skipped; parseStateEntries drops anything
  // that isn't a live <pid> file with a known status.
  const readEntries = (tabId) => {
    try {
      const dir = dirFor(tabId)
      const files = fs
        .readdirSync(dir)
        .filter((name) => !name.startsWith("."))
        .map((name) => {
          try {
            return { name, content: fs.readFileSync(path.join(dir, name), "utf8") }
          } catch {
            return { name, content: "" }
          }
        })
      return parseStateEntries(files)
    } catch {
      return []
    }
  }

  // Persist this pane's status atomically (temp write + rename) so a concurrent
  // reader never sees a half-written file.
  const writeStatus = (tabId, status) => {
    try {
      const dir = dirFor(tabId)
      fs.mkdirSync(dir, { recursive: true })
      const tmp = path.join(dir, `.${pid}.tmp`)
      fs.writeFileSync(tmp, status)
      fs.renameSync(tmp, fileFor(tabId))
    } catch {
      // best-effort; a missing state file just means no badge contribution
    }
  }

  // Synchronous re-render for exit cleanup (a process 'exit' handler can't
  // await): drop our badge contribution at once so a closed solo pane leaves no
  // stuck glyph. Bounded timeouts keep shutdown from hanging on a slow zellij.
  const syncRender = (tabId) => {
    let tabs
    try {
      const out = execFileSync("zellij", ["action", "list-tabs", "--json"], {
        encoding: "utf8",
        timeout: 1000,
      })
      tabs = JSON.parse(out)
    } catch {
      return
    }
    const tab = findTab(tabs, tabId)
    if (!tab) {
      return
    }
    const next = desiredName(tab.name, readEntries(tabId), isAlive)
    if (next !== tab.name) {
      try {
        execFileSync("zellij", ["action", "rename-tab-by-id", String(tabId), next], { timeout: 1000 })
      } catch {
        // tab gone or zellij unreachable during teardown — nothing to do
      }
    }
  }

  // Remove this pane's state file and clear its badge contribution on exit.
  const finalize = (tabId) => {
    try {
      fs.rmSync(fileFor(tabId), { force: true })
    } catch {}
    try {
      syncRender(tabId)
    } catch {}
  }

  const listTabs = async () => {
    try {
      const out = await $`zellij action list-tabs --json`.nothrow().quiet()
      if (out.exitCode !== 0) {
        return null
      }
      return out.json()
    } catch {
      return null
    }
  }

  const renameTab = async (tabId, name) => {
    try {
      await $`zellij action rename-tab-by-id ${tabId} ${name}`.nothrow().quiet()
    } catch {
      // zellij unreachable (e.g. detached session) — ignore
    }
  }

  // Serialize a tab's renders across its panes with a portable mkdir lock
  // (macOS has no flock(1)). A lock older than 2s is treated as orphaned by a
  // crashed renderer and stolen; after ~1s of contention we proceed unlocked
  // rather than deadlock.
  const withLock = async (tabId, fn) => {
    const lock = path.join(dirFor(tabId), ".lock")
    try {
      fs.mkdirSync(dirFor(tabId), { recursive: true })
    } catch {}
    let held = false
    for (let attempt = 0; attempt < 50; attempt++) {
      try {
        fs.mkdirSync(lock)
        held = true
        break
      } catch {
        try {
          if (Date.now() - fs.statSync(lock).mtimeMs > 2000) {
            fs.rmSync(lock, { recursive: true, force: true })
            continue
          }
        } catch {}
        await sleep(20)
      }
    }
    try {
      return await fn()
    } finally {
      if (held) {
        try {
          fs.rmSync(lock, { recursive: true, force: true })
        } catch {}
      }
    }
  }

  // setInterval-based focus poll, unref'd so a pending ✓ never keeps opencode
  // alive on its own.
  const startPoll = (fn, ms) => {
    const handle = setInterval(() => {
      Promise.resolve(fn()).catch(() => {})
    }, ms)
    if (typeof handle.unref === "function") {
      handle.unref()
    }
    return handle
  }

  const stopPoll = (handle) => {
    clearInterval(handle)
  }

  const onExit = (fn) => {
    process.once("exit", fn)
  }

  return createTabStatus({
    pid,
    pollMs,
    isAlive,
    readEntries,
    writeStatus,
    finalize,
    listTabs,
    renameTab,
    withLock,
    startPoll,
    stopPoll,
    onExit,
  })
}
