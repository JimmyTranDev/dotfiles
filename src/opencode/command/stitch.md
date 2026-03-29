---
name: stitch
description: Generate UI designs with Google Stitch
---

Usage: /stitch <description of what to design>

Generate AI-powered UI design variations using Google Stitch.

$ARGUMENTS

Load the **stitch-mcp** skill.

Use only Stitch MCP tools (`get_screen_code`, `get_screen_image`, `build_site`, and the upstream Stitch project/screen listing tools) for all design generation. Do NOT use Browser MCP tools — this command generates designs, not web pages.

1. Generate 3 design variations with Stitch:
   - Use Stitch MCP upstream tools to list existing projects and check for a relevant project
   - If a matching project exists, list its screens and ask the user whether to use existing screens or generate new ones
   - Generate 3 distinct variations of the design based on `$ARGUMENTS`, each with a different visual approach (e.g., minimal, detailed, creative)
   - Retrieve all 3 variations in parallel using Stitch MCP `get_screen_code` for the HTML/CSS and `get_screen_image` for the screenshots

2. Present the 3 variations to the user:
   - Show each variation's screenshot and a brief description of its design approach
   - Highlight the key differences between the 3 options (layout, typography, spacing, visual hierarchy, component patterns)
   - Ask the user to pick one variation, request modifications, or specify elements to combine from multiple variations

3. If the user wants to preview a design on a mobile device:
   - Load the **mobile-mcp** skill
   - Use Mobile MCP tools (`mobile_list_available_devices`, `mobile_open_url`, `mobile_take_screenshot`, etc.) to preview the design on a simulator or device
   - Do NOT use Browser MCP tools for mobile preview

Important:
- Use Stitch MCP tools for all design generation — never Browser MCP
- Use Mobile MCP tools for mobile device previews — never Browser MCP
- If Stitch tools are unavailable or auth fails, notify the user and suggest running `stitch-mcp doctor`
