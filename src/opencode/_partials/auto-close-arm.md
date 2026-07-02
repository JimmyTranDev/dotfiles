```bash
node "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/lib/implement-auto-close-arm.mjs"
```

It is best-effort and self-limiting: a no-op outside zellij and unless
`OPENCODE_IMPLEMENT_AUTOCLOSE` is explicitly enabled (e.g. `=1`) — the feature is
opt-in / default-off — and it never fails the run.
