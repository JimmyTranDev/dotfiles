---
name: fms
description: Generate FMS JSON array with key, no, and en translation fields
---

Usage: /fms $ARGUMENTS

Generate a JSON array of FMS translation objects from the provided keys or descriptions.

1. Parse input:
   - If `$ARGUMENTS` contains keys (dot-notation like `page.login.title`), use them directly
   - If `$ARGUMENTS` contains descriptions in one language, generate the key from the description and translate to the other language
   - If no arguments provided, default to diff-detection mode (see below)

### Diff-detection mode (default when no arguments)
Automatically extract new/modified FMS keys. Fallback files may be gitignored, so use multiple detection strategies:

1. **Primary: diff fallback JSON files** — glob for `**/fallback-en.json` and `**/fallback-no.json`, then check in order (use first non-empty result):
   a. Staged changes: `git diff --cached --unified=0 -- <fallback files>`
   b. Unstaged changes: `git diff --unified=0 -- <fallback files>`
   c. Last commit: `git diff HEAD~1 --unified=0 -- <fallback files>`
   d. Parse added lines (`+` prefix) to extract key-value pairs, match keys across both files

2. **Fallback: diff FMS types file** — if fallback files are gitignored (no diff results), find the FMS types file (e.g., `**/FmsTypes.ts`, `**/fmsTypes.ts`) and diff it instead:
   a. Extract new key strings from added lines (e.g., `| 'some.key'`)
   b. Read the actual fallback JSON files from disk to get the `no` and `en` translations for each key
   c. If a key exists in the types diff but not in a fallback file, generate the translation

3. **Last resort: compare fallback files against types** — if no diffs found at all, compare keys in fallback JSON files against the FMS types union to find keys present in fallbacks but not yet in FMS.json

4. Continue to step 2 with the extracted keys and translations
5. If no new keys found via any strategy, inform the user and stop

Alternatively, if `$ARGUMENTS` contains explicit keywords like "diff", "fallback", or "check", also use diff-detection mode.

2. For each key, generate an object with:
   - `key`: dot-notation path (e.g., `page.login.title`)
   - `no`: Norwegian Bokmal translation
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
