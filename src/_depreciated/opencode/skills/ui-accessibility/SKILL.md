---
name: ui-accessibility
description: Web and mobile accessibility checklist covering WCAG compliance, semantic HTML, ARIA patterns, React Native a11y props, keyboard navigation, focus management, and a11y testing
---

Apply these patterns to make all web UI keyboard-operable, screen-reader-compatible, and WCAG AA compliant in structure, contrast, and semantics. For mobile (React Native/Expo), ensure VoiceOver (iOS) and TalkBack (Android) compatibility.

## Platform Selection

| Platform | Screen Reader | Primary API |
|----------|--------------|-------------|
| Web | NVDA, JAWS, VoiceOver | HTML semantics + ARIA |
| iOS | VoiceOver | React Native `accessibility*` props |
| Android | TalkBack | React Native `accessibility*` props |

## WCAG Compliance Levels

| Level | Requirement | Target |
|-------|-------------|--------|
| A | Minimum — content must be accessible | Always meet |
| AA | Standard — removes significant barriers | Default target |
| AAA | Enhanced — highest level of accessibility | Nice to have |

## Semantic HTML

Use the correct element for the job — avoid `<div>` and `<span>` when a semantic element exists.

| Instead of | Use | Why |
|------------|-----|-----|
| `<div onclick>` | `<button>` | Built-in keyboard, focus, role |
| `<div class="nav">` | `<nav>` | Screen readers identify navigation |
| `<div class="header">` | `<header>` | Landmark region |
| `<div class="main">` | `<main>` | Main content landmark |
| `<span class="link">` | `<a href>` | Focusable, announced as link |
| `<div class="list">` | `<ul>` / `<ol>` | Announced as list with count |
| `<div class="table">` | `<table>` | Row/column relationships preserved |

## Heading Hierarchy

- One `<h1>` per page — the page title
- Never skip levels: `h1` -> `h2` -> `h3` (not `h1` -> `h3`)
- Headings describe content sections — don't use for styling
- Use CSS for visual sizing, HTML for document structure

## ARIA Patterns

### When to Use ARIA

1. No native HTML element provides the semantics needed
2. The native element cannot be styled as required
3. Adding supplementary information (descriptions, live regions)

### Common Attributes

| Attribute | Purpose | Example |
|-----------|---------|---------|
| `aria-label` | Labels element with no visible text | Icon buttons, search inputs |
| `aria-labelledby` | Points to visible label element | Dialogs, sections |
| `aria-describedby` | Links to supplementary description | Form field errors, help text |
| `aria-expanded` | Indicates expandable state | Accordions, dropdowns |
| `aria-hidden="true"` | Hides decorative content from AT | Icons next to text labels |
| `aria-live` | Announces dynamic content changes | Toast notifications, status |
| `aria-invalid` | Marks invalid form fields | Validation errors |
| `aria-current` | Indicates current item in a set | Active nav link, current page |
| `role="alert"` | Immediate announcement | Error messages |
| `role="status"` | Polite announcement | Success messages |

### Live Regions

```html
<div aria-live="polite" aria-atomic="true">
  3 results found
</div>

<div role="alert">
  Payment failed. Please try again.
</div>
```

- `polite` — announces when user is idle (search results, status updates)
- `assertive` — interrupts immediately (errors, critical alerts)
- `aria-atomic="true"` — reads the entire region, not just changes

## Keyboard Navigation

### Required Interactions

| Component | Keys | Behavior |
|-----------|------|----------|
| Button | `Enter`, `Space` | Activate |
| Link | `Enter` | Follow |
| Dialog | `Escape` | Close |
| Tab panel | `Arrow Left/Right` | Switch tabs |
| Menu | `Arrow Up/Down` | Navigate items |
| Combobox | `Arrow Down`, `Escape` | Open list, close |
| Checkbox | `Space` | Toggle |
| Radio group | `Arrow Up/Down` | Move selection |

### Tab Order

- Interactive elements are focusable by default (`<a>`, `<button>`, `<input>`)
- Use `tabindex="0"` to add custom elements to tab order
- Use `tabindex="-1"` for programmatic focus only (not in tab order)
- Never use `tabindex` > 0 — it breaks natural order

## Focus Management

### Modal Dialogs

1. Move focus to first focusable element (or the dialog itself) on open
2. Trap focus inside — Tab cycles within dialog
3. Restore focus to trigger element on close
4. Prevent interaction with content behind the dialog

### Route Changes (SPA)

1. Move focus to the new page heading or main content
2. Announce page title change via `document.title` or live region
3. Ensure back button focus is restored properly

### Focus Visibility

- Never remove `outline` without a visible replacement
- Use `:focus-visible` for keyboard-only focus indicators
- Minimum 3:1 contrast ratio for focus indicators (WCAG 1.4.11)

## Color and Contrast

| Content | Minimum Ratio | Level |
|---------|--------------|-------|
| Normal text (<18px) | 4.5:1 | AA |
| Large text (>=18px bold, >=24px) | 3:1 | AA |
| UI components & graphics | 3:1 | AA |
| Focus indicators | 3:1 | AA |
| Enhanced normal text | 7:1 | AAA |

- Never convey information by color alone — add icons, text, or patterns
- Test with simulated color blindness (protanopia, deuteranopia, tritanopia)

## Motion and Animation

