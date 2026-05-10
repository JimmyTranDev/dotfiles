export const Notification = async ({ $ }) => {
  const platform = process.platform
  let needsAttention = false
  let taskStartTime = Date.now()

  let lastToolName = ""
  let toolCallCount = 0
  const changedFiles = new Set()
  let lastMessageText = ""
  let lastErrorDetail = ""
  let lastPermissionDetail = ""

  const idleSound = process.env.OPENCODE_SOUND_IDLE || "Glass"
  const permissionSound = process.env.OPENCODE_SOUND_PERMISSION || "Ping"
  const errorSound = process.env.OPENCODE_SOUND_ERROR || "Basso"
  const volume = process.env.OPENCODE_SOUND_VOLUME || "0.3"

  const formatDuration = (ms) => {
    const seconds = Math.floor(ms / 1000)
    if (seconds < 60) {
      return `${seconds}s`
    }
    const minutes = Math.floor(seconds / 60)
    const remainingSeconds = seconds % 60
    if (minutes < 60) {
      return remainingSeconds > 0 ? `${minutes}m ${remainingSeconds}s` : `${minutes}m`
    }
    const hours = Math.floor(minutes / 60)
    const remainingMinutes = minutes % 60
    return remainingMinutes > 0 ? `${hours}h ${remainingMinutes}m` : `${hours}h`
  }

  const truncate = (text, maxLength) => {
    if (text.length <= maxLength) {
      return text
    }
    return text.slice(0, maxLength - 3) + "..."
  }

  const getProjectName = () => {
    try {
      const cwd = process.cwd()
      return cwd.split("/").pop() || "OpenCode"
    } catch {
      return "OpenCode"
    }
  }

  const resetTrackingState = () => {
    lastToolName = ""
    toolCallCount = 0
    changedFiles.clear()
    lastMessageText = ""
    lastErrorDetail = ""
    lastPermissionDetail = ""
  }

  const buildNotificationBody = (variant) => {
    const project = getProjectName()
    const lines = []

    if (taskStartTime) {
      const elapsed = formatDuration(Date.now() - taskStartTime)
      lines.push(`${project} - ${elapsed}`)
    } else {
      lines.push(project)
    }

    const contextParts = []
    if (lastToolName) {
      contextParts.push(`Last: ${lastToolName}`)
    }
    if (toolCallCount > 0) {
      contextParts.push(`${toolCallCount} calls`)
    }
    if (changedFiles.size > 0) {
      contextParts.push(`${changedFiles.size} file${changedFiles.size > 1 ? "s" : ""}`)
    }
    if (contextParts.length > 0) {
      lines.push(contextParts.join(" | "))
    }

    if (variant === "error" && lastErrorDetail) {
      lines.push(truncate(lastErrorDetail, 80))
    } else if (variant === "permission" && lastPermissionDetail) {
      lines.push(truncate(lastPermissionDetail, 80))
    } else if (lastMessageText) {
      lines.push(truncate(lastMessageText, 80))
    }

    return lines.join("\n")
  }

  const playSound = async (sound) => {
    try {
      if (platform === "darwin") {
        await $`afplay -v ${volume} /System/Library/Sounds/${sound}.aiff`
      } else if (platform === "linux") {
        await $`paplay /usr/share/sounds/freedesktop/stereo/complete.oga`
      }
    } catch {}
  }

  const sendNotification = async (subtitle, body) => {
    try {
      if (platform === "darwin") {
        const escaped = body.replace(/"/g, '\\"')
        await $`osascript -e ${"display notification \"" + escaped + "\" with title \"OpenCode\" subtitle \"" + subtitle + "\""}`
      } else if (platform === "linux") {
        await $`notify-send "OpenCode" "${subtitle}: ${body}"`
      }
    } catch {}
  }

  return {
    event: async ({ event }) => {
      if (event.type === "tool.execute.after") {
        const toolName = event?.properties?.tool || event?.properties?.name || ""
        if (toolName) {
          lastToolName = toolName
        }
        toolCallCount++
      } else if (event.type === "file.edited") {
        const filePath = event?.properties?.file || event?.properties?.filePath || ""
        if (filePath) {
          changedFiles.add(filePath)
        }
      } else if (event.type === "message.part.updated") {
        const content = event?.properties?.content || event?.properties?.text || ""
        if (typeof content === "string" && content.trim()) {
          lastMessageText = content.trim().split("\n").pop() || ""
        }
      } else if (event.type === "session.idle") {
        needsAttention = true
        await playSound(idleSound)
        const body = buildNotificationBody("idle")
        taskStartTime = null
        resetTrackingState()
        await sendNotification("Task completed", body)
      } else if (event.type === "session.error") {
        needsAttention = true
        lastErrorDetail = event?.properties?.error?.message || event?.properties?.error || event?.properties?.message || ""
        await playSound(errorSound)
        const body = buildNotificationBody("error")
        taskStartTime = null
        resetTrackingState()
        await sendNotification("Task failed", body)
      } else if (event.type === "permission.asked") {
        needsAttention = true
        const tool = event?.properties?.tool || ""
        const args = event?.properties?.args || {}
        if (tool) {
          lastPermissionDetail = `${tool}: ${JSON.stringify(args)}`.slice(0, 120)
        }
        await playSound(permissionSound)
        const body = buildNotificationBody("permission")
        await sendNotification("Waiting for input", body)
      } else if (event.type === "session.cancelled") {
        taskStartTime = null
        resetTrackingState()
      } else if (event.type === "session.status" && needsAttention) {
        needsAttention = false
        taskStartTime = Date.now()
        resetTrackingState()
      }
    },
  }
}
