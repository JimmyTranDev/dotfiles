
# Copilot Coding Conventions

## General Guidelines

1. Avoid obvious or redundant comments; code should be self-explanatory.
2. Do not add unnecessary files or folders.
3. When making changes, update all affected code directly—no need to ask for permission.
4. Refactor repeating code into reusable components or use mapping functions.
5. Follow language-specific and project-specific style guides for formatting and naming.
6. Write clear, concise, and meaningful commit messages describing the change.
7. Document non-trivial logic, decisions, and public APIs.
8. Handle errors gracefully and provide useful error messages.
9. Keep dependencies up to date and remove unused ones.
10. Review code for security, performance, and maintainability.
11. Test changes before merging or deploying.
12. Use version control best practices: branch naming, rebasing, and pull requests.

## React Conventions

### Code Style
1. Prefer named functions for clarity and maintainability.
2. Use `export default` for the main export of a file.
3. Destructure objects and props when it reduces code verbosity.

### Component Structure
1. Use functional components unless class components are required.
2. Keep components small and focused; split large components into smaller ones.
3. Use prop-types or TypeScript for type safety.
4. Name components and files consistently (e.g., `MyComponent.tsx`).
5. Place related files (types, styles, constants, utils) in the same folder as the component.
6. Keep the Props interface in the same file as the component.
7. Views should have no logic or state; they should preferrably have value, onChange and formState props only.

### Hooks
1. Prefer React hooks (`useState`, `useEffect`, etc.) for state and lifecycle management.
2. Extract custom hooks into a `hooks` folder or file when reused.
3. Avoid using hooks conditionally; always call hooks at the top level of your component.

### Testing
1. Write storybook 9 stories for components and views

### Documentation
1. Document complex components and hooks with JSDoc or markdown files.
2. Add usage examples for reusable components in the README or storybook.

### Project Structure
1. Place all components in a `components` folder inside `src`.
2. Store each component's 
  - types in a `types.ts` file within the same folder.
  - styles in a `styles.ts` file within the same folder.
  - constants in a `constants.ts` file within the same folder.
  - utility functions in a `utils.ts` file within the same folder.

## Neovim Lua Conventions

1. Place functions for keymaps in `./lua/actions` in logically named files.
2. Place helper functions used by other functions in `./lua/utils` in logically named files.
3. Place core logic in `./lua/core` in logically named files.

### Code Style
1. Use local functions and variables unless global scope is required.
2. Prefer descriptive names for functions, variables, and modules.
3. Use consistent indentation (2 spaces recommended).
4. Avoid magic numbers and strings; use constants where possible.

### Plugin Structure
1. Organize plugins in separate folders under `./lua/plugins`.
1. Organize utils in separate folders under `./lua/utils`.
1. Organize keymap actions in separate folders under `./lua/actions`.
3. Use a `init.lua` as the entry point for plugins.

### Documentation
1. Document public functions and modules with comments or markdown files.
2. Provide usage examples for custom modules and plugins.

### Testing
1. Write tests for critical functions using a Lua testing framework (e.g., busted).
2. Place tests in a `tests` folder or alongside the module as `module_test.lua`.

### Performance
1. Avoid unnecessary global state and side effects.
2. Optimize for startup time and lazy loading where possible.
