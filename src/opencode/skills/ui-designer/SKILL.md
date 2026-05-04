---
name: ui-designer
description: UI/UX design patterns covering component architecture, layout systems, responsive design, state handling, theming, design tokens, and platform-specific conventions for React, React Native/Expo, and terminal interfaces
---

For accessibility, see the **ui-accessibility** skill. For animations, see the **ui-animator** skill.

## Platform Component Primitives

| Concept | Web (React) | Mobile (React Native/Expo) | Terminal (CLI/TUI) |
|---------|-------------|----------------------------|---------------------|
| Container | `<div>`, `<section>`, `<article>` | `View` | Box-drawing frame |
| Text | `<p>`, `<span>`, `<h1>`-`<h6>` | `Text` | ANSI-styled string |
| Button | `<button>` | `Pressable` | Highlighted menu item |
| Text input | `<input>`, `<textarea>` | `TextInput` | Line-edit prompt |
| Image | `<img>` | `expo-image` / `Image` | ASCII art / absent |
| Scrollable list | Native scroll / virtualized | `FlatList` / `FlashList` | Paged output / scrollback |
| Link | `<a href>` | `Pressable` + router navigation | Underlined text |
| Modal/Dialog | `<dialog>` / portal | `Modal` / overlay `View` | Centered box-drawing frame |
| Dropdown | `<select>` / custom listbox | Bottom sheet / picker | Numbered menu |

## Semantic Structure

### Web

Use native HTML elements over generic `<div>`/`<span>`:

| Region | Element |
|--------|---------|
| Page header | `<header>` |
| Navigation | `<nav>` |
| Main content | `<main>` |
| Sidebar | `<aside>` |
| Content block | `<article>` / `<section>` |
| Page footer | `<footer>` |
| Form group | `<fieldset>` + `<legend>` |
| Data grid | `<table>` with `<thead>`, `<tbody>`, `<th scope>` |

### Mobile

| Pattern | Component |
|---------|-----------|
| Screen wrapper | `SafeAreaView` + `View` |
| Scrollable content | `ScrollView` (short) / `FlatList` (long) |
| Optimized long list | `FlashList` (`@shopify/flash-list`) |
| Pressable surface | `Pressable` (not `TouchableOpacity`) |
| Cached image | `expo-image` (blurhash, caching) |

### Terminal

- Box-drawing characters (`┌─┐│└─┘`) for borders
- ANSI escape codes for color and emphasis
- Column alignment via fixed-width printf formatting
- Tree-drawing characters (`├── └──`) for hierarchies

## Layout Systems

### Web — Flexbox & Grid

| Layout | Use When |
|--------|----------|
| Flexbox | Single-axis alignment (row or column) |
| Grid | Two-dimensional layout, card grids, dashboards |
| Container queries | Component-level responsive breakpoints |

```tsx
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  {items.map((item) => <Card key={item.id} {...item} />)}
</div>

<div className="flex items-center justify-between gap-2">
  <Logo />
  <nav className="flex gap-4">{links}</nav>
  <UserMenu />
</div>
```

### Mobile — Flexbox Only

React Native defaults: `flexDirection: 'column'`, `flexShrink: 0`, no CSS Grid.

```tsx
<View className="flex-1 gap-4 px-4 pt-safe">
  <View className="flex-row items-center justify-between">
    <Text className="text-xl font-bold text-text">Title</Text>
    <IconButton icon="settings" />
  </View>
  <ScrollView className="flex-1" contentContainerClassName="gap-3 pb-safe">
    {children}
  </ScrollView>
</View>
```

### Terminal

- Fixed-width columns via printf-style alignment
- Detect terminal width (`$COLUMNS` / `tput cols`) for responsive wrapping
- Truncate long values with ellipsis (`…`) rather than wrapping

## Responsive Design

### Mobile-First Breakpoints (Tailwind)

