export const SoundNotification = async ({ $ }) => {
  const platform = process.platform

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        if (platform === "darwin") {
          await $`afplay /System/Library/Sounds/Glass.aiff`
        } else if (platform === "linux") {
          await $`paplay /usr/share/sounds/freedesktop/stereo/complete.oga`.catch(() => {})
        }
      }
    },
  }
}
