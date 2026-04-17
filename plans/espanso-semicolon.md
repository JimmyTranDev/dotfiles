# Espanso: Fix Semicolon Trigger in Number Inputs

## Overview

Espanso uses `;` as the universal trigger prefix for all expansions. Some input fields (likely number-type HTML inputs or app-specific fields) don't accept `;` as valid input, causing espanso triggers to either fail silently or interfere with typing. This spec covers investigating and fixing the issue.

## Architecture

- Config lives at `src/espanso/config/default.yml` (global settings, app filters)
- Match files at `src/espanso/match/*.yml` (trigger definitions)
- Espanso supports app-specific config overrides via `filter_title`, `filter_exec`, or separate config files per app

## Data Flow

1. User types `;` in any application
2. Espanso intercepts the keystroke and starts buffering for trigger matching
3. In number input fields, `;` is either rejected by the field or causes unexpected behavior
4. Fix: either change the trigger character, add a double-character trigger prefix, or configure espanso to not intercept in specific contexts

## Tasks

| # | File | Change | Complexity | Dependencies | Parallel? |
|---|------|--------|------------|--------------|-----------|
| 1 | Research | Investigate which apps/fields cause the issue. Test espanso behavior in: browser number inputs, terminal, native macOS number fields. Document findings. | Small | None | Yes |
| 2 | `src/espanso/config/default.yml` | Implement the chosen fix. Options: (a) Change trigger prefix from `;` to `;;` across all match files, (b) Add `filter_exec` / `filter_title` exclusions for problematic apps, (c) Use espanso's `word` trigger mode or `propagate_case` options, (d) Use `passive_only` mode for specific contexts. | Medium | 1 | Sequential |
| 3 | `src/espanso/match/personal.yml` | If option (a) is chosen, update all trigger prefixes from `;x` to `;;x`. | Small | 2 | Sequential |
| 4 | `src/espanso/match/emoticons.yml` | Same as task 3 for emoticon triggers. | Small | 2 | Sequential |

## State Changes

- Modified espanso config files (trigger prefix or filter rules)
- No new files unless app-specific config overrides are needed

## Edge Cases

- Changing trigger prefix from `;` to `;;` doubles the keystrokes — may feel slower for frequent users
- App exclusions might be too broad (excluding an entire app when only specific fields are problematic)
- Espanso's `filter_title` matching may not work reliably across all macOS apps (window title detection varies)
- Some apps may swallow the `;` keystroke entirely (not just reject it), meaning espanso never sees it

## Testing Approach

- Manual: after fix, test typing `;` triggers in a browser number input field
- Manual: verify all existing triggers still work in normal text fields
- Manual: test in the specific apps where the issue was reported

## Open Questions

### Requirements
- **Which apps/fields** specifically exhibit this problem? The Todoist task says "some inputs don't allow ; for number inputs for example" but doesn't specify which apps. Need user input to identify the exact reproduction case.
- **Is the issue that `;` is blocked by the field, or that espanso intercepts it before the field can process it?** These require different fixes.

### Architecture
- **Trigger prefix change vs app exclusion**: Changing to `;;` is the nuclear option (affects all triggers, doubles keystrokes). App-specific exclusions are surgical but require knowing which apps are affected. (Recommend: investigate first, then decide — task 1 is research)

### Risks
- Changing the trigger prefix is a breaking change for muscle memory — all existing triggers would need relearning
- Espanso v2 may handle this differently than v1 — need to verify which version is installed
