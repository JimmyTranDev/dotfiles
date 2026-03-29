---
name: implement-mobile
description: Generate a Stitch design, implement it in a React Native/Expo project, and verify on an Android device
---

Usage: /implement-mobile <description of what to build>

Generate a UI design with Google Stitch, implement it in the current React Native/Expo project, and verify the result on an Android emulator.

$ARGUMENTS

Load the **stitch-mcp**, **mobile-mcp**, **accessibility**, and **follower** skills in parallel.

Use Stitch MCP tools for design generation and Mobile MCP tools for device verification. Do NOT use Browser MCP tools at any point in this workflow.

1. Generate 3 design variations with Stitch:
   - Use Stitch MCP upstream tools to list existing projects and check for a relevant project
   - If a matching project exists, list its screens and ask the user whether to use existing screens or generate new ones
   - Generate 3 distinct variations of the design based on `$ARGUMENTS`, each with a different visual approach (e.g., minimal, detailed, creative)
   - Retrieve all 3 variations in parallel using Stitch MCP `get_screen_code` for the HTML/CSS and `get_screen_image` for the screenshots

2. Present the 3 variations to the user:
   - Show each variation's screenshot and a brief description of its design approach
   - Highlight the key differences between the 3 options (layout, typography, spacing, visual hierarchy, component patterns)
   - Ask the user to pick one variation, request modifications, or specify elements to combine from multiple variations

3. Analyze the chosen design:
   - Parse the HTML/CSS structure from the selected Stitch output
   - Identify distinct components, layout patterns, and interactive elements
   - **Discard all Stitch design tokens** (colors, fonts, spacing scales, shadows, radii) — use only the project's existing design system or Catppuccin Mocha theme
   - Note any gaps: missing states (loading, empty, error), missing interactions, or accessibility issues

4. Plan the implementation:
   - Break the design into components that match the project's existing component granularity
   - Map each design element to React Native/Expo components with NativeWind or the project's styling approach
   - Present the component breakdown to the user and ask for confirmation before implementing

5. Implement the components:
   - Delegate to the **designer** agent for all component creation
   - Translate Stitch layout patterns to React Native primitives (`View`, `Text`, `Pressable`, `ScrollView`, `FlatList`, etc.)
   - Use the project's existing design system tokens exclusively — never adopt Stitch colors, fonts, spacing, shadows, or radii
   - Match the project's existing file structure, naming patterns, and import conventions
   - Add accessibility: screen reader support via `accessibilityLabel`, `accessibilityRole`, `accessibilityHint`, touch target sizing (min 44x44), focus management
   - Handle all states: loading, empty, error, disabled
   - Keep components presentational — do not add business logic or data fetching

6. Verify on Android emulator using Mobile MCP tools:
   - Call `mobile_list_available_devices` to find an available Android emulator
   - If no Android emulator is running, notify the user and ask them to start one
   - Build and install the app if needed, or use hot reload if the dev server is running
   - Call `mobile_launch_app` with the project's package name (check `app.json` or `app.config.ts` for the Android package)
   - Navigate to the implemented screen using Mobile MCP tap and swipe interactions
   - Call `mobile_take_screenshot` to capture the result
   - Compare the screenshot against the original Stitch design screenshot
   - If there are visual discrepancies, fix them and re-verify (max 2 iterations)

7. Post-implementation review — launch **reviewer** and **auditor** in parallel:
   - **reviewer**: verify component correctness, prop interfaces, and convention adherence
   - **auditor**: scan for unsafe patterns in user-facing components
   - Collect all issues found by both agents

8. If issues were found:
   - Use **fixer** to address each finding
   - Re-run **reviewer** once more to verify (max 2 iterations)

9. Summarize the result:
   - Show the final Android screenshot alongside the original Stitch design
   - List all components created with brief descriptions
   - List accessibility features added
   - List any follow-up improvements that were out of scope

Important:
- Use Stitch MCP tools for design generation — never Browser MCP
- Use Mobile MCP tools for all device interaction — never Browser MCP
- The Stitch design informs layout and component structure only — never adopt its design tokens
- Every component must have screen reader support and adequate touch targets
- Never skip accessibility to match a design exactly
- Match the project's existing file structure and naming patterns
- If Stitch tools are unavailable or auth fails, notify the user and suggest running `stitch-mcp doctor`
