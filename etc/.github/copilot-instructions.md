

# Copilot Coding Conventions

## General Guidelines

1. Write self-explanatory code; avoid redundant comments.
1. Only add files and folders when necessary.
1. Update all affected code directly when making changes.
1. Refactor repeating code into reusable components or mapping functions.
1. Follow language and project style guides for formatting and naming.
1. Use clear, concise, and meaningful commit messages.
1. Document non-trivial logic, decisions, and public APIs.
1. Handle errors gracefully and provide useful error messages.
1. Keep dependencies up to date and remove unused ones.
1. Review code for security, performance, and maintainability.
1. Test changes before merging or deploying.
1. Use version control best practices: branch naming, rebasing, and pull requests.
1. Ensure code is accessible and inclusive.
1. Use consistent naming conventions for variables, functions, and files.
1. Write modular, reusable code; avoid monolithic functions/classes.
1. Use meaningful names that convey purpose.
1. Avoid deep nesting; use early returns or helper functions to simplify logic.
1. Use consistent indentation and spacing for readability.
1. Use constants for magic numbers and strings.
1. Avoid hardcoding values; use configuration files or environment variables.
1. Write unit tests for critical functions and components.
1. Use descriptive names for test cases and assertions.
1. Follow the project's testing framework and conventions.

---


## React Conventions

### File & Component Organization
1. Use functional components unless class components are required.
1. Keep components small, focused, and split large ones into smaller units.
1. Use prop-types or TypeScript for type safety.
1. Place related files (index, types, styles, constants, utils) in the same folder as the component.
1. Keep the Props interface in the same file as the component.
1. Views should have minimal logic or state; prefer value, onChange, and formState props only.
1. Place all components in a `components` folder inside `src`.
1. Store each component's types, styles, constants, and utility functions in their respective files within the same folder.

### Functions & Variables
1. Prefer named functions for clarity and maintainability.
1. Use `export default` for the main export of a file.
1. Destructure objects and props when it reduces code verbosity.
1. Use `const` for variables that do not change; use `let` for variables that may change.
1. Use `camelCase` for variable and function names; use `PascalCase` for component and class names; use `UPPER_SNAKE_CASE` for constants.

### Hooks
1. Prefer React hooks (`useState`, `useEffect`, etc.) for state and lifecycle management.
1. Extract custom hooks into a `hooks` folder or file when reused.
1. Avoid using hooks conditionally; always call hooks at the top level of your component.
1. Use `useCallback` and `useMemo` to optimize performance for functions and values passed as props.
1. Use `useEffect` for side effects, and clean up effects when necessary.
1. Use `useRef` for mutable values that do not trigger re-renders.
1. Use `useContext` for global state management when appropriate; avoid prop drilling.
1. Use `useLayoutEffect` for DOM measurements and mutations that need to happen before the browser paints.

### Conditions
1. Use ternary operators for simple conditions; use `if` statements for complex logic.

### Testing & Documentation
1. Write Storybook stories for components and views.
1. Write unit tests for components and hooks using Jest and React Testing Library.
1. Place tests in a `__tests__` folder or alongside the component as `ComponentName.test.tsx`.
1. Aim for high coverage of critical logic and UI states.
1. Document complex components and hooks with JSDoc, including examples.
1. Add usage examples for reusable components in the README or Storybook.

---


## Neovim Lua Conventions

### File & Module Organization
1. Organize:
  - Keymap functions in `./lua/actions`.
  - Utility functions in `./lua/utils`.
  - Core logic in `./lua/core`.
  - Plugin configurations in `./lua/plugins`.
1. Use `init.lua` files to require and organize modules in folders.
1. Keep the main `init.lua` file clean by offloading configurations to separate files.
1. Organize plugins in separate folders under `./lua` with a `main.lua` entry point, `README.md`, and `LICENSE`.

### Code Style & Variables
1. Use local functions and variables unless global scope is required.
1. Use `snake_case` for variable and function names; use `PascalCase` for module and class names; use `UPPER_SNAKE_CASE` for constants.
1. Prefer descriptive names for functions, variables, and modules.
1. Use consistent indentation (2 spaces recommended).
1. Avoid magic numbers and strings; use constants where possible.

### Documentation
1. Document public functions and modules with comments or markdown files.
1. Provide usage examples for custom modules and plugins.

### Testing
1. Write tests for critical functions using a Lua testing framework (e.g., busted).
1. Place tests in a `tests` folder or alongside the module as `module_test.lua`.

### Performance
1. Avoid unnecessary global state and side effects.
1. Optimize for startup time and lazy loading where possible.

---
## Markdown

### Formatting
1. Use 1. for numbered lists, don't increment manually.
