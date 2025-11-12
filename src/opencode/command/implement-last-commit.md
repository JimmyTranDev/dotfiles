---
name: implement
description: Read the last commit message and implement the required changes described in it
---

Read the last git commit message and analyze what changes need to be implemented based on that commit message. Then implement those changes:

1. Get the last commit message using `git log -1 --pretty=format:"%s"`
2. Parse the commit message to understand what was supposed to be implemented
3. Check if the changes described in the commit message are actually present in the codebase
4. If the changes are missing or incomplete, implement them according to the commit message description
5. If the changes are already present, verify they match the commit description and suggest improvements if needed

Common scenarios this handles:
- Commit messages that describe features not yet implemented
- Commits that mention fixes but the fix wasn't fully applied
- Commits describing refactoring that wasn't completed
- Documentation updates mentioned but not written
- Configuration changes described but not applied

This command is useful when you've made a commit describing what you want to do, but haven't actually implemented it yet.