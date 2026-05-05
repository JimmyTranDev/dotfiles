---
name: specify-design
description: Specify skill for UI/UX design analysis — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`design-`

## Skills to Load

- **ui-designer**: Component architecture, layout systems, responsive design, theming
- **ui-accessibility**: WCAG compliance, semantic HTML, ARIA patterns, keyboard navigation
- **ui-animator**: Animation patterns, transitions, reduced-motion handling
- **code-conventions**: Coding conventions (optional)
- **code-follower**: Match existing patterns (optional)
- **strategy-engager**: Engagement patterns (optional)

## Agents to Launch

None specified.

## Analysis Categories

- **Component architecture**: Evaluate component composition, prop interfaces, compound patterns, and separation of layout vs content — flag overly monolithic components, prop drilling, and missing composition boundaries
- **Layout and spacing**: Audit use of layout primitives (flexbox, grid, stack patterns), spacing consistency (design tokens vs magic numbers), and container/content separation — flag inconsistent gaps, hardcoded dimensions, and missing responsive breakpoints
- **Responsive design**: Check breakpoint strategy, mobile-first vs desktop-first approach, fluid typography, container queries, and touch target sizing — flag layouts that break at common viewport widths or fail on mobile
- **Visual consistency**: Audit theming system (design tokens, color palette, typography scale, shadow/elevation system), icon usage, and border radius consistency — flag one-off values that should use tokens
- **Accessibility**: Evaluate semantic HTML, ARIA patterns, keyboard navigation, focus management, color contrast, screen reader support, and reduced motion handling — flag WCAG violations and missing a11y patterns
- **State and feedback**: Audit loading states, empty states, error states, skeleton screens, optimistic updates, and transition animations — flag missing states that leave users confused
- **Animation and motion**: Evaluate transition timing, easing curves, enter/exit animations, gesture-driven animations, and scroll-driven effects — flag jarring transitions or animations that ignore `prefers-reduced-motion`

## Severity Classification

- **Critical**: WCAG A/AA accessibility violations needing immediate attention
- **High impact**: Component architecture issues, missing responsive breakpoints
- **Medium**: Visual inconsistencies, missing states
- **Low**: Animation polish, minor spacing issues

Rank findings by impact-to-effort ratio (quick wins first).

## Scope Overrides

None — uses default scope detection.
