---
name: implement-stitch
description: Implement an existing Stitch design in a React Native/Expo project and verify on an Android device
---

Usage: /implement-stitch <stitch project URL or project ID> [screen description or screen ID]

Implement an existing Stitch design in the current React Native/Expo project and verify the result on an Android emulator.

$ARGUMENTS

Load the **stitch**, **mobile-mcp**, **accessibility**, and **follower** skills in parallel.

Do NOT use Browser MCP tools at any point in this workflow.

1. Fetch the Stitch design:
   - Extract the project ID (and screen instance ID if present) from `$ARGUMENTS`
   - Call `list_projects` to find the project, then `list_screens` with the project ID to list available screens
   - If a specific screen was provided, use it. Otherwise, present the available screens and ask the user which one to implement
   - Call `get_screen_code` and `get_screen_image` in parallel to retrieve both the full HTML/CSS code and the screenshot image
   - Always retrieve both artifacts -- the code is needed for implementation reference and the screenshot for visual comparison during verification

2. Analyze the design:
   - Parse the HTML/CSS structure from the Stitch output
   - Identify distinct components, layout patterns, and interactive elements
   - **Discard all Stitch design tokens** (colors, fonts, spacing scales, shadows, radii) -- use only the project's existing design system or Catppuccin Mocha theme
   - Note any gaps: missing states (loading, empty, error), missing interactions, or accessibility issues

3. Plan the implementation:
   - Break the design into components that match the project's existing component granularity
   - Map each design element to React Native/Expo components with NativeWind or the project's styling approach
   - Identify any new utility classes, custom values, or theme extensions the design requires that are not yet in the Tailwind/NativeWind config
   - Identify any existing global/shared components (buttons, inputs, cards, typography, layout wrappers) that need modification to support the new design
   - Present the component breakdown, proposed Tailwind config changes, and proposed global component changes to the user and ask for confirmation before implementing

4. Update Tailwind config and global components:
   - If the design introduces spacing, font sizes, border radii, breakpoints, or other values not present in `tailwind.config.js` / `tailwind.config.ts` / `nativewind` config, extend the theme to include them using the project's existing design system tokens (never Stitch tokens)
   - If the design requires new NativeWind plugins, variants, or custom utilities, add them to the config
   - If existing global/shared components need changes to support the new design (new variants, sizes, props, layout adjustments), update them in place rather than creating one-off duplicates
   - Ensure global component changes remain backward compatible -- existing usages must not break
   - Run the project's type check or linter after config/global changes to catch regressions before proceeding

5. Implement the screen components:
   - Delegate to the **designer** agent for all component creation
   - Translate Stitch layout patterns to React Native primitives (`View`, `Text`, `Pressable`, `ScrollView`, `FlatList`, etc.)
   - Use the project's existing design system tokens exclusively -- never adopt Stitch colors, fonts, spacing, shadows, or radii
   - Leverage the updated Tailwind config values and modified global components from step 4
   - Match the project's existing file structure, naming patterns, and import conventions
   - Add accessibility: screen reader support via `accessibilityLabel`, `accessibilityRole`, `accessibilityHint`, touch target sizing (min 44x44), focus management
   - Handle all states: loading, empty, error, disabled
   - Keep components presentational -- do not add business logic or data fetching

6. Quick visual check on Android emulator:
   - Call `mobile_list_available_devices` to find an available Android emulator -- if none is running, skip this step and note it in the summary
   - Launch the app and navigate to the implemented screen
   - Call `mobile_take_screenshot` once and compare it side-by-side with the original Stitch design screenshot
   - Only fix obvious layout-breaking issues (wrong order, missing sections, completely wrong sizing) -- do not iterate on pixel-level polish

7. Summarize the result:
   - Show the final Android screenshot alongside the original Stitch design
   - List all components created with brief descriptions
   - List accessibility features added
   - List any follow-up improvements that were out of scope

Important:
- Use Stitch MCP tools for all design operations -- they are available via the proxy configured in opencode.json
- Use Mobile MCP tools for all device interaction -- never Browser MCP
- The Stitch design informs layout and component structure only -- never adopt its design tokens
- Every component must have screen reader support and adequate touch targets
- Never skip accessibility to match a design exactly
- Match the project's existing file structure and naming patterns
- Always extend Tailwind/NativeWind config through the theme `extend` object to avoid overriding defaults
- When modifying global components, preserve backward compatibility -- add new props/variants instead of changing existing behavior
- Run type checks after Tailwind config or global component changes to catch regressions early
- If Stitch tools fail or auth errors occur, notify the user and suggest running `stitch-mcp doctor --verbose`