| Prefix | Min Width | Target |
|--------|-----------|--------|
| (none) | 0px | Mobile |
| `sm:` | 640px | Large phone / small tablet |
| `md:` | 768px | Tablet |
| `lg:` | 1024px | Desktop |
| `xl:` | 1280px | Large desktop |
| `2xl:` | 1536px | Ultra-wide |

Always start with mobile styles and layer up:

```tsx
<div className="px-4 py-2 md:px-6 md:py-3 lg:px-8 lg:py-4">
  <h1 className="text-xl md:text-2xl lg:text-3xl font-bold">Title</h1>
</div>
```

### Container Queries

Use when a component's layout depends on its container, not the viewport:

```tsx
<div className="@container">
  <div className="flex flex-col @md:flex-row @md:items-center gap-2">
    <Avatar />
    <UserInfo />
  </div>
</div>
```

### Mobile Platform Specifics

| Concern | Pattern |
|---------|---------|
| Safe areas | `pt-safe pb-safe` or `SafeAreaView` |
| Platform styles | `ios:shadow-md android:elevation-4` |
| Bottom tabs | `pb-safe` on tab bar content |
| Notch/island | `pt-safe` on status bar area |
| Keyboard avoidance | `KeyboardAvoidingView` / `expo-keyboard-controller` |

### Terminal Responsiveness

- Detect width: `tput cols` or `$COLUMNS`
- Narrow (<80): stack columns vertically, truncate aggressively
- Standard (80-120): side-by-side columns, standard truncation
- Wide (>120): full detail, additional columns

## Styling Approach

### Web — Tailwind CSS

- Utility-first via `className`
- CSS custom properties for theme tokens
- Component-scoped styles only when Tailwind is insufficient
- No inline `style={}` except dynamic values (calculated positions, user-set colors)
- Use `cn()` (clsx/tailwind-merge) for conditional classes

### Mobile — NativeWind

- Tailwind via `className` prop on React Native primitives
- Platform variants: `ios:` / `android:` prefixes
- No web-only utilities: `grid`, `cursor-pointer`, `hover:`
- Remember RN flex defaults differ from CSS (`column` not `row`, `shrink: 0` not `1`)

### Terminal

- Catppuccin Mocha ANSI colors for all output
- Semantic color usage: red = error, yellow = warning, green = success, blue = info
- Bold for emphasis, dim for secondary information

## Theming & Design Tokens

### Catppuccin Mocha Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `base` | `#1e1e2e` | Background |
| `mantle` | `#181825` | Secondary background |
| `crust` | `#11111b` | Deepest background |
| `surface0` | `#313244` | Surface / card |
| `surface1` | `#45475a` | Elevated surface |
| `surface2` | `#585b70` | Highest surface |
| `overlay0` | `#6c7086` | Muted text, placeholders |
| `overlay1` | `#7f849c` | Secondary text |
| `text` | `#cdd6f4` | Primary text |
| `subtext0` | `#a6adc8` | Dimmed text |
| `subtext1` | `#bac2de` | Slightly dimmed text |
| `blue` | `#89b4fa` | Primary action, links |
| `sapphire` | `#74c7ec` | Active/pressed state |
| `green` | `#a6e3a1` | Success |
| `yellow` | `#f9e2af` | Warning |
| `red` | `#f38ba8` | Error, destructive |
| `peach` | `#fab387` | Accent |
| `mauve` | `#cba6f7` | Secondary accent |
| `lavender` | `#b4befe` | Tertiary accent |

### Token Usage Rules

- Use project design tokens, never hardcoded hex values in components
- If integrating external designs (Stitch, Figma), discard their tokens and map to project tokens
- Extend `tailwind.config` theme via `extend` — never override defaults
- Keep a single source of truth for colors, spacing, typography, and radii

## Component Composition Patterns

### Variant + Size Pattern

