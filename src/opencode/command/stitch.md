---
name: stitch
description: Generate UI designs with Google Stitch
---

Usage: /stitch <description of what to design>

Generate AI-powered UI design variations using Google Stitch.

$ARGUMENTS

Load the **stitch-mcp** skill.

1. Generate 3 design variations with Stitch:
   - List existing Stitch projects to check for a relevant project
   - If a matching project exists, list its screens and ask the user whether to use existing screens or generate new ones
   - Generate 3 distinct variations of the design based on `$ARGUMENTS`, each with a different visual approach (e.g., minimal, detailed, creative)
   - Retrieve all 3 variations in parallel using `get_screen_code` for the HTML/CSS and `get_screen_image` for the screenshots

2. Present the 3 variations to the user:
   - Show each variation's screenshot and a brief description of its design approach
   - Highlight the key differences between the 3 options (layout, typography, spacing, visual hierarchy, component patterns)
   - Ask the user to pick one variation, request modifications, or specify elements to combine from multiple variations

Important:
- If Stitch tools are unavailable or auth fails, notify the user and suggest running `npx @_davideast/stitch-mcp doctor`
