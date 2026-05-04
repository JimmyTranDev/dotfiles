export const SoundNotification = async ({ $ }) => {
  const platform = process.platform
  let needsAttention = false

  const getBaseTabName = async () => {
    try {
      const home = process.env.HOME || ""
      const cwd = process.cwd()
      let currentDir = cwd.split("/").pop() || ""
      if (cwd === home) {
        currentDir = "~"
      }
      currentDir = currentDir.replace(/^[A-Z]+-\d+-/, "")
      const maxLength = parseInt(process.env.ZELLIJ_TAB_NAME_MAX_LENGTH || "20", 10)
      let tabName = currentDir.slice(0, maxLength)

      try {
        const result = await $`zellij action dump-layout 2>/dev/null`.quiet()
        const lines = result.stdout.split("\n")
        let count = 0
        for (const line of lines) {
          if (/^\s*tab\s/.test(line)) {
            count++
            if (/focus=true/.test(line)) {
              tabName = `${count}. ${tabName}`
              break
            }
          }
        }
      } catch {}

      return tabName
    } catch {
      return "OpenCode"
    }
  }

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
        const baseName = await getBaseTabName()
        await renameTab(`${baseName} ✅`)
        if (platform === "darwin") {
          try {
            await $`osascript -e 'display notification "Task completed" with title "OpenCode"'`
          } catch {}
        }
      }
      if (event.type === "permission.asked") {
        needsAttention = true
        await playSound("Ping")
        const baseName = await getBaseTabName()
        await renameTab(`${baseName} ❓`)
        if (platform === "darwin") {
          try {
            await $`osascript -e 'display notification "Waiting for input" with title "OpenCode"'`
          } catch {}
        }
      }
      if (event.type === "session.status" && needsAttention) {
        needsAttention = false
        const baseName = await getBaseTabName()
        await renameTab(baseName)
      }
    },
  }
}
