---
name: design
description: Analyze and improve UI/UX with accessible, responsive, and polished component design
---

Usage: /design [$ARGUMENTS]

Analyze the specified scope from a UI/UX perspective and design or improve components to be accessible, responsive, and polished. If `$ARGUMENTS` is provided, focus on that area. Otherwise, scan recent changes for UI/UX improvement opportunities.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files, components, or screens, focus on those
   - If the user describes a UI problem or feature, search the codebase to locate the relevant code
   - If no scope is given, analyze recent changes via `git diff` and `git log --oneline -20` against the base branch (prefer `develop`, fall back to `main`)
   - Detect the platform: React (web), React Native/Expo (mobile), or CLI/TUI (terminal)

2. Load applicable skills in parallel based on platform and scope:
   - **designer-ui-ux**: Always load — component architecture, layout, responsive design, theming, state handling, design tokens
   - **accessibility**: Always load — every UI change must meet WCAG/a11y standards
   - **follower**: Always load — match existing component patterns, naming, and styling conventions
   - **ux-ui-animator**: Load when scope involves transitions, animations, micro-interactions, or loading states
   - **gamification**: Load when scope involves engagement features, progress indicators, achievements, or reward loops

3. Audit the current UI/UX across these categories (reference the `designer-ui-ux` and `accessibility` skills for detailed patterns):
   - **Component structure**: semantic markup, heading hierarchy, logical DOM/view order, proper use of platform primitives, typed props with variant/size support
   - **Accessibility**: keyboard navigation, focus management, screen reader support, color contrast, ARIA/a11y props, touch targets (44pt iOS / 48dp Android), reduced motion
   - **Responsiveness**: mobile-first breakpoints, container queries, safe areas, platform-specific adaptations, graceful text truncation
   - **Visual consistency**: spacing scale, typography scale, color usage against the project's design tokens or Catppuccin Mocha theme, icon sizing
   - **State handling**: loading states (skeleton/spinner), empty states (illustration + CTA), error states (inline + banner), disabled states, selected states
   - **Interaction quality**: transitions, micro-interactions, feedback on user actions, confirmation for destructive actions, optimistic updates
   - **User flow**: confusing workflows, dead-end states, missing navigation affordances, unclear calls to action
   - **Form design**: visible labels, required indicators, validation feedback, helper text, field grouping, submit button states
   - **Performance users feel**: layout shifts, janky animations, unnecessary re-renders, slow initial paint

4. Prioritize findings:
   - Rank by user impact (high, medium, low) — how much it affects real users in frequency and severity
   - For each finding, explain what the user experiences today, why it's a problem, and what the improved version looks like
   - Present the plan and ask the user to confirm before applying changes

5. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Primary agent:
   - **designer**: Delegate all component creation and modification — new components, accessibility fixes, responsive improvements, styling updates

   Post-implementation agents (launch all applicable in parallel):
   - **reviewer**: Verify component correctness, prop interfaces, and pattern consistency
   - **auditor**: Scan for XSS vectors, unsafe dangerouslySetInnerHTML, injection risks in user-facing inputs
   - **optimizer**: Identify unnecessary re-renders, heavy bundle imports, or animation performance issues
   - **tester**: Add or update component tests covering accessibility, keyboard navigation, and edge states

6. If review agents surface issues:
   - Use **fixer** to address each finding
   - Re-run **reviewer** once more to verify (max 2 iterations)

7. After all changes are applied:
   - Run the project's test suite and build to confirm nothing is broken
   - Summarize each improvement: what the UX was before, what it is now, and why it's better
   - List follow-up UI/UX opportunities that were out of scope

8. Present follow-up UI/UX opportunities to the user:
   - List each follow-up item with a short description and estimated user impact
   - Use the question tool with `multiple: true` to ask the user which items to implement
   - For each selected item, delegate to the appropriate specialized agent to implement it

Important:
- Every component must have keyboard navigation (web) or screen reader support (mobile)
- Never skip accessibility to ship faster
- Match the project's existing styling approach (Tailwind, NativeWind, or shell formatting)
- Keep components presentational — do not introduce business logic or data fetching
- Prefer improving existing components over creating new abstractions
