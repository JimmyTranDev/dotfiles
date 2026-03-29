---
name: stitch
description: Generate UI designs with Google Stitch, implement in a worktree, and create a PR
---

Usage: /stitch <description of what to design>

Generate AI-powered UI designs using Google Stitch, implement the chosen design in a new git worktree, then create a pull request.

$ARGUMENTS

Load the **stitch-mcp**, **accessibility**, **follower**, **worktree-workflow**, and **git-workflows** skills in parallel.

1. Determine the platform by examining the project:
   - Check for `react-native` or `expo` in `package.json` — if found, target React Native/Expo
   - Check for `react` or `next` in `package.json` — if found, target React web
   - If neither, ask the user what platform to target

2. Generate 3 design variations with Stitch:
   - List existing Stitch projects to check for a relevant project
   - If a matching project exists, list its screens and ask the user whether to use existing screens or generate new ones
   - Generate 3 distinct variations of the design based on `$ARGUMENTS`, each with a different visual approach (e.g., minimal, detailed, creative)
   - Retrieve all 3 variations in parallel using `get_screen_code` for the HTML/CSS and `get_screen_image` for the screenshots

3. Present the 3 variations to the user:
   - Show each variation's screenshot and a brief description of its design approach
   - Highlight the key differences between the 3 options (layout, typography, spacing, visual hierarchy, component patterns)
   - Ask the user to pick one variation, or specify elements to combine from multiple variations

4. Analyze the chosen design:
   - Parse the HTML/CSS structure from the selected Stitch output
   - Identify distinct components, layout patterns, and interactive elements
   - Map Stitch design tokens to the project's existing design system or Catppuccin Mocha theme
   - Note any gaps: missing states (loading, empty, error), missing interactions, or accessibility issues in the generated design

5. Plan the implementation:
   - Break the design into components that match the project's existing component granularity
   - Map each design element to the project's styling approach (Tailwind, NativeWind, or shell formatting)
   - Present the component breakdown to the user and ask for confirmation before implementing

6. Determine the base branch using the priority order from the **git-workflows** skill (`develop` > `main` > `master`)

7. Derive a kebab-case branch name from the task description (e.g., `feat-stitch-login-page`, `feat-stitch-dashboard`). Keep it short and descriptive.

8. Check for uncommitted changes on the current branch (run in parallel):
   - `git status --porcelain`
   - `git diff --cached --stat`

9. If there are staged or unstaged changes:
   - Stash them with `git stash push -m "<branch-name>"`

10. Create the worktree:
    - `git worktree add ~/Programming/wcreated/<branch-name> -b <branch-name>`

11. If changes were stashed in step 9:
    - Apply the stash in the worktree: `git stash pop` (run from the worktree directory)

12. Delegate implementation to the **designer** agent — all work happens in `~/Programming/wcreated/<branch-name>/`:
    - Provide the chosen Stitch HTML/CSS and screenshot as reference
    - Implement each component following the project's conventions
    - Translate Stitch styles to the project's styling system
    - Add accessibility: keyboard navigation, ARIA/a11y props, focus management, screen reader support
    - Add responsive behavior: mobile-first breakpoints (web) or platform-specific adaptations (mobile)
    - Handle all states: loading, empty, error, disabled, hover, focus, active

13. Stage and commit the changes using the commit format from the **git-workflows** skill:
    - `git add -A`
    - `git commit -m "✨ feat(<scope>): implement <description> from stitch design"`

14. Review and fix — launch **reviewer**, **auditor**, and **optimizer** agents in parallel:
    - All agents analyze the diff from `git diff <base-branch>...HEAD`
    - **reviewer**: verify component correctness, prop interfaces, and convention adherence
    - **auditor**: scan for XSS, injection risks, or unsafe patterns in user-facing components
    - **optimizer**: check for unnecessary re-renders, heavy imports, or animation performance issues
    - Collect all issues found by all agents

15. If issues were found:
    - Launch **fixer** agents in parallel for independent fixes across different files
    - After fixes are applied, stage and commit: `git add -A && git commit -m "🐛 fix: address review and audit findings"`
    - Run **reviewer** once more to verify the fixes are correct (max 2 iterations)

16. Push and create the PR:
    - `git push -u origin <branch-name>`
    - Create the PR with `gh pr create` targeting the base branch, with a title matching the original commit message and a body containing:
      - Which Stitch variation was chosen and why
      - Components created with brief descriptions
      - Accessibility features added
      - Issues found and fixed during pre-PR review

17. Report the PR URL to the user

Important:
- All implementation happens in the worktree directory, never in the main repo
- The Stitch design is a reference, not a literal copy — adapt it to the project's conventions and design system
- Never skip accessibility to match a design exactly
- Keep components presentational — do not add business logic or data fetching
- Match the project's existing file structure and naming patterns for new components
- If the stash pop has conflicts, notify the user and stop
- If `gh pr create` fails, report the error but do not retry
- If Stitch tools are unavailable or auth fails, notify the user and suggest running `npx @_davideast/stitch-mcp doctor`
