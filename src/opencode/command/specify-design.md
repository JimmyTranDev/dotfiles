---
name: specify-design
description: Analyze UI/UX design and suggest improvements for layout, responsiveness, accessibility, and visual consistency and write spec to `spec/`
---

Usage: /specify-design [scope or focus area]

Analyze the project's UI/UX design and suggest improvements — component architecture, layout systems, responsive design, accessibility, theming, and animation patterns.

$ARGUMENTS

1. Understand the project (run independent commands in parallel):
   - Explore the project structure, entry points, and key modules to understand the tech stack (React, React Native/Expo, terminal UI, etc.)
   - Run `git log --oneline -30` to understand recent development direction and momentum
   - Read key config files, READMEs, or AGENTS.md to understand the project's purpose, audience, and platform targets
   - If the user specifies a focus area, narrow analysis to that scope

2. Load all applicable skills in parallel (**ui-designer**, **ui-accessibility**, **ui-animator**, and optionally **code-conventions**, **code-follower**, **strategy-engager**), then analyze the project for design opportunities across these categories:
   - **Component architecture**: Evaluate component composition, prop interfaces, compound patterns, and separation of layout vs content — flag overly monolithic components, prop drilling, and missing composition boundaries
   - **Layout and spacing**: Audit use of layout primitives (flexbox, grid, stack patterns), spacing consistency (design tokens vs magic numbers), and container/content separation — flag inconsistent gaps, hardcoded dimensions, and missing responsive breakpoints
   - **Responsive design**: Check breakpoint strategy, mobile-first vs desktop-first approach, fluid typography, container queries, and touch target sizing — flag layouts that break at common viewport widths or fail on mobile
   - **Visual consistency**: Audit theming system (design tokens, color palette, typography scale, shadow/elevation system), icon usage, and border radius consistency — flag one-off values that should use tokens
   - **Accessibility**: Evaluate semantic HTML, ARIA patterns, keyboard navigation, focus management, color contrast, screen reader support, and reduced motion handling — flag WCAG violations and missing a11y patterns
   - **State and feedback**: Audit loading states, empty states, error states, skeleton screens, optimistic updates, and transition animations — flag missing states that leave users confused about what happened
   - **Animation and motion**: Evaluate transition timing, easing curves, enter/exit animations, gesture-driven animations, and scroll-driven effects — flag jarring transitions, missing motion, or animations that ignore `prefers-reduced-motion`

3. For each opportunity:
   - Give it a short, clear name
   - Describe the current state and the design principle it violates or underutilizes in 1-2 sentences
   - Estimate effort (small, medium, large) and impact (high, medium, low)
   - Suggest where in the codebase it would fit and which existing patterns to follow
   - Cite the specific framework (Component Architecture, Layout System, WCAG, Design Tokens, Motion Design) backing the recommendation

4. Present findings:
   - Group by category
   - Within each category, rank by impact-to-effort ratio (quick wins first, then high-impact projects)
   - Highlight the top 3 "best bang for buck" improvements across all categories
   - Flag any critical accessibility violations that need immediate attention (WCAG A/AA failures)

5. Write findings to a spec file:
   - Create the `spec/` directory if it doesn't exist (using `mkdir -p spec/`)
   - Choose filename: use the `design-` prefix followed by a descriptive kebab-case name based on the scope or key findings (e.g., `spec/design-responsive-layout.md`, `spec/design-accessibility-violations.md`)
   - If a file with the chosen name already exists, append a numeric suffix (e.g., `spec/design-responsive-layout-2.md`)
   - Write all findings to the file using the same grouped-by-category format from step 4, including effort/impact estimates and framework citations for each item
   - Print a brief summary to chat: the file path, total number of findings, and the top 3 items

6. After completing the analysis, load the **meta-skill-learnings** skill and improve any relevant skills with reusable patterns, gotchas, or anti-patterns discovered during the analysis.
