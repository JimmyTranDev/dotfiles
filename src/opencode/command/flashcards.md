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

2. Delegate to the **fsrs** agent to:
   - Analyze the source material for key concepts, patterns, and facts worth retaining
   - Generate flashcards optimized for spaced repetition (atomic, unambiguous, one concept per card)
   - Format cards for import into Anki or similar SRS tools

3. Present the generated flashcards to the user for review and refinement
