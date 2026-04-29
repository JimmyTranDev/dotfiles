---
name: fms
description: Generate FMS JSON array with key, no, and en translation fields
---

Usage: /fms $ARGUMENTS

Generate a JSON array of FMS translation objects from the provided keys or descriptions.

1. Parse input:
   - If `$ARGUMENTS` contains keys (dot-notation like `page.login.title`), use them directly
   - If `$ARGUMENTS` contains descriptions in one language, generate the key from the description and translate to the other language
   - If no arguments provided, prompt the user for keys interactively

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

4. Copy to clipboard if possible:
   - On macOS: pipe to `pbcopy`
   - Report that the JSON was copied

Important:
- Keys must be dot-notation format (e.g., `page.section.element`)
- Translations should be natural and contextually appropriate, not literal word-for-word
- If the user provides Norwegian text, translate to English and vice versa
- If the user provides both languages, just format them
