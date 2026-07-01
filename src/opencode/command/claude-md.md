---
description: Create, update, or migrate a CLAUDE.md rules file (incl. AGENTS.md → CLAUDE.md)
---

Load the `claude-md` skill with the skill tool and follow its workflow exactly
to create, update, or migrate a `CLAUDE.md` rules file for the current repo.

Specifically:

1. Survey the current state: `git grep -n -I 'AGENTS\.md'` to find every rules
   file, `instructions` array, `.gitignore` allowlist, and internal reference.
   Decide the mode — **migrate** (an `AGENTS.md` exists) or **create** (none).
2. Migrate by `git mv`-ing each project-scope `AGENTS.md` to `CLAUDE.md`
   (preserve history); delete instead of rename any `AGENTS.md` that is
   byte-identical to a canonical `CLAUDE.md` elsewhere.
3. Point every `opencode.json` / `opencode.jsonc` `instructions` array at
   `CLAUDE.md` (or intentionally empty, relying on auto-load).
4. Update every reference: `.gitignore` allowlists (`!CLAUDE.md`), and internal
   references in commands, skills, scripts, docs, and specs.
5. In this dotfiles repo, edit `src/` sources only — never the live `~/.config`
   or `~/.claude` targets.
6. Verify: `git grep -n 'AGENTS\.md'` returns only intentional references, config
   validators pass, and opencode still loads the rules (probe, do not assume).