- Respect `prefers-reduced-motion` for all animations (see **ui-animator** skill for implementation patterns)
- No auto-playing content that flashes more than 3 times per second
- Provide pause/stop controls for moving content

## Forms

- Every input needs an accessible name (`<label>`, `aria-label`, or `aria-labelledby`)
- Group related fields with `<fieldset>` and `<legend>`
- Associate error messages with `aria-describedby` and mark fields `aria-invalid="true"`
- Announce errors via `role="alert"` or `aria-live="assertive"`
- Don't rely solely on placeholder text — it disappears on input and has poor contrast

## Images and Media

| Type | Approach |
|------|----------|
| Informative image | `alt` describes the content |
| Decorative image | `alt=""` or `aria-hidden="true"` |
| Complex image (chart) | `alt` + long description via `aria-describedby` |
| Video | Captions + audio descriptions |
| Audio | Transcript |
| SVG icon (standalone) | `role="img"` + `aria-label` |
| SVG icon (with text) | `aria-hidden="true"` on the icon |

## Testing Checklist

- [ ] Tab through entire page — all interactive elements reachable
- [ ] Activate every control with keyboard only
- [ ] Screen reader announces all content meaningfully (VoiceOver, NVDA)
- [ ] Color contrast passes AA for all text and UI elements
- [ ] Page works at 200% zoom without horizontal scroll
- [ ] `prefers-reduced-motion` disables animations
- [ ] Forms announce errors and required fields
- [ ] Images have appropriate alt text
- [ ] Heading hierarchy is logical (no skipped levels)
- [ ] Dynamic content changes are announced via live regions

## Automated Tools

| Tool | Use |
|------|-----|
| axe-core | Runtime a11y audit (framework-agnostic) |
| Lighthouse Accessibility | Chrome DevTools audit |
| WAVE | Browser extension for visual inspection |
| pa11y | CLI-based automated testing |
| @axe-core/playwright | Playwright integration for CI a11y checks |

## Mobile Accessibility (React Native / Expo)

### Core Props

| Prop | Purpose | Example |
|------|---------|---------|
| `accessibilityLabel` | Announced by screen reader (like `aria-label`) | `accessibilityLabel="Delete item"` |
| `accessibilityHint` | Describes result of action | `accessibilityHint="Removes item from cart"` |
| `accessibilityRole` | Semantic role | `"button"`, `"link"`, `"header"`, `"image"`, `"search"` |
| `accessibilityState` | Current state | `{ selected: true, disabled: false, checked: true }` |
| `accessibilityValue` | Current value | `{ min: 0, max: 100, now: 50, text: "50%" }` |
| `accessibilityLiveRegion` | Announces dynamic changes (Android) | `"polite"`, `"assertive"` |
| `importantForAccessibility` | Visibility to screen reader | `"yes"`, `"no"`, `"no-hide-descendants"` |
| `accessibilityElementsHidden` | Hide from VoiceOver (iOS) | `true` to hide decorative elements |
| `accessibilityViewIsModal` | Trap VoiceOver focus (iOS) | `true` for modals and overlays |
| `accessible` | Marks as a11y element | `true` (default for touchable) |

### Component Patterns

```tsx
<Pressable
  onPress={onDelete}
  accessibilityRole="button"
  accessibilityLabel="Delete item"
  accessibilityHint="Removes this item from your cart"
  accessibilityState={{ disabled: isLoading }}
>
  <TrashIcon accessibilityElementsHidden />
</Pressable>

<TextInput
  accessibilityLabel="Email address"
  accessibilityState={{ invalid: !!error }}
  accessibilityHint="Enter your email to sign in"
  placeholder="email@example.com"
/>

<View accessibilityRole="header">
  <Text>Shopping Cart</Text>
</View>
```

### Grouping Elements

```tsx
<View accessible accessibilityLabel="Price: $29.99, In stock">
  <Text>$29.99</Text>
  <Text>In stock</Text>
</View>
```

- Set `accessible={true}` on the parent to group children into one a11y element
- Provide a combined `accessibilityLabel` for the group

### Screen Reader Announcements

```tsx
import { AccessibilityInfo } from "react-native"

AccessibilityInfo.announceForAccessibility("Item added to cart")
```

### Focus Management

```tsx
const headerRef = useRef<View>(null)

useEffect(() => {
  if (headerRef.current) {
    AccessibilityInfo.setAccessibilityFocus(
      findNodeHandle(headerRef.current) ?? 0
    )
  }
}, [])

<View ref={headerRef} accessible accessibilityRole="header">
  <Text>New Screen Title</Text>
</View>
```

### Mobile A11y Checklist

- [ ] All interactive elements have `accessibilityRole` and `accessibilityLabel`
- [ ] Icon-only buttons have descriptive `accessibilityLabel`
- [ ] Decorative images use `accessibilityElementsHidden` or `importantForAccessibility="no"`
- [ ] Modals use `accessibilityViewIsModal` (iOS) to trap focus
- [ ] Dynamic content announces changes via `AccessibilityInfo.announceForAccessibility`
- [ ] Touch targets are at least 44x44pt (iOS) / 48x48dp (Android)
- [ ] Form errors announce via screen reader when validation fails
- [ ] Screen reader can navigate all screens without touch
- [ ] Tested with VoiceOver (iOS) and TalkBack (Android)
