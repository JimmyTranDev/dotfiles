---
name: stitch
description: Generate UI designs with Google Stitch
---

Usage: /stitch <description of what to design>

Generate AI-powered UI design variations using Google Stitch.

$ARGUMENTS

Load the **stitch-mcp** skill.

Use only Stitch MCP tools for all design generation. Do NOT use Browser MCP tools — this command generates designs, not web pages.

1. Check for existing designs:
   - Call `list_projects` to check for a relevant existing project
   - If a matching project exists, call `list_screens` with its `projectId` to see existing screens
   - Ask the user whether to use existing screens, generate variants of them, or generate new screens from scratch

2. Generate designs with Stitch:
   - If generating new screens: call `generate_screen_from_text` with `projectId`, `prompt` (from `$ARGUMENTS`), and `deviceType`
   - If generating variants of existing screens: call `generate_variants` with `projectId`, `selectedScreenIds`, `prompt`, and `variantOptions`
   - If no existing project fits: call `create_project` first, then `generate_screen_from_text`
   - Aim for 3 distinct variations with different visual approaches (e.g., minimal, detailed, creative)

3. Retrieve the generated designs:
   - Call `get_screen_code` and `get_screen_image` in parallel for each generated screen to get the HTML/CSS and screenshots

4. Present the variations to the user:
   - Show each variation's screenshot and a brief description of its design approach
   - Highlight the key differences between the options (layout, typography, spacing, visual hierarchy, component patterns)
   - Ask the user to pick one variation, request modifications, or specify elements to combine from multiple variations

5. If the user requests modifications:
   - Call `edit_screens` with the selected `screenId`, `projectId`, and the edit `prompt`
   - Retrieve and present the updated design

6. If the user wants to preview a design on a mobile device:
   - Load the **mobile-mcp** skill
   - Use Mobile MCP tools (`mobile_list_available_devices`, `mobile_open_url`, `mobile_take_screenshot`, etc.) to preview on a simulator or device
   - Do NOT use Browser MCP tools for mobile preview

Important:
- Use Stitch MCP tools for all design generation — never Browser MCP
- Use Mobile MCP tools for mobile device previews — never Browser MCP
- If Stitch tools are unavailable or auth fails, notify the user and suggest running `stitch-mcp doctor`
