---
name: conventions
description: Add a new coding convention to the conventions skill file
---

Usage: /conventions <convention description>

Add a new convention to `src/opencode/skills/conventions/SKILL.md` based on what the user describes.

$ARGUMENTS

1. Read the current contents of `src/opencode/skills/conventions/SKILL.md`

2. Determine where the new convention belongs:
   - Match the convention to an existing section (General, TypeScript > Code Rules, Module Structure, Error Handling, Imports, Project Setup Preferences)
   - If no existing section fits, create a new section following the existing heading hierarchy

3. Write the convention:
   - Use the same format as existing entries — a single bullet point starting with a dash
   - Keep it concise: one line, action-oriented, with an em dash for rationale if needed
   - Avoid duplicating or contradicting existing conventions

4. Add the convention to the appropriate section in the file

5. Show the user what was added and where it was placed

Important:
- Never remove or modify existing conventions
- Never reorganize the file structure — add only
- If the convention already exists in substance, notify the user and stop
- If the convention contradicts an existing one, ask the user which to keep
