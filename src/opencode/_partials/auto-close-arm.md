```bash
node "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/lib/implement-auto-close-arm.mjs"
```

It is best-effort and self-limiting: a no-op outside zellij and when
`OPENCODE_IMPLEMENT_AUTOCLOSE=0`, and it never fails the run.
