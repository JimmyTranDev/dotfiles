---
name: browser-mcp
description: Browser MCP tool usage patterns for web page navigation, accessibility snapshots, element interaction, form filling, keyboard input, and console log inspection
---

## Tool Overview

| Tool | Purpose |
|------|---------|
| `Browser_browser_navigate` | Navigate to a URL |
| `Browser_browser_go_back` | Go back to the previous page |
| `Browser_browser_go_forward` | Go forward to the next page |
| `Browser_browser_snapshot` | Capture accessibility tree of current page |
| `Browser_browser_click` | Click an element by ref |
| `Browser_browser_hover` | Hover over an element by ref |
| `Browser_browser_type` | Type text into an editable element |
| `Browser_browser_select_option` | Select option(s) in a dropdown |
| `Browser_browser_press_key` | Press a keyboard key |
| `Browser_browser_wait` | Wait for a specified number of seconds |
| `Browser_browser_screenshot` | Take a screenshot of the current page |
| `Browser_browser_get_console_logs` | Get browser console output |

## Interaction Workflow

Every browser interaction follows this sequence:

1. **Navigate** — call `Browser_browser_navigate` with the target URL
2. **Snapshot** — call `Browser_browser_snapshot` to get the accessibility tree with element refs
3. **Act** — click, type, select, or hover using refs from the snapshot
4. **Verify** — snapshot or screenshot to confirm the action succeeded

Never skip the snapshot step. Always inspect the accessibility tree before interacting.

## Accessibility Snapshots

```
Browser_browser_snapshot()
```

Returns the page's accessibility tree with:
- Element roles (button, link, textbox, combobox, etc.)
- Display text and accessible names
- Ref strings for targeting elements in subsequent calls

Use snapshot output to find the correct `ref` for any element you want to interact with. Do not guess refs — always snapshot first.

### When to Re-Snapshot

- After any click that triggers navigation or DOM change
- After form submission
- After expanding dropdowns or modals
- After waiting for dynamic content to load

## Clicking Elements

```
Browser_browser_click(ref: "<ref_string>", element: "Submit button")
```

| Parameter | Required | Purpose |
|-----------|----------|---------|
| `ref` | Yes | Exact ref string from snapshot |
| `element` | Yes | Human-readable description of what you're clicking |

Use for: buttons, links, checkboxes, radio buttons, tabs, menu items.

## Typing Text

```
Browser_browser_type(ref: "<ref_string>", element: "Email input", text: "user@example.com", submit: false)
```

| Parameter | Required | Purpose |
|-----------|----------|---------|
| `ref` | Yes | Exact ref string from snapshot |
| `element` | Yes | Human-readable description of the input |
| `text` | Yes | Text to enter |
| `submit` | Yes | `true` to press Enter after typing, `false` to just type |

To replace existing text in an input, select all first with `Browser_browser_press_key(key: "Meta+a")` then type the new value.

## Selecting Dropdown Options

```
Browser_browser_select_option(ref: "<ref_string>", element: "Country dropdown", values: ["US"])
```

| Parameter | Required | Purpose |
|-----------|----------|---------|
| `ref` | Yes | Ref of the `<select>` element |
| `element` | Yes | Human-readable description |
| `values` | Yes | Array of option values to select |

For native `<select>` elements only. For custom dropdowns (divs styled as dropdowns), click to open, snapshot to see options, then click the target option.

## Keyboard Input

```
Browser_browser_press_key(key: "Enter")
```

Common keys:

| Key | Use |
|-----|-----|
| `Enter` | Submit forms, confirm actions |
| `Escape` | Close modals, cancel dialogs |
| `Tab` | Move focus to next element |
| `ArrowDown` / `ArrowUp` | Navigate lists, dropdown options |
| `ArrowLeft` / `ArrowRight` | Navigate carousels, move cursor |
| `Meta+a` | Select all text in focused input |
| `Backspace` | Delete selected text or character |

## Hovering

```
Browser_browser_hover(ref: "<ref_string>", element: "User menu trigger")
```

Use for: tooltip triggers, hover menus, elements that reveal content on hover.

## Navigation

| Action | Tool |
|--------|------|
| Go to URL | `Browser_browser_navigate(url: "https://example.com")` |
| Go back | `Browser_browser_go_back()` |
| Go forward | `Browser_browser_go_forward()` |

After every navigation, take a new snapshot before interacting with the page.

## Waiting

```
Browser_browser_wait(time: 2)
```

Use when:
- Page has loading spinners or skeleton screens
- Waiting for animations to complete
- Debounced search inputs need time to trigger
- Content loads asynchronously after initial render

Default to 1-2 seconds. Only increase if the page is known to be slow.

## Screenshots

```
Browser_browser_screenshot()
```

Use for:
- Visual verification when accessibility tree doesn't convey layout
- Debugging rendering issues
- Capturing visual state for the user
- Checking images, colors, or spatial layout

Prefer snapshots over screenshots for finding elements to interact with.

## Console Logs

```
Browser_browser_get_console_logs()
```

Use for:
- Debugging JavaScript errors
- Checking network request failures
- Verifying console output from application code
- Investigating unexpected page behavior

## Common Patterns

### Fill a Form

1. Navigate to the form page
2. Snapshot to identify all input fields
3. For each field: click or focus, then type the value
4. For dropdowns: use `select_option` for native selects, click-snapshot-click for custom ones
5. Snapshot after filling to verify values
6. Click the submit button
7. Snapshot or screenshot to confirm submission

### Handle Multi-Page Flows

1. Fill current page
2. Click Next / Continue
3. Snapshot the new page before interacting
4. Repeat until complete

### Interact with Custom Dropdowns

1. Snapshot to find the dropdown trigger
2. Click the trigger to open the dropdown
3. Snapshot again to see the revealed options
4. Click the desired option
5. Snapshot to confirm selection

### Handle Modals and Dialogs

1. Trigger the modal (click a button, navigate, etc.)
2. Snapshot to get the modal's accessibility tree
3. Interact with modal contents using refs from the snapshot
4. Close by clicking close button or pressing Escape

### Debug a Page Issue

1. Screenshot to see the visual state
2. Get console logs to check for errors
3. Snapshot to inspect the DOM structure
4. Combine findings to diagnose the problem

## Limitations

| Limitation | Workaround |
|------------|------------|
| File uploads | Cannot automate — instruct the user to upload manually |
| CAPTCHAs | Cannot solve — flag to the user |
| Browser extensions | Not available in MCP browser context |
| Cross-origin iframes | May not appear in snapshots — try navigating directly to iframe URL |
| Downloads | Cannot trigger or manage file downloads |
