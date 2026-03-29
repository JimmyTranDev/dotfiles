---
name: implement-stitch
description: Implement an existing Stitch design in a React Native/Expo project and verify on an Android device
---

Usage: /implement-stitch <stitch project URL or project ID> [screen description or screen ID]

Implement an existing Stitch design in the current React Native/Expo project and verify the result on an Android emulator.

$ARGUMENTS

Load the **mobile-mcp**, **accessibility**, and **follower** skills in parallel.

Use the `stitch-mcp tool <tool_name>` CLI via Bash for all Stitch operations. Pass parameters as JSON after the tool name with `--input '{"key": "value"}'`. Use Mobile MCP tools for device verification. Do NOT use Browser MCP tools at any point in this workflow.

1. Fetch the Stitch design:
   - Extract the project ID (and screen instance ID if present) from `$ARGUMENTS`
   - Run `stitch-mcp tool list_projects` to find the project, then `stitch-mcp tool list_screens --input '{"projectId": "<id>"}'` to list available screens
   - If a specific screen was provided, use it. Otherwise, present the available screens and ask the user which one to implement
   - Run `stitch-mcp tool get_screen_code --input '{"projectId": "<id>", "screenId": "<id>"}'` and `stitch-mcp tool get_screen_image --input '{"projectId": "<id>", "screenId": "<id>"}'` in parallel to retrieve both the full HTML/CSS code and the screenshot image
   - Always retrieve both artifacts — the code is needed for implementation reference and the screenshot for visual comparison during verification

2. Analyze the design:
   - Parse the HTML/CSS structure from the Stitch output
   - Identify distinct components, layout patterns, and interactive elements
   - **Discard all Stitch design tokens** (colors, fonts, spacing scales, shadows, radii) — use only the project's existing design system or Catppuccin Mocha theme
   - Note any gaps: missing states (loading, empty, error), missing interactions, or accessibility issues

3. Plan the implementation:
   - Break the design into components that match the project's existing component granularity
   - Map each design element to React Native/Expo components with NativeWind or the project's styling approach
   - Present the component breakdown to the user and ask for confirmation before implementing

4. Implement the components:
   - Delegate to the **designer** agent for all component creation
   - Translate Stitch layout patterns to React Native primitives (`View`, `Text`, `Pressable`, `ScrollView`, `FlatList`, etc.)
   - Use the project's existing design system tokens exclusively — never adopt Stitch colors, fonts, spacing, shadows, or radii
   - Match the project's existing file structure, naming patterns, and import conventions
   - Add accessibility: screen reader support via `accessibilityLabel`, `accessibilityRole`, `accessibilityHint`, touch target sizing (min 44x44), focus management
   - Handle all states: loading, empty, error, disabled
   - Keep components presentational — do not add business logic or data fetching

5. Verify on Android emulator using Mobile MCP tools:
   - Call `mobile_list_available_devices` to find an available Android emulator
   - If no Android emulator is running, notify the user and ask them to start one
   - Build and install the app if needed, or use hot reload if the dev server is running
   - Call `mobile_launch_app` with the project's package name (check `app.json` or `app.config.ts` for the Android package)
   - Navigate to the implemented screen using Mobile MCP tap and swipe interactions
   - Call `mobile_take_screenshot` to capture the result
   - Compare the screenshot against the original Stitch design screenshot
   - If there are visual discrepancies, fix them and re-verify (max 2 iterations)

6. Summarize the result:
   - Show the final Android screenshot alongside the original Stitch design
   - List all components created with brief descriptions
   - List accessibility features added
   - List any follow-up improvements that were out of scope

Important:
- Run all Stitch operations via `stitch-mcp tool <name> --input '{...}'` in Bash — do NOT use Stitch MCP tools
- Use Mobile MCP tools for all device interaction — never Browser MCP
- The Stitch design informs layout and component structure only — never adopt its design tokens
- Every component must have screen reader support and adequate touch targets
- Never skip accessibility to match a design exactly
- Match the project's existing file structure and naming patterns
- If Stitch CLI fails or auth errors occur, notify the user and suggest running `stitch-mcp doctor`
