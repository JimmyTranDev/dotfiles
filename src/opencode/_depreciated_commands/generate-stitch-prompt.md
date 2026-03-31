---
name: generate-stitch-prompt
description: Analyze the codebase and generate a detailed Stitch design prompt saved to STITCH_PROMPT.md
---

Usage: /generate-stitch-prompt <screen or feature description>

Analyze the current project's UI patterns, theme, component library, and design system to generate a detailed, production-ready prompt for Stitch's `generate_screen_from_text`. Write the result to `STITCH_PROMPT.md` at the project root.

$ARGUMENTS

1. Understand the target screen:
   - Parse `$ARGUMENTS` to identify what screen or feature the user wants a Stitch design for
   - If the description is vague, ask the user for clarification before proceeding

2. Analyze the codebase (run independent searches in parallel):
   - **Platform**: detect whether the project is React (web), React Native/Expo (mobile), or another framework
   - **Design system**: find the color palette, typography scale, spacing scale, border radii, and shadow definitions from Tailwind config, NativeWind config, theme files, or CSS variables
   - **Component inventory**: identify existing shared/global components (buttons, inputs, cards, modals, navigation, lists, headers) and their variant patterns
   - **Layout patterns**: identify common layout structures (stack, grid, sidebar, tab bar, bottom sheet, scroll containers) used across screens
   - **Existing screens**: find 2-3 screens similar to the requested one to extract structural patterns, section ordering, and information density
   - **Brand assets**: check for logo references, icon libraries (Lucide, Ionicons, Material, etc.), and illustration patterns
   - **State patterns**: identify how the project handles loading, empty, error, and disabled states visually

3. Build the Stitch prompt with these sections:
   - **Device type**: specify `mobile` or `desktop` based on the detected platform
   - **Screen purpose**: one paragraph describing what the screen does, who uses it, and the primary user goal
   - **Visual style**: describe the color scheme, typography hierarchy, spacing rhythm, corner radii, and shadow usage derived from the project's design system — use exact hex values and pixel/rem sizes where available
   - **Layout structure**: describe the screen layout top-to-bottom — header, content sections, navigation, fixed elements — referencing patterns found in existing screens
   - **Component breakdown**: list each distinct UI element on the screen with its visual treatment (size, color, shape, typography, spacing, state variations)
   - **Content specifications**: describe placeholder text, image dimensions, icon choices, and data density (how many items in lists, how many fields in forms)
   - **Interactive states**: describe hover/press/focus/disabled/selected states for interactive elements
   - **Responsive behavior**: describe how the layout adapts across breakpoints (web) or orientations (mobile)
   - **Accessibility notes**: describe contrast requirements, touch target sizes, and focus indicators

4. Write the prompt to `STITCH_PROMPT.md`:
   - If `STITCH_PROMPT.md` already exists, overwrite it with the new prompt
   - Format the file with a `# Stitch Prompt` heading followed by the target screen name
   - Include a `## Prompt` section containing the full prompt text ready to copy-paste into Stitch
   - Include a `## Metadata` section listing the detected platform, design system source files, and reference screens used

5. Present the result:
   - Show the user a summary of what was generated
   - Suggest running `/implement-stitch` after creating the design in Stitch to implement it back into the project

Important:
- Use only design tokens and patterns found in the actual codebase — never invent colors, fonts, or spacing values
- If the project uses Catppuccin Mocha, reference exact Catppuccin hex values in the prompt
- The prompt must be detailed enough for Stitch to produce a design that closely matches the project's visual language without manual adjustment
- Do not call any Stitch MCP tools — this command only analyzes the codebase and writes a text file
- If no design system is detected, inform the user and ask whether to use Catppuccin Mocha as the default theme
