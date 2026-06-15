---
name: app-store-screenshots
description: Use when building App Store or Google Play screenshot pages, generating exportable marketing screenshots for iOS and/or Android apps, or creating programmatic screenshot generators with Next.js. Triggers on app store, play store, screenshots, marketing assets, html-to-image, phone mockup, android screenshots, feature graphic.
---

# App Store & Google Play Screenshots Generator

## Overview

Build a Next.js page that renders App Store **and** Google Play screenshots as **advertisements** (not UI showcases) and exports them via `html-to-image` at Apple's and Google's required resolutions. Screenshots are the single most important conversion asset on both stores.

Supported devices out of the box:
- **iPhone** (portrait) — Apple App Store
- **iPad** (portrait) — Apple App Store
- **Android Phone** (portrait) — Google Play
- **Android Tablet 7"** (portrait + landscape) — Google Play
- **Android Tablet 10"** (portrait + landscape) — Google Play
- **Feature Graphic** (landscape banner, 1024×500) — Google Play store listing header

## Core Principle

**Screenshots are advertisements, not documentation.** Every screenshot sells one idea. If you're showing UI, you're doing it wrong — you're selling a *feeling*, an *outcome*, or killing a *pain point*.

## Step 1: Ask the User These Questions

Before writing ANY code, ask the user all of these. Do not proceed until you have answers:

### Required

1. **App screenshots** — "Where are your app screenshots? (PNG files of actual device captures)"
2. **App icon** — "Where is your app icon PNG?"
3. **Brand colors** — "What are your brand colors? (accent color, text color, background preference)"
4. **Font** — "What font does your app use? (or what font do you want for the screenshots?)"
5. **Feature list** — "List your app's features in priority order. What's the #1 thing your app does?"
6. **Number of slides** — "How many screenshots do you want? (Apple allows up to 10, Google Play up to 8)"
7. **Style direction** — "What style do you want? Examples: warm/organic, dark/moody, clean/minimal, bold/colorful, gradient-heavy, flat. Share App Store screenshot references if you have any."

### Optional

8. **Target stores** — "Are you targeting Apple App Store only, Google Play only, or both? This determines which devices we generate screenshots for."
9. **iPad screenshots** — "Do you also have iPad screenshots? If so, we'll generate iPad App Store screenshots too (recommended for universal apps)."
10. **Android tablet screenshots** — "Do you have Android tablet screenshots? If yes, what tablet sizes — 7" and/or 10"? Do you have them in portrait, landscape, or both orientations?"
11. **Feature Graphic** — "Do you want a Google Play Feature Graphic (1024×500 banner shown at the top of your Play Store listing)? This is separate from phone screenshots."
12. **Component assets** — "Do you have any UI element PNGs (cards, widgets, etc.) you want as floating decorations? If not, that's fine — we'll skip them."
13. **Localized screenshots** — "Do you want screenshots in multiple languages? This helps your listing rank in regional App Stores even if your app is English-only. If yes: which languages? (e.g. en, de, es, pt, ja, ar, he)"
14. **Theme preset system** — "Do you want one art direction, or reusable visual themes (for example: clean-light, dark-bold, warm-editorial) so you can swap screenshot looks quickly?"
15. **Additional instructions** — "Any specific requirements, constraints, or preferences?"

### Derived from answers (do NOT ask — decide yourself)