```tsx
const variants = {
  primary: "bg-blue text-crust hover:bg-sapphire",
  secondary: "bg-surface0 text-text hover:bg-surface1",
  destructive: "bg-red text-crust hover:bg-red/80",
  ghost: "text-text hover:bg-surface0",
} as const

const sizes = {
  sm: "h-8 px-3 text-sm",
  md: "h-10 px-4 text-base",
  lg: "h-12 px-6 text-lg",
} as const

type ButtonProps = {
  variant?: keyof typeof variants
  size?: keyof typeof sizes
} & React.ButtonHTMLAttributes<HTMLButtonElement>
```

### Compound Component Pattern

```tsx
const Card = ({ children, className, ...props }: CardProps) => (
  <div className={cn("rounded-lg border border-surface1 bg-surface0", className)} {...props}>
    {children}
  </div>
)

const CardHeader = ({ children, className }: CardHeaderProps) => (
  <div className={cn("border-b border-surface1 px-4 py-3", className)}>{children}</div>
)

const CardBody = ({ children, className }: CardBodyProps) => (
  <div className={cn("px-4 py-3", className)}>{children}</div>
)

const CardFooter = ({ children, className }: CardFooterProps) => (
  <div className={cn("border-t border-surface1 px-4 py-3", className)}>{children}</div>
)
```

### Slot/Render Prop Pattern

```tsx
type ListItemProps = {
  leading?: React.ReactNode
  trailing?: React.ReactNode
  title: string
  subtitle?: string
}

const ListItem = ({ leading, trailing, title, subtitle }: ListItemProps) => (
  <div className="flex items-center gap-3 px-4 py-3">
    {leading && <div className="shrink-0">{leading}</div>}
    <div className="min-w-0 flex-1">
      <p className="truncate font-medium text-text">{title}</p>
      {subtitle && <p className="truncate text-sm text-overlay1">{subtitle}</p>}
    </div>
    {trailing && <div className="shrink-0">{trailing}</div>}
  </div>
)
```

## State Handling in UI

### Visual States Every Component Needs

| State | Web | Mobile | Terminal |
|-------|-----|--------|----------|
| Default | Base styles | Base styles | Default colors |
| Hover | `hover:` prefix | N/A | N/A |
| Pressed/Active | `active:` prefix | `active:` (NativeWind) | Inverse/bold |
| Focused | `focus-visible:` ring | System focus indicator | Bracketed/highlighted |
| Disabled | `disabled:opacity-50 disabled:pointer-events-none` | `opacity-50`, `disabled` prop | Dim text |
| Loading | Spinner/skeleton | ActivityIndicator/skeleton | Spinner character (⠋⠙⠹⠸) |
| Error | Red border + error text | Red border + error text | Red ANSI text |
| Empty | Empty state illustration + CTA | Empty state + CTA | "No items" message |
| Selected | Ring/background highlight | Background highlight | Arrow indicator (▶) |

### Loading Patterns

| Pattern | Use When |
|---------|----------|
| Skeleton | Layout is known, replacing content blocks |
| Spinner (inline) | Button submit, small area loading |
| Full-screen spinner | Initial app load, auth redirect |
| Progress bar | Upload, multi-step process |
| Optimistic update | Action is almost certain to succeed |
| Shimmer | Content cards, text blocks |

### Empty States

Every list, feed, or data view needs an empty state:

```tsx
const EmptyState = ({ icon, title, description, action }: EmptyStateProps) => (
  <div className="flex flex-col items-center justify-center gap-3 py-12 text-center">
    <div className="text-4xl text-overlay0">{icon}</div>
    <h3 className="text-lg font-medium text-text">{title}</h3>
    <p className="max-w-sm text-sm text-overlay1">{description}</p>
    {action}
  </div>
)
```

### Error States

| Error Type | UI Treatment |
|------------|-------------|
| Field validation | Inline error below field, red border |
| Form submission | Banner/toast at top with retry |
| Network failure | Full-screen retry with offline indicator |
| 404 / Not found | Friendly illustration + navigation |
| Permission denied | Explanation + request access CTA |
| Server error | "Something went wrong" + retry + support link |

