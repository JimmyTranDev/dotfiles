// Dependency-injected orchestration core for the zellij-tab-status plugin.
// Every real side effect (fs state files, render locks, `zellij action` calls,
// timers, pid liveness, exit hooks) is injected via `io`, so the full
// transition logic runs in-memory under `node --test`. The thin adapter in
// plugins/zellij-tab-status.js supplies the real `io`.
//
// One opencode pane owns one createTabStatus. It caches a single tab id (the
// tab focused when this pane first started working) and drives that tab's emoji
// badge through processing -> done/idle as turns start and end. A tab can be
// shared by several panes, so the rendered badge is always the live aggregate
// of every pane's status, never just this pane's.

import {
  activeTab,
  desiredName,
  eventToTransition,
  findTab,
  isTabActive,
  resolveTurnEnd,
} from "./zellij-tab-status.mjs"

// `io` contract:
//   pid                    this pane's process id (its state-file owner)
//   pollMs                 focus-poll interval, ms
//   isAlive(pid) -> bool   is a pane process still running
//   readEntries(tabId)     -> [{ pid, status }] for the tab's state dir
//   writeStatus(tabId, s)  persist this pane's status under the tab
//   finalize(tabId)        remove this pane's state file (exit cleanup)
//   listTabs() -> tabs|null parsed `zellij action list-tabs --json`
//   renameTab(tabId, name) `zellij action rename-tab-by-id`
//   withLock(tabId, fn)    run fn holding the tab's render lock
//   startPoll(fn, ms) -> h start a repeating focus poll, returns a handle
//   stopPoll(handle)       cancel a focus poll
//   onExit(fn)             register a process-exit cleanup hook
export const createTabStatus = (io) => {
  let tabId = null
  let pollHandle = null

  const stopPoll = () => {
    if (pollHandle == null) return
    io.stopPoll(pollHandle)
    pollHandle = null
  }

  const armPoll = () => {
    if (pollHandle != null) return
    pollHandle = io.startPoll(pollTick, io.pollMs)
  }

  // Cache the tab this pane belongs to the first time it starts working. A
  // just-submitted turn means the user is looking at this pane, so the active
  // tab is ours. Returns false when zellij can't be reached.
  const ensureTabId = async () => {
    if (tabId != null) return true
    const active = activeTab(await io.listTabs())
    if (!active) return false
    tabId = active.tab_id
    return true
  }

  // Re-render our tab's name from the live aggregate of its panes, renaming
  // only when the badge actually changes (so a tab kept 🤖 by a sibling pane is
  // never needlessly renamed). Always runs under the tab's render lock.
  const render = async () => {
    await io.withLock(tabId, async () => {
      const tab = findTab(await io.listTabs(), tabId)
      if (!tab) return
      const next = desiredName(tab.name, io.readEntries(tabId), io.isAlive)
      if (next !== tab.name) await io.renameTab(tabId, next)
    })
  }

  // A turn started: badge this tab 🤖 and cancel any pending done-poll.
  const goProcessing = async () => {
    if (!(await ensureTabId())) return
    stopPoll()
    io.writeStatus(tabId, "processing")
    await render()
  }

  // A turn ended: if we were watching, it resolves straight to idle; otherwise
  // it shows ✅ and we poll until the user looks at the tab.
  const goTurnEnded = async () => {
    if (tabId == null) return
    const status = resolveTurnEnd(isTabActive(await io.listTabs(), tabId))
    io.writeStatus(tabId, status)
    await render()
    if (status === "done") armPoll()
  }

  // While a ✅ is pending: once the user focuses the tab, clear it to idle and
  // stop polling; otherwise keep waiting.
  const pollTick = async () => {
    if (tabId == null) return
    if (!isTabActive(await io.listTabs(), tabId)) return
    io.writeStatus(tabId, "idle")
    await render()
    stopPoll()
  }

  // On pane exit, drop our state file so a closed pane never leaves a stuck
  // badge, and cancel any poll timer.
  io.onExit(() => {
    if (tabId != null) io.finalize(tabId)
    stopPoll()
  })

  return {
    "chat.message": () => goProcessing(),
    event: (input) => {
      const transition = eventToTransition(input?.event)
      if (transition === "processing") return goProcessing()
      if (transition === "turn-ended") return goTurnEnded()
      return undefined
    },
  }
}
