---
name: flashcards
description: Generate FSRS-optimized spaced repetition flashcards from code, docs, or concepts
---

Generate spaced repetition flashcards from the specified source material for long-term retention.

Usage: /flashcards [source]

1. Determine the source material:
   - If the user specifies files, directories, or a topic, use those
   - If no source is given, use recent changes via `git diff` and `git diff --cached`
   - Read and understand the material thoroughly before generating cards

2. Load the **fsrs** skill for card design principles, card types, output format, and quality guidelines

3. Generate flashcards:
   - Analyze the source material for key concepts, patterns, and facts worth retaining
   - Create cards optimized for spaced repetition (atomic, unambiguous, one concept per card)
   - Format cards for import into Anki or similar SRS tools following the skill's output format

4. Present the generated flashcards to the user for review and refinement
