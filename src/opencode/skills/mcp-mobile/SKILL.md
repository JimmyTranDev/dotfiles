---
name: mcp-mobile
description: Mobile MCP tool usage patterns for device interaction, app testing, element discovery, coordinate-based input, screenshots, and swipe gestures on iOS simulators and Android emulators
---

## Tool Overview

| Tool | Purpose |
|------|---------|
| `mobile_list_available_devices` | Discover physical devices, simulators, and emulators |
| `mobile_launch_app` | Open an app by package name |
| `mobile_terminate_app` | Stop a running app |
| `mobile_install_app` | Install .app/.apk/.ipa onto device |
| `mobile_uninstall_app` | Remove an app from device |
| `mobile_list_apps` | List all installed apps on device |
| `mobile_list_elements_on_screen` | Get element tree with coordinates and labels |
| `mobile_take_screenshot` | Capture current screen as image |
| `mobile_save_screenshot` | Save screenshot to a file path |
| `mobile_click_on_screen_at_coordinates` | Tap at specific x,y pixel coordinates |
| `mobile_double_tap_on_screen` | Double-tap at x,y coordinates |
| `mobile_long_press_on_screen_at_coordinates` | Long press at x,y with configurable duration |
| `mobile_swipe_on_screen` | Swipe in a direction from optional start point |
| `mobile_type_keys` | Type text into the currently focused element |
| `mobile_press_button` | Press hardware buttons (HOME, BACK, VOLUME_UP, etc.) |
| `mobile_open_url` | Open a URL in the device browser |
| `mobile_get_screen_size` | Get device screen dimensions in pixels |
| `mobile_set_orientation` | Change to portrait or landscape |
| `mobile_get_orientation` | Get current orientation |
| `mobile_start_screen_recording` | Begin recording device screen |
| `mobile_stop_screen_recording` | Stop recording and get file path |

## Interaction Workflow

Every device interaction follows this sequence:

1. **Discover** — call `mobile_list_available_devices` to get device identifiers
2. **Launch** — call `mobile_launch_app` with the device ID and package name
3. **Observe** — call `mobile_list_elements_on_screen` or `mobile_take_screenshot` to understand current state
4. **Act** — tap, swipe, type, or press based on element coordinates
5. **Verify** — screenshot or re-list elements to confirm the action succeeded

Never skip the observe step. Always inspect the screen before interacting.

## Device Discovery

```
mobile_list_available_devices()
```

Returns both iOS and Android devices. Each device has a unique identifier string used in all subsequent calls. Prefer booted simulators/emulators over disconnected physical devices.

## Finding Elements

```
mobile_list_elements_on_screen(device: "<device_id>")
```

Returns elements with:
- Display text or accessibility label
- Center coordinates (x, y) in pixels
- Element type

Use the returned coordinates directly in click/tap calls. Do not cache element positions — re-list after any navigation or state change.

## Tapping Elements

| Action | Tool | When |
|--------|------|------|
| Single tap | `mobile_click_on_screen_at_coordinates` | Buttons, links, inputs, list items |
| Double tap | `mobile_double_tap_on_screen` | Zoom, select text, custom gestures |
| Long press | `mobile_long_press_on_screen_at_coordinates` | Context menus, drag initiation |

Always get coordinates from `mobile_list_elements_on_screen` first. Never guess coordinates.

## Typing Text

1. Tap the input field using its coordinates
2. Call `mobile_type_keys` with the text
3. Set `submit: true` to press Enter after typing, `submit: false` to just type

```
mobile_click_on_screen_at_coordinates(device, x, y)
mobile_type_keys(device, text: "search query", submit: true)
```

## Swipe Patterns

| Direction | Effect | Common Use |
|-----------|--------|------------|
| `up` | Scroll content down | Scroll through lists, reveal lower content |
| `down` | Scroll content up | Pull to refresh, scroll back to top |
| `left` | Next item / dismiss | Carousel, delete swipe, navigate forward |
| `right` | Previous item / back | Navigate back, reveal side menu |

Optional parameters:
- `x`, `y` — start position (defaults to screen center)
- `distance` — swipe length in pixels (defaults to 400px iOS / 30% screen Android)

To scroll a specific list, set `x` and `y` to a point inside that list before swiping.

## Hardware Buttons

| Button | Platform | Use |
|--------|----------|-----|
| `HOME` | Both | Return to home screen |
| `BACK` | Android only | Navigate back |
| `VOLUME_UP` | Both | Increase volume |
| `VOLUME_DOWN` | Both | Decrease volume |
| `ENTER` | Both | Submit / confirm |
| `DPAD_CENTER` | Android TV | Select focused item |
| `DPAD_UP/DOWN/LEFT/RIGHT` | Android TV | Navigate focus |

## Screenshots

| Tool | When |
|------|------|
| `mobile_take_screenshot` | Inline visual check during interaction |
| `mobile_save_screenshot` | Save to disk for comparison or reporting |

Use screenshots to:
- Verify UI state after actions
- Debug when element listing doesn't show expected content
- Capture visual bugs or test evidence

## Screen Recording

```
mobile_start_screen_recording(device, output: "/path/to/recording.mp4")
mobile_stop_screen_recording(device)
```

Use for:
- Recording bug reproduction steps
- Capturing E2E test flow for review
- Documenting UI behavior

Set `timeLimit` to auto-stop after a maximum duration in seconds.

## App Lifecycle

| Action | Tool | Notes |
|--------|------|-------|
| Install | `mobile_install_app` | iOS sim: `.zip` or `.app` dir; Android: `.apk`; iOS device: `.ipa` |
| Launch | `mobile_launch_app` | Requires package name — find with `mobile_list_apps` |
| Terminate | `mobile_terminate_app` | Force-stop a running app |
| Uninstall | `mobile_uninstall_app` | Remove by bundle ID or package name |

Use `locale` parameter on `mobile_launch_app` to test localization (BCP 47 tags like `fr-FR,en-GB`).

## Platform Differences

| Behavior | iOS Simulator | Android Emulator |
|----------|--------------|-----------------|
| Back navigation | Swipe right or in-app button | `BACK` hardware button |
| Default swipe distance | 400px | 30% of screen dimension |
| App file format | `.app` / `.zip` | `.apk` |
| Home button | `HOME` | `HOME` |

## Common Patterns

### Scroll Until Element Found

1. List elements on screen
2. If target element not found, swipe up
3. Re-list elements
4. Repeat until found or max attempts reached

### Navigate to a Screen

1. List elements to find navigation target (tab bar item, menu item, link)
2. Tap the target using its coordinates
3. Wait briefly if animation expected
4. List elements on new screen to confirm navigation succeeded

### Fill a Form

1. List elements to identify all input fields
2. For each field: tap to focus, then type the value
3. After filling all fields, find and tap the submit button
4. Verify success by listing elements or taking a screenshot

### Test Multiple Orientations

1. Get current orientation with `mobile_get_orientation`
2. Interact and verify in current orientation
3. Switch with `mobile_set_orientation(device, "landscape")`
4. Re-list elements and verify layout adapts correctly
