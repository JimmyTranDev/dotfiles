---
name: stitch
description: Generate UI designs with Google Stitch and implement them as components
---

Usage: /stitch <description of what to design>

Generate AI-powered UI designs using Google Stitch, then implement them as working components in the project.

$ARGUMENTS

Load the **stitch-mcp**, **accessibility**, and **follower** skills in parallel.

1. Determine the platform by examining the project:
   - Check for `react-native` or `expo` in `package.json` — if found, target React Native/Expo
   - Check for `react` or `next` in `package.json` — if found, target React web
   - If neither, ask the user what platform to target

2. Generate 3 design variations with Stitch:
   - List existing Stitch projects to check for a relevant project
   - If a matching project exists, list its screens and ask the user whether to use existing screens or generate new ones
   - Generate 3 distinct variations of the design based on `$ARGUMENTS`, each with a different visual approach (e.g., minimal, detailed, creative)
   - Retrieve all 3 variations in parallel using `get_screen_code` for the HTML/CSS and `get_screen_image` for the screenshots

3. Present the 3 variations to the user:
   - Show each variation's screenshot and a brief description of its design approach
   - Highlight the key differences between the 3 options (layout, typography, spacing, visual hierarchy, component patterns)
   - Ask the user to pick one variation, or specify elements to combine from multiple variations

4. Analyze the chosen design:
   - Parse the HTML/CSS structure from the selected Stitch output
   - Identify distinct components, layout patterns, and interactive elements
   - Map Stitch design tokens to the project's existing design system or Catppuccin Mocha theme
   - Note any gaps: missing states (loading, empty, error), missing interactions, or accessibility issues in the generated design

5. Plan the implementation:
   - Break the design into components that match the project's existing component granularity
   - Map each design element to the project's styling approach (Tailwind, NativeWind, or shell formatting)
   - Present the component breakdown to the user and ask for confirmation before implementing

6. Delegate implementation to the **designer** agent:
   - Provide the chosen Stitch HTML/CSS and screenshot as reference
   - Implement each component following the project's conventions
   - Translate Stitch styles to the project's styling system
   - Add accessibility: keyboard navigation, ARIA/a11y props, focus management, screen reader support
   - Add responsive behavior: mobile-first breakpoints (web) or platform-specific adaptations (mobile)
   - Handle all states: loading, empty, error, disabled, hover, focus, active

7. Post-implementation review — launch agents in parallel:
   - **reviewer**: Verify component correctness, prop interfaces, and convention adherence
   - **auditor**: Scan for XSS, injection risks, or unsafe patterns in user-facing components
   - **optimizer**: Check for unnecessary re-renders, heavy imports, or animation performance issues

8. If review agents surface issues:
   - Use **fixer** to address each finding
   - Re-run **reviewer** once more to verify (max 2 iterations)

9. After all components are implemented:
   - Run the project's test suite and build to confirm nothing is broken
   - Summarize what was generated: which variation was chosen, components created, design decisions made, accessibility features added
   - Show the mapping from Stitch screens to implemented components

Important:
- The Stitch design is a reference, not a literal copy — adapt it to the project's conventions and design system
- Never skip accessibility to match a design exactly
- Keep components presentational — do not add business logic or data fetching
- Match the project's existing file structure and naming patterns for new components
- If Stitch tools are unavailable or auth fails, notify the user and suggest running `npx @_davideast/stitch-mcp doctor`
