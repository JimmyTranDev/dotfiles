---
name: stitch
description: Generate UI designs with Google Stitch
---

Usage: /stitch <description of what to design>

Generate AI-powered UI design variations using Google Stitch.

$ARGUMENTS

Load the **stitch** skill.

Do NOT use Browser MCP tools -- this command generates designs, not web pages.

1. Check for existing designs:
   - Call `list_projects` to check for a relevant existing project
   - If a matching project exists, call `list_screens` with the project ID to see existing screens
   - Ask the user whether to use existing screens, generate variants of them, or generate new screens from scratch

2. Generate designs with Stitch:
   - If generating new screens: call `generate_screen_from_text` with the project ID, prompt from `$ARGUMENTS`, and target `deviceType`
   - If generating variants of existing screens: call `generate_variants` with the project ID, screen IDs, prompt, and `variantOptions`
   - If no existing project fits: call `create_project` first, then `generate_screen_from_text`
   - Aim for 3 distinct variations with different visual approaches (minimal, detailed, creative)
   - Generation can take several minutes -- do NOT retry on timeout; check with `list_screens` or `get_screen` afterward

3. Retrieve the generated designs:
   - For each generated screen, call `get_screen_code` and `get_screen_image` in parallel to retrieve both the full HTML/CSS code and the screenshot image
   - Always retrieve both artifacts -- the code is needed for implementation reference and the screenshot for visual review

4. Present the variations to the user:
   - Show each variation's screenshot image and its HTML/CSS code
   - Provide a brief description of each variation's design approach
   - Highlight the key differences between the options (layout, typography, spacing, visual hierarchy, component patterns)
   - Ask the user to pick one variation, request modifications, or specify elements to combine from multiple variations

5. If the user requests modifications:
   - Call `edit_screens` with the project ID, screen IDs, and edit prompt
   - Call `get_screen_code` and `get_screen_image` in parallel for the updated screen
   - Present the updated screenshot and code to the user

6. If the user wants to preview a design on a mobile device:
   - Load the **mobile-mcp** skill
   - Use Mobile MCP tools to preview on a simulator or device
   - Do NOT use Browser MCP tools for mobile preview

Important:
- Use Stitch MCP tools for all design operations -- they are available via the proxy configured in opencode.json
- Use Mobile MCP tools for mobile device previews -- never Browser MCP
- If Stitch tools fail or auth errors occur, notify the user and suggest running `stitch-mcp doctor --verbose`
