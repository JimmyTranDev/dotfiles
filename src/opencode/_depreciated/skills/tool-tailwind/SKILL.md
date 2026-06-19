---
name: tool-tailwind
description: Tailwind CSS patterns covering utility classes, custom config, plugins, dark mode, responsive design, cn() helper, and component composition
---

## Utility Class Patterns

| Category | Classes | Example |
|----------|---------|---------|
| Spacing | `p-{0-96}`, `m-{0-96}`, `gap-{0-96}` | `p-4 mx-auto gap-6` |
| Sizing | `w-{0-96}`, `h-{0-96}`, `size-{0-96}` | `w-full h-screen size-10` |
| Flexbox | `flex`, `flex-col`, `items-center`, `justify-between` | `flex items-center gap-4` |
| Grid | `grid`, `grid-cols-{1-12}`, `col-span-{1-12}` | `grid grid-cols-3 gap-4` |
| Typography | `text-{xs-9xl}`, `font-{thin-black}`, `leading-{none-loose}` | `text-lg font-semibold` |
| Colors | `text-{color}-{50-950}`, `bg-{color}-{50-950}` | `text-zinc-900 bg-white` |
| Borders | `border`, `border-{0-8}`, `rounded-{none-full}` | `border rounded-lg` |
| Shadows | `shadow-{sm-2xl}`, `shadow-none` | `shadow-md` |
| Transitions | `transition-{all,colors,opacity,shadow,transform}` | `transition-colors duration-200` |

## Custom Config

```ts
import type { Config } from "tailwindcss";

export default {
  content: ["./src/**/*.{ts,tsx}"],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        brand: {
          50: "#eff6ff",
          500: "#3b82f6",
          900: "#1e3a5f",
        },
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "sans-serif"],
      },
      animation: {
        "fade-in": "fadeIn 0.2s ease-in-out",
      },
      keyframes: {
        fadeIn: {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
      },
    },
  },
  plugins: [],
} satisfies Config;
```

## cn() Helper Pattern

```ts
import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

Usage in components:

```tsx
interface ButtonProps {
  variant?: "primary" | "secondary" | "ghost";
  size?: "sm" | "md" | "lg";
  className?: string;
  children: React.ReactNode;
}

const variantStyles = {
  primary: "bg-brand-500 text-white hover:bg-brand-600",
  secondary: "bg-zinc-100 text-zinc-900 hover:bg-zinc-200",
  ghost: "text-zinc-600 hover:bg-zinc-100",
} as const;

const sizeStyles = {
  sm: "px-3 py-1.5 text-sm",
  md: "px-4 py-2 text-base",
  lg: "px-6 py-3 text-lg",
} as const;

export function Button({ variant = "primary", size = "md", className, children }: ButtonProps) {
  return (
    <button className={cn("inline-flex items-center justify-center rounded-md font-medium transition-colors", variantStyles[variant], sizeStyles[size], className)}>
      {children}
    </button>
  );
}
```

## Dark Mode

```html
<!-- Class-based (recommended) -->
<div class="bg-white dark:bg-zinc-900 text-zinc-900 dark:text-zinc-100">
  <p class="text-zinc-600 dark:text-zinc-400">Adapts to theme</p>
</div>
```

Toggle implementation:

```tsx
export function ThemeToggle() {
  const toggleTheme = () => {
    document.documentElement.classList.toggle("dark");
    const isDark = document.documentElement.classList.contains("dark");
    localStorage.setItem("theme", isDark ? "dark" : "light");
  };

  return <button onClick={toggleTheme}>Toggle</button>;
}
```

Init script (place in `<head>`):

```html
<script>
  if (localStorage.theme === "dark" || (!("theme" in localStorage) && window.matchMedia("(prefers-color-scheme: dark)").matches)) {
    document.documentElement.classList.add("dark");
  }
</script>
```

## Responsive Design

| Breakpoint | Min Width | Prefix |
|------------|-----------|--------|
| sm | 640px | `sm:` |
| md | 768px | `md:` |
| lg | 1024px | `lg:` |
| xl | 1280px | `xl:` |
| 2xl | 1536px | `2xl:` |

Mobile-first approach:

```html
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
  <div class="p-4 sm:p-6 lg:p-8">Responsive padding</div>
</div>

<nav class="flex flex-col sm:flex-row sm:items-center gap-4">
  <span class="text-sm sm:text-base lg:text-lg">Responsive text</span>
</nav>
```

## Component Composition Patterns

Card pattern:

```tsx
export function Card({ className, children }: { className?: string; children: React.ReactNode }) {
  return (
    <div className={cn("rounded-lg border border-zinc-200 bg-white p-6 shadow-sm dark:border-zinc-800 dark:bg-zinc-900", className)}>
      {children}
    </div>
  );
}

export function CardHeader({ className, children }: { className?: string; children: React.ReactNode }) {
  return <div className={cn("mb-4 space-y-1", className)}>{children}</div>;
}

export function CardTitle({ className, children }: { className?: string; children: React.ReactNode }) {
  return <h3 className={cn("text-lg font-semibold text-zinc-900 dark:text-zinc-100", className)}>{children}</h3>;
}
```

## Common Patterns

### Centered Layout

```html
<div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">Content</div>
```

### Stack

```html
<div class="flex flex-col gap-4">Vertical stack</div>
<div class="flex items-center gap-4">Horizontal stack</div>
```

### Form Input

```html
<input class="w-full rounded-md border border-zinc-300 px-3 py-2 text-sm placeholder:text-zinc-400 focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-100" />
```

### Badge

```html
<span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900 dark:text-green-200">Active</span>
```

### Truncation

```html
<p class="truncate">Single line truncate</p>
<p class="line-clamp-3">Multi-line clamp to 3 lines</p>
```

### Absolute Centering

```html
<div class="relative">
  <div class="absolute inset-0 flex items-center justify-center">Centered overlay</div>
</div>
```

## Arbitrary Values

```html
<div class="w-[calc(100%-2rem)]">Calc width</div>
<div class="grid-cols-[200px_1fr_200px]">Custom grid</div>
<div class="bg-[#1a1a2e]">Custom color</div>
<div class="text-[clamp(1rem,2vw,2rem)]">Fluid text</div>
<div class="top-[var(--header-height)]">CSS variable</div>
```

## Important Modifier

```html
<div class="!mt-0">Overrides any other mt- class</div>
```

Use sparingly — prefer `cn()` merging for component overrides instead of `!important`.
