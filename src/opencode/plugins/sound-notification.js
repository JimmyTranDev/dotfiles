export const SoundNotification = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        await $`afplay /System/Library/Sounds/Glass.aiff`
      }
    },
  }
}