## Typography Scale

### Web (Tailwind)

| Class | Size | Weight | Use For |
|-------|------|--------|---------|
| `text-xs` | 12px | normal | Captions, timestamps |
| `text-sm` | 14px | normal/medium | Secondary text, labels |
| `text-base` | 16px | normal | Body text |
| `text-lg` | 18px | medium | Subheadings |
| `text-xl` | 20px | semibold | Section titles |
| `text-2xl` | 24px | bold | Page titles |
| `text-3xl` | 30px | bold | Hero headings |

### Mobile

Same Tailwind scale via NativeWind. Add `tracking-tight` for headings, `leading-relaxed` for body.

## Spacing Scale

| Token | Value | Use For |
|-------|-------|---------|
| `gap-1` / `p-1` | 4px | Tight element spacing |
| `gap-2` / `p-2` | 8px | Related element spacing |
| `gap-3` / `p-3` | 12px | Component internal padding |
| `gap-4` / `p-4` | 16px | Standard section padding |
| `gap-6` / `p-6` | 24px | Section separation |
| `gap-8` / `p-8` | 32px | Major section gaps |
| `gap-12` / `p-12` | 48px | Page-level spacing |

Rules:
- Consistent spacing within a component (don't mix `p-3` and `p-4` in the same card)
- Increase spacing as hierarchy level increases (element < component < section < page)
- Use `gap` over margin for flex/grid children

## Touch & Click Targets

| Platform | Minimum Size | Recommendation |
|----------|-------------|----------------|
| Web (WCAG) | 24x24 CSS px | 44x44 CSS px |
| iOS (HIG) | 44x44 pt | 44x44 pt |
| Android (Material) | 48x48 dp | 48x48 dp |

Extend hit area without increasing visual size:

```tsx
<Pressable
  className="p-2"
  hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
>
  <Icon size={20} />
</Pressable>
```

## Icon Usage

| Guideline | Rule |
|-----------|------|
| Standalone icon button | Always add `aria-label` (web) or `accessibilityLabel` (mobile) |
| Icon + text label | Hide icon from AT: `aria-hidden="true"` (web) or `accessibilityElementsHidden` (mobile) |
| Icon sizing | Match text size in the same row (16-20px for body, 24px for headings) |
| Icon color | Use `currentColor` to inherit text color |
| Icon library | Use project's existing library, don't introduce a new one |

## Form Design

| Pattern | Implementation |
|---------|---------------|
| Labels | Always visible above input — never placeholder-only |
| Required indicator | Asterisk or "(required)" text, never color alone |
| Error placement | Below the field, associated via `aria-describedby` / `accessibilityLabel` |
| Success feedback | Green checkmark or text after successful validation |
| Helper text | Below input, muted color, linked via `aria-describedby` |
| Field grouping | `<fieldset>` + `<legend>` (web), labeled `View` group (mobile) |
| Submit button | Primary variant, disabled during submission, loading indicator |
| Destructive action | Confirmation dialog before executing |

## Common UI Component Checklist

- [ ] Uses platform-appropriate primitives (no `div` in RN, no `View` in web)
- [ ] Has a typed props interface with sensible defaults
- [ ] Supports variant and size props via lookup objects
- [ ] Handles all visual states (default, hover, active, focus, disabled, loading, error, empty)
- [ ] Uses project design tokens — no hardcoded colors or spacing
- [ ] Responsive: mobile-first breakpoints (web) or safe areas + platform variants (mobile)
- [ ] Text truncates gracefully with `truncate` / `numberOfLines`
- [ ] Forwarded `className` or `style` prop for parent overrides
- [ ] Accepts and spreads remaining props (`...props`) for extensibility
- [ ] No business logic — purely presentational
