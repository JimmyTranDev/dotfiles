---
name: fms
description: Generate FMS JSON array with key, no, and en translation fields
---

Usage: /fms $ARGUMENTS

Generate a JSON array of FMS translation objects from the provided keys or descriptions.

1. Parse input:
   - If `$ARGUMENTS` contains keys (dot-notation like `page.login.title`), use them directly
   - If `$ARGUMENTS` contains descriptions in one language, generate the key from the description and translate to the other language
   - If `$ARGUMENTS` contains "diff", "fallback", or "check" — use diff-detection mode (see below)
   - If no arguments provided, prompt the user for keys interactively (include "Detect from git diff" as an option)

### Diff-detection mode
When triggered, automatically extract new/modified FMS keys from git diffs:
1. Find fallback translation files: glob for `**/fallback-en.json` and `**/fallback-no.json`
2. Run `git diff --cached` on those files first (staged changes); if empty, fall back to `git diff` (unstaged); if still empty, diff the last commit (`git diff HEAD~1`)
3. Parse added lines (`+` prefix) to extract key-value pairs from both `en` and `no` files
4. Match keys across both files to build the FMS objects
5. Continue to step 2 with the extracted keys and translations

2. For each key, generate an object with:
   - `key`: dot-notation path (e.g., `page.login.title`)
   - `no`: Norwegian Bokmål translation
   - `en`: English translation

3. Output the JSON array:
   ```json
   [
     { "key": "page.login.title", "no": "Logg inn", "en": "Log in" },
     { "key": "page.login.subtitle", "no": "Velkommen tilbake", "en": "Welcome back" }
   ]
   ```

4. Write the JSON array to `FMS.json` at the project root:
   - If `FMS.json` already exists, merge new keys with existing ones (avoid duplicates by key)
   - If it doesn't exist, create it with the generated array

5. Also copy to clipboard if possible:
   - On macOS: pipe to `pbcopy`
   - Report that the JSON was written to `FMS.json` and copied

Important:
- Keys must be dot-notation format (e.g., `page.section.element`)
- Translations should be natural and contextually appropriate, not literal word-for-word
- If the user provides Norwegian text, translate to English and vice versa
- If the user provides both languages, just format them
