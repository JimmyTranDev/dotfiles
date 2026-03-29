---
name: stitch
description: Generate UI designs with Google Stitch
---

Usage: /stitch <description of what to design>

Generate AI-powered UI design variations using Google Stitch.

$ARGUMENTS

Do NOT use Browser MCP tools — this command generates designs, not web pages.

Load the **stitch-cli** skill.

Use the `stitch-mcp tool <tool_name>` CLI via Bash for all Stitch operations. Pass parameters as JSON after the tool name with `-d '{"key": "value"}'`.

1. Check for existing designs:
   - Run `stitch-mcp tool list_projects` to check for a relevant existing project
   - If a matching project exists, run `stitch-mcp tool list_screens -d '{"projectId": "<id>"}'` to see existing screens
   - Ask the user whether to use existing screens, generate variants of them, or generate new screens from scratch

2. Generate designs with Stitch:
   - If generating new screens: run `stitch-mcp tool generate_screen_from_text -d '{"projectId": "<id>", "prompt": "<from $ARGUMENTS>", "deviceType": "<mobile|desktop>"}'`
   - If generating variants of existing screens: run `stitch-mcp tool generate_variants -d '{"projectId": "<id>", "selectedScreenIds": ["<id>"], "prompt": "<prompt>", "variantOptions": {}}'`
   - If no existing project fits: run `stitch-mcp tool create_project` first, then `generate_screen_from_text`
   - Aim for 3 distinct variations with different visual approaches (e.g., minimal, detailed, creative)
   - Generation can take a few minutes -- do NOT retry on timeout. If a connection error occurs, the generation may still succeed; check with `get_screen` later

3. Retrieve the generated designs:
   - For each generated screen, run `stitch-mcp tool get_screen_code -d '{"projectId": "<id>", "screenId": "<id>"}'` and `stitch-mcp tool get_screen_image -d '{"projectId": "<id>", "screenId": "<id>"}'` in parallel to retrieve both the full HTML/CSS code and the screenshot image
   - Always retrieve both artifacts — the code is needed for implementation reference and the screenshot for visual review

4. Present the variations to the user:
   - Show each variation's screenshot image and its HTML/CSS code
   - Provide a brief description of each variation's design approach
   - Highlight the key differences between the options (layout, typography, spacing, visual hierarchy, component patterns)
   - Ask the user to pick one variation, request modifications, or specify elements to combine from multiple variations

5. If the user requests modifications:
   - Run `stitch-mcp tool edit_screens -d '{"projectId": "<id>", "selectedScreenIds": ["<id>"], "prompt": "<edit prompt>"}'`
   - Run `get_screen_code` and `get_screen_image` in parallel for the updated screen to retrieve both the updated code and screenshot
   - Present the updated screenshot and code to the user

6. If the user wants to preview a design on a mobile device:
   - Load the **mobile-mcp** skill
   - Use Mobile MCP tools (`mobile_list_available_devices`, `mobile_open_url`, `mobile_take_screenshot`, etc.) to preview on a simulator or device
   - Do NOT use Browser MCP tools for mobile preview

Important:
- Run all Stitch operations via `stitch-mcp tool <name> -d '{...}'` in Bash — do NOT use Stitch MCP tools
- Use Mobile MCP tools for mobile device previews — never Browser MCP
- If Stitch CLI fails or auth errors occur, notify the user and suggest running `stitch-mcp doctor`
