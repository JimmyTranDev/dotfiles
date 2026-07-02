---
description: Scaffold a good LOCAL opencode config for the current project — create/upsert opencode.json and AGENTS.md (smart merge, never clobbering your prose), and, when it makes sense, a local skill index
---

Set up a good **project-local** opencode configuration for the project in the
current working directory. Optional focus/notes: **$ARGUMENTS**.

This produces three things in the **target project** (never in opencode's own
global config):

1. A project `opencode.json` (create or extend, preserving existing fields).
2. An **upserted `AGENTS.md`** — a good starter when absent, a **smart merge**
   that preserves all hand-written prose when present.
3. **When it makes sense**, a local `.opencode/skills/` routing index.

Load the `customize-opencode` skill with the skill tool first and follow it — it
is the source of truth for opencode's config shapes, file locations, and the
"restart after config changes" rule. Do **not** edit any global config
(`~/.config/opencode/…`); everything here is scoped to the current project.

## Phase 0 — Detect the project

1. Confirm the target is the current working directory (the project root opencode
   walked up to). Do **not** touch this dotfiles repo's own config unless the cwd
   *is* that repo.
2. Best-effort, lightweight stack detection to seed command hints — check for:
   - `package.json` → read `scripts` for build/test/lint/dev commands.
   - `Cargo.toml` (`cargo build` / `cargo test`), `go.mod` (`go build` / `go test`),
     `pyproject.toml` / `requirements.txt`, `Makefile`, `.git`, etc.
   Detection only *suggests* command hints for the AGENTS.md starter; it never
   hard-fails and it is fine to detect nothing.

## Phase 1 — Upsert the project `opencode.json`

Ensure a valid project config exists (prefer `.opencode/opencode.json`, or a
root `opencode.json`/`opencode.jsonc` if one already exists — do not create a
duplicate). It must:

- Declare `"$schema": "https://opencode.ai/config.json"`.
- Include `AGENTS.md` in `instructions` (e.g. `"instructions": ["AGENTS.md"]`).
- **Preserve every pre-existing field** — merge, never overwrite. If the file is
  already valid and complete, leave it as-is.

If you are unsure of any field's exact shape, fetch `https://opencode.ai/config.json`
and read the schema rather than guessing (opencode hard-fails on invalid config).

## Phase 2 — Upsert `AGENTS.md` (smart merge)

opencode's guidance lives between two sentinel comments so re-runs never clobber
hand-written prose:

```
<!-- opencode:managed:start -->
… managed content …
<!-- opencode:managed:end -->
```

Use the committed helper — the deterministic merge logic (create / replace-only-
the-block / append / idempotent) is scripted, not re-derived by hand:

```bash
# Dry-run first — prints the merged document, writes nothing:
node "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/lib/agents-md-upsert.mjs" \
  <path-to-project>/AGENTS.md \
  --name "<project name>" \
  --build "<build cmd>" --test "<test cmd>" --lint "<lint cmd>" --dev "<dev cmd>" \
  --create-notes

# When the merged output looks right, write it back:
node "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/lib/agents-md-upsert.mjs" \
  <path-to-project>/AGENTS.md \
  --name "<project name>" \
  --build "<build cmd>" --test "<test cmd>" --lint "<lint cmd>" --dev "<dev cmd>" \
  --create-notes --write
```

Behavior (all handled by the helper):

- **Absent AGENTS.md** → the managed block becomes the file; `--create-notes`
  adds an unmanaged "Project notes" section **after** the block as a safe place
  for the user's own guidance.
- **Present with sentinels** → only the first block is replaced; every other
  byte is preserved verbatim. `--create-notes` is ignored (file exists).
- **Present without sentinels** → the managed block is appended after one blank
  line; existing content is untouched.

`--write` creates the target's parent directory if needed and, on any failure,
prints a single `error: …` line and exits non-zero (never a stack trace).

Pass only the `--build`/`--test`/`--lint`/`--dev` hints you actually detected;
omit the rest. Prefer generating the body from hints; only use `--inner-file` /
`--stdin` if you need a fully custom managed body — and that custom body must not
itself contain the sentinel comments (the helper rejects it if it does).

**Never edit the managed block by hand and never move a user's prose inside the
sentinels** — hand-written guidance belongs *outside* the block.

## Phase 3 — Local skill index (only when it makes sense)

If the project has local skills in `.opencode/skills/` (or you are adding the
first one and want them routable) **and** has no `using-agent-skills` index yet,
load the `local-skill-index` skill with the skill tool and follow it to generate
`.opencode/skills/using-agent-skills/SKILL.md`. If the project has no local
skills and isn't gaining any, **skip this** — do not invent skills nobody asked
for.

## Phase 4 — Verify & hand off

1. Show the user the resulting `opencode.json` and the AGENTS.md diff (the dry-run
   output vs. the prior file), and confirm hand-written prose was preserved.
2. If you edited config-time files, remind the user to **quit and restart
   opencode** — config, skills, and instructions are loaded at startup and are
   not hot-reloaded.
3. **Never commit or push** on the user's behalf. If they want to land it, point
   them at the `commit` skill.

## Done

Report what was created vs. merged (config, AGENTS.md, optional skill index), the
detected stack/commands, confirmation that existing prose was preserved, and the
restart reminder.
