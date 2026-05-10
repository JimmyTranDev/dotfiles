export const SoundNotification = async ({ $ }) => {
  const platform = process.platform
  let needsAttention = false
  let taskStartTime = Date.now()

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

  const getProjectName = () => {
    try {
      const cwd = process.cwd()
      return cwd.split("/").pop() || "OpenCode"
    } catch {
      return "OpenCode"
    }
  }

  const getElapsedBody = (project) => {
    if (taskStartTime) {
      const elapsed = formatDuration(Date.now() - taskStartTime)
      return `${project} - ${elapsed}`
    }
    return project
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
      if (event.type === "session.idle") {
        needsAttention = true
        await playSound(idleSound)
        const project = getProjectName()
        const body = getElapsedBody(project)
        taskStartTime = null
        await sendNotification("Task completed", body)
      } else if (event.type === "session.error") {
        needsAttention = true
        await playSound(errorSound)
        const project = getProjectName()
        const body = getElapsedBody(project)
        taskStartTime = null
        await sendNotification("Task failed", body)
      } else if (event.type === "permission.asked") {
        needsAttention = true
        await playSound(permissionSound)
        const project = getProjectName()
        const body = getElapsedBody(project)
        await sendNotification("Waiting for input", body)
      } else if (event.type === "session.status" && needsAttention) {
        needsAttention = false
        taskStartTime = Date.now()
      }
    },
  }
}