Based on the user's style direction, brand colors, and app aesthetic, decide:
- **Background style**: gradient direction, colors, whether light or dark base
- **Decorative elements**: blobs, glows, geometric shapes, or none — match the style
- **Dark vs light slides**: how many of each, which features suit dark treatment
- **Typography treatment**: weight, tracking, line height — match the brand personality
- **Color palette**: derive text colors, secondary colors, shadow tints from the brand colors
- **Theme preset names**: turn vague style requests into reusable theme ids the user can switch between
- **RTL behavior**: if any locale is RTL (`ar`, `he`, `fa`, `ur`), mirror layout intentionally instead of just translating the text
- **Landscape slide layouts**: for tablet landscape slides, use caption-left + device-right composition (never try to fit two tablets side-by-side in landscape — there's not enough horizontal room)

**IMPORTANT:** If the user gives additional instructions at any point during the process, follow them. User instructions always override skill defaults.

## Step 2: Set Up the Project

### Detect Package Manager

Check what's available, use this priority: **bun > pnpm > yarn > npm**

```bash
which bun && echo "use bun" || which pnpm && echo "use pnpm" || which yarn && echo "use yarn" || echo "use npm"
```

### Scaffold (if no existing Next.js project)

```bash
# With bun:
bunx create-next-app@latest . --typescript --tailwind --app --src-dir --no-eslint --import-alias "@/*"
bun add html-to-image

# With pnpm:
pnpx create-next-app@latest . --typescript --tailwind --app --src-dir --no-eslint --import-alias "@/*"
pnpm add html-to-image

# With yarn:
yarn create next-app . --typescript --tailwind --app --src-dir --no-eslint --import-alias "@/*"
yarn add html-to-image

# With npm:
npx create-next-app@latest . --typescript --tailwind --app --src-dir --no-eslint --import-alias "@/*"
npm install html-to-image
```

### Copy the Phone Mockup

The skill includes a pre-measured iPhone mockup at `mockup.png` (co-located with this SKILL.md). Copy it to the project's `public/` directory. All other device frames (Android Phone, Android Tablets, iPad) are rendered with CSS — no additional mockup PNGs needed.

### File Structure

#### iPhone-only app (default)

```
project/
├── public/
│   ├── mockup.png              # iPhone frame (included with skill)
│   ├── app-icon.png            # User's app icon
│   └── screenshots/
│       ├── en/
│       │   ├── home.png
│       │   ├── feature-1.png
│       │   └── ...
│       ├── de/
│       └── {locale}/
├── src/app/
│   ├── layout.tsx              # Font setup
│   └── page.tsx                # The screenshot generator (single file)
└── package.json
```

If iPad screenshots are localized too, mirror the same locale structure:

```
└── screenshots-ipad/
    ├── en/
    ├── de/
    └── {locale}/
```

Single-language apps can omit the locale folder entirely — paths become `screenshots/home.png`.

#### Multi-platform app (iOS + Android)

When the user needs both Apple and Android screenshots, use a platform-based structure so every device's images are clearly separated:

```
└── screenshots/
    ├── apple/
    │   ├── iphone/
    │   │   ├── en/
    │   │   └── {locale}/
    │   └── ipad/
    │       ├── en/
    │       └── {locale}/
    └── android/
        ├── phone/
        │   ├── en/
        │   └── {locale}/
        ├── tablet-7/
        │   ├── portrait/
        │   │   └── {locale}/
        │   └── landscape/
        │       └── {locale}/
        └── tablet-10/
            ├── portrait/
            │   └── {locale}/
            └── landscape/
                └── {locale}/
```

**Only create subdirectories for devices the user actually has screenshots for.** An empty directory will cause broken image placeholders in the generator.

**Use the iPhone-only structure by default.** Switch to the platform-based structure only when the user confirms they're targeting Android as well.

**The entire generator is a single `page.tsx` file.** No routing, no extra layouts, no API routes.

### Multi-language: Locale Select

Add a `LOCALES` array and a `<select>` locale picker to the toolbar. Every slide src uses a `base` variable — no hardcoded locale paths:

```tsx
const LOCALES = ["en", "de", "es", "tr"] as const;
type Locale = typeof LOCALES[number];

const [locale, setLocale] = useState<Locale>("en");
const base = (platform: string) => `/screenshots/${platform}/${locale}`;

<select value={locale} onChange={e => setLocale(e.target.value as Locale)}>
  {LOCALES.map(l => <option key={l} value={l}>{l.toUpperCase()}</option>)}
</select>

<Phone src={`${base("apple/iphone")}/home.png`} alt="Home" />
```

### Theme Presets

```tsx
const THEMES = {
  "clean-light": { bg: "#F6F1EA", fg: "#171717", accent: "#5B7CFA", muted: "#6B7280" },
  "dark-bold":   { bg: "#0B1020", fg: "#F8FAFC", accent: "#8B5CF6", muted: "#94A3B8" },
  "warm-editorial": { bg: "#F7E8DA", fg: "#2B1D17", accent: "#D97706", muted: "#7C5A47" },
} as const;

type ThemeId = keyof typeof THEMES;
const [themeId, setThemeId] = useState<ThemeId>("clean-light");
const theme = THEMES[themeId];
```

### Font Setup

```tsx
// src/app/layout.tsx
import { YourFont } from "next/font/google";
const font = YourFont({ subsets: ["latin"] });

export default function Layout({ children }: { children: React.ReactNode }) {
  return <html><body className={font.className}>{children}</body></html>;
}
```

## Step 3: Plan the Slides

### Screenshot Framework (Narrative Arc)

| Slot | Purpose | Notes |
|------|---------|-------|
| #1 | **Hero / Main Benefit** | App icon + tagline + home screen. This is the ONLY one most people see. |
| #2 | **Differentiator** | What makes this app unique vs competitors |
| #3 | **Ecosystem** | Widgets, extensions, watch — beyond the main app. Skip if N/A. |
| #4+ | **Core Features** | One feature per slide, most important first |
| 2nd to last | **Trust Signal** | Identity/craft — "made for people who [X]" |
| Last | **More Features** | Pills listing extras + coming soon. Skip if few features. |

**Rules:**
- Each slide sells ONE idea. Never two features on one slide.
- Vary layouts across slides — never repeat the same template structure.
- Include 1-2 contrast slides (inverted bg) for visual rhythm.
- **Landscape tablets**: use caption-left + device-right layout.

## Step 4: Write Copy FIRST

### The Iron Rules

1. **One idea per headline.** Never join two things with "and."
2. **Short, common words.** 1-2 syllables. No jargon unless it's domain-specific.
3. **3-5 words per line.** Must be readable at thumbnail size in the App Store.
4. **Line breaks are intentional.** Control where lines break with `<br />`.

### Three Approaches (pick one per slide)

| Type | What it does | Example |
|------|-------------|---------|
| **Paint a moment** | You picture yourself doing it | "Check your coffee without opening the app." |
| **State an outcome** | What your life looks like after | "A home for every coffee you buy." |
| **Kill a pain** | Name a problem and destroy it | "Never waste a great bag of coffee." |

### What NEVER Works

- Feature lists as headlines
- Two ideas joined by "and"
- Vague aspirational copy
- Marketing buzzwords (unless actually AI)

### Localization Rules

- Do not literally translate — re-write for the target market.
- Re-check line breaks per locale; German/French/Portuguese often need shorter claims.
- For RTL languages (`ar`, `he`, `fa`, `ur`), set `dir="rtl"` and mirror layouts intentionally.

## Step 5: Build the Page

### Architecture

```
page.tsx
├── Constants (canvas dimensions, export sizes, frame ratios)
├── Width formula functions (phoneW, tabletPW, tabletLW, ipadW)
├── LOCALES / RTL_LOCALES / THEMES / COPY_BY_LOCALE
├── Image preload cache (preloadAllImages + img() helper)
├── Device frame components:
│   ├── Phone          — iPhone (mockup.png + pre-measured overlay)
│   ├── AndroidPhone   — Android phone (CSS-only)
│   ├── AndroidTabletP — Android tablet portrait (CSS-only)
│   ├── AndroidTabletL — Android tablet landscape (CSS-only)
│   └── IPad           — iPad (CSS-only)
├── Caption component (label + headline, scales from canvasW)
├── Decorative components (blobs, glows — based on style direction)
├── Slide components (makeSlide1..N factories for portrait,
│                     makeTabLSlide1..N factories for landscape)
├── Slide registries
├── ScreenshotPreview  — ResizeObserver scaling + hover export
└── ScreenshotsPage    — grid + toolbar + export logic
```

### Canvas Dimensions

```typescript
// Apple
const W      = 1320;  const H      = 2868; // iPhone 6.9"
const IPAD_W = 2064;  const IPAD_H = 2752; // iPad 13"

// Android phone
const AW     = 1080;  const AH     = 1920;

// Android tablet — portrait
const AT7P_W  = 1200; const AT7P_H  = 1920; // 7"
const AT10P_W = 1600; const AT10P_H = 2560; // 10"

// Android tablet — landscape
const AT7L_W  = 1920; const AT7L_H  = 1200; // 7"
const AT10L_W = 2560; const AT10L_H = 1600; // 10"

// Feature Graphic
const FGW = 1024; const FGH = 500;
```

### Export Sizes

#### iPhone (Apple required)

```typescript
const IPHONE_SIZES = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;
```

#### iPad (Apple required)

```typescript
const IPAD_SIZES = [
  { label: '13" iPad',     w: 2064, h: 2752 },
  { label: '12.9" iPad Pro', w: 2048, h: 2732 },
] as const;
```

#### Android (Google Play)

```typescript
const ANDROID_SIZES    = [{ label: "Phone",           w: 1080, h: 1920 }] as const;
const ANDROID_7P_SIZES = [{ label: '7" Portrait',     w: 1200, h: 1920 }] as const;
const ANDROID_7L_SIZES = [{ label: '7" Landscape',    w: 1920, h: 1200 }] as const;
const ANDROID_10P_SIZES= [{ label: '10" Portrait',    w: 1600, h: 2560 }] as const;
const ANDROID_10L_SIZES= [{ label: '10" Landscape',   w: 2560, h: 1600 }] as const;
const FG_SIZES         = [{ label: "Feature Graphic", w: 1024, h:  500 }] as const;
```

### Frame Aspect Ratios

```typescript
const MK_RATIO   = 1022 / 2082; // iPhone mockup
const TAB_P_RATIO = 0.667;       // tablet portrait (5:8)
const TAB_L_RATIO = 1.5;         // tablet landscape (8:5)
const IPAD_RATIO  = 0.770;       // iPad (770/1000)
```

### Width Formula Functions

```typescript
type WidthFn = (cW: number, cH: number) => number;

function phoneW(cW: number, cH: number, clamp = 0.84) {
  return Math.min(clamp, 0.72 * (cH / cW) * MK_RATIO);
}
function phoneW2(cW: number, cH: number) { return phoneW(cW, cH, 0.66); }

function tabletPW(cW: number, cH: number, clamp = 0.80) {
  return Math.min(clamp, 0.72 * (cH / cW) * TAB_P_RATIO);
}

function tabletLW(cW: number, cH: number, clamp = 0.62) {
  return Math.min(clamp, 0.75 * (cH / cW) * TAB_L_RATIO);
}

function ipadW(cW: number, cH: number, clamp = 0.75) {
  return Math.min(clamp, 0.72 * (cH / cW) * IPAD_RATIO);
}
```

### Device Frame Components

#### iPhone (PNG mockup)

```typescript
const MK_W = 1022; const MK_H = 2082;
const SC_L  = (52   / MK_W) * 100;
const SC_T  = (46   / MK_H) * 100;
const SC_W  = (918  / MK_W) * 100;
const SC_H  = (1990 / MK_H) * 100;
const SC_RX = (126  / 918)  * 100;
const SC_RY = (126  / 1990) * 100;
```

```tsx
function Phone({ src, alt, style }: { src: string; alt: string; style?: React.CSSProperties }) {
  return (
    <div style={{ position: "relative", aspectRatio: `${MK_W}/${MK_H}`, ...style }}>
      <img src={img("/mockup.png")} alt="" style={{ display: "block", width: "100%", height: "100%" }} draggable={false} />
      <div style={{
        position: "absolute", zIndex: 10, overflow: "hidden",
        left: `${SC_L}%`, top: `${SC_T}%`, width: `${SC_W}%`, height: `${SC_H}%`,
        borderRadius: `${SC_RX}% / ${SC_RY}%`,
      }}>
        <img src={src} alt={alt} style={{ display: "block", width: "100%", height: "100%", objectFit: "cover", objectPosition: "top" }} draggable={false} />
      </div>
    </div>
  );
}
```

#### Android Phone (CSS-only)

```tsx
function AndroidPhone({ src, alt, style }: { src: string; alt: string; style?: React.CSSProperties }) {
  return (
    <div style={{ position: "relative", aspectRatio: "9/19.5", ...style }}>
      <div style={{
        width: "100%", height: "100%",
        borderRadius: "8% / 4%",
        background: "linear-gradient(160deg, #2a2a2e 0%, #18181b 100%)",
        boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.08), 0 8px 40px rgba(0,0,0,0.55)",
        position: "relative", overflow: "hidden",
      }}>
        <div style={{
          position: "absolute", top: "1.5%", left: "50%",
          transform: "translateX(-50%)", width: "3%", height: "1.4%",
          borderRadius: "50%", background: "#0d0d0f",
          border: "1px solid rgba(255,255,255,0.06)", zIndex: 20,
        }} />
        <div style={{
          position: "absolute", left: "3.5%", top: "2%",
          width: "93%", height: "96%",
          borderRadius: "5.5% / 2.6%", overflow: "hidden", background: "#000",
        }}>
          <img src={src} alt={alt} style={{ display: "block", width: "100%", height: "100%", objectFit: "cover", objectPosition: "top" }} draggable={false} />
        </div>
      </div>
    </div>
  );
}
```

#### Android Tablet Portrait / Landscape and iPad

Use CSS-only frames with appropriate aspect ratios (`5/8` portrait, `8/5` landscape, `770/1000` iPad). See source repo for full implementations.

### Slide Factory Pattern

```typescript
type SlideProps = { cW: number; cH: number; locale: string };
type SlideDef   = { id: string; component: (p: SlideProps) => JSX.Element };

function makeSlide1(PhoneComp: PhoneComp, widthFn: WidthFn, basePath: string, _frameRatio: number): SlideDef {
  return {
    id: "hero",
    component: ({ cW, cH }) => {
      const fw = widthFn(cW, cH) * 100;
      return (
        <div style={{ width: "100%", height: "100%", position: "relative", background: "...", overflow: "hidden" }}>
          <Caption cW={cW} label="YOUR APP" headline={<>"Sell one<br />idea here."</>} />
          <PhoneComp src={img(`/${basePath}/home.png`)} alt="Home"
            style={{ position: "absolute", bottom: 0, width: `${fw}%`, left: "50%", transform: "translateX(-50%) translateY(13%)" }} />
        </div>
      );
    },
  };
}
```

### Landscape Slide Layout

Use **caption-left + device-right**. Never two devices side-by-side.

### Typography (Resolution-Independent)

| Element | Size | Weight |
|---------|------|--------|
| Category label | `cW * 0.028` | 600 |
| Headline | `cW * 0.09` to `cW * 0.1` | 700 |
| Hero headline | `cW * 0.1` | 700 |

## Step 6: Export

### Pre-load Images as Data URIs (CRITICAL)

`html-to-image` clones DOM into SVG — re-fetches fail non-deterministically. Fix: convert all images to base64 at load time.

```typescript
const imageCache: Record<string, string> = {};

async function preloadAllImages() {
  await Promise.all(IMAGE_PATHS.map(async (path) => {
    const resp = await fetch(path);
    const blob = await resp.blob();
    const dataUrl = await new Promise<string>((resolve) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(reader.result as string);
      reader.readAsDataURL(blob);
    });
    imageCache[path] = dataUrl;
  }));
}

function img(path: string): string {
  return imageCache[path] || path;
}
```

### Export Implementation

```typescript
import { toPng } from "html-to-image";

async function captureSlide(el: HTMLElement, w: number, h: number): Promise<string> {
  el.style.left = "0px";
  el.style.opacity = "1";
  el.style.zIndex = "-1";
  const opts = { width: w, height: h, pixelRatio: 1, cacheBust: true };
  await toPng(el, opts); // warm-up call
  const dataUrl = await toPng(el, opts);
  el.style.left = "-9999px";
  el.style.opacity = "";
  el.style.zIndex = "";
  return dataUrl;
}
```

### Key Export Rules

- **Double-call trick**: First `toPng()` loads fonts/images. Second produces clean output.
- **On-screen for capture**: Move to `left: 0` before capture.
- **Offscreen container**: `position: absolute; left: -9999px` inside `overflowX: hidden` wrapper.
- **300ms delay** between sequential exports.
- **Numbered filenames**: `01-hero-en-1320x2868.png`.
- **RGB source images**: RGBA PNGs can produce black regions in exports.

## Step 7: Final QA Gate

### Message Quality
- One idea per slide
- First slide is strongest benefit
- Readable in one second at arm's length

### Visual Quality
- No repeated layouts in sequence
- Landscape slides use caption-left + device-right
- Decorative elements support the story without blocking UI
- At least one contrast slide for rhythm

### Export Quality
- No clipped text or assets after scaling
- Screenshots correctly aligned in device frames
- Filenames sort with zero-padded prefixes
- Theme tokens applied consistently
- Localized copy still fits
- RTL slides feel designed, not just flipped

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| All slides look the same | Vary device position across slides |
| Landscape slides look broken | Caption-left + single device-right |
| Copy is too complex | "One second at arm's length" test |
| Export is blank | Double-call trick; move on-screen before capture |
| Phone screens black in export | Use `preloadAllImages()` + `img()` helper |
| Page has horizontal scroll | Add `overflowX: "hidden"` on outermost wrapper |
| Screenshots rejected by App Store | Flatten source PNGs to RGB |
