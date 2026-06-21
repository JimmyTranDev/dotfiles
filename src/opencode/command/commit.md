---
description: Commit staged changes with a conventional commit message
---

Load the `commit` skill with the skill tool and follow its workflow exactly to
commit the changes that are **already staged**.

Specifically:

1. Run `git diff --cached --name-only`; if nothing is staged, tell me and stop —
   do not stage anything yourself.
2. Read the staged diff (excluding `*.csv`) and derive any Jira ticket from the
   current branch name (`[A-Z]+-[0-9]+`).
3. Decide the type, scope, and description autonomously — do not ask clarifying
   questions.
4. Commit only what is staged (no `git add`, no file paths passed to `git commit`).
5. Report the final message, short hash, and the files committed.
