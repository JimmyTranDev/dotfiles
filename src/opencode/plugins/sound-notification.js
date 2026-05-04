export const SoundNotification = async ({ $ }) => {
  const platform = process.platform
  let needsAttention = false

  const playSound = async (sound) => {
    try {
      if (platform === "darwin") {
        await $`afplay -v 0.3 /System/Library/Sounds/${sound}.aiff`
      } else if (platform === "linux") {
        await $`paplay /usr/share/sounds/freedesktop/stereo/complete.oga`
      }
    } catch {}
  }

  const renameTab = async (name) => {
    try {
      await $`zellij action rename-tab ${name}`
    } catch {}
  }

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        needsAttention = true
        await playSound("Glass")
        await renameTab("✅ Done")
        if (platform === "darwin") {
          try {
            await $`osascript -e 'display notification "Task completed" with title "OpenCode"'`
          } catch {}
        }
      }
      if (event.type === "permission.asked") {
        needsAttention = true
        await playSound("Ping")
        await renameTab("❓ Input")
        if (platform === "darwin") {
          try {
            await $`osascript -e 'display notification "Waiting for input" with title "OpenCode"'`
          } catch {}
        }
      }
      if (event.type === "session.status" && needsAttention) {
        needsAttention = false
        await renameTab("OpenCode")
      }
    },
  }
}
