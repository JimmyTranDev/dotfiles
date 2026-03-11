---
name: eslint-config
description: ESLint flat config setup for TypeScript and React projects including plugin selection, rule tiers, typed linting, and common customizations
---

## Config File Format

ESLint v9+ uses flat config (`eslint.config.mjs`). Export an array of config objects via `defineConfig`.

```ts
import eslint from "@eslint/js";
import { defineConfig, globalIgnores } from "eslint/config";
import tseslint from "typescript-eslint";

export default defineConfig(
  globalIgnores(["dist/", "node_modules/", ".next/", "coverage/"]),
  eslint.configs.recommended,
  tseslint.configs.strictTypeChecked,
  tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
      },
    },
  },
);
```

## Packages to Install

```bash
pnpm add -D eslint @eslint/js typescript typescript-eslint
```

### Optional Plugins

| Plugin | Package | Purpose |
|--------|---------|---------|
| React | `eslint-plugin-react`, `eslint-plugin-react-hooks` | JSX rules, hooks rules |
| Next.js | `eslint-plugin-next` | Next.js specific rules |
| Import sorting | `eslint-plugin-simple-import-sort` | Auto-sort imports |
| Unused imports | `eslint-plugin-unused-imports` | Auto-remove unused imports |
| A11y | `eslint-plugin-jsx-a11y` | Accessibility checks for JSX |
| Tailwind | `eslint-plugin-tailwindcss` | Tailwind class order and usage |
| Vitest | `@vitest/eslint-plugin` | Vitest-specific rules |
| Prettier | `eslint-config-prettier` | Disables rules that conflict with Prettier |
| Tanstack Query | `@tanstack/eslint-plugin-query` | Correct query key usage |

## typescript-eslint Config Tiers

Pick one correctness tier and optionally add a stylistic tier.

### Correctness (pick one)

| Config | Typed | Strictness |
|--------|-------|------------|
| `tseslint.configs.recommended` | No | Baseline — almost always a bug |
| `tseslint.configs.recommendedTypeChecked` | Yes | Baseline + type-aware rules |
| `tseslint.configs.strict` | No | Opinionated superset of recommended |
| `tseslint.configs.strictTypeChecked` | Yes | Most thorough — recommended for proficient TS teams |

### Stylistic (optional, add on top)

| Config | Typed |
|--------|-------|
| `tseslint.configs.stylistic` | No |
| `tseslint.configs.stylisticTypeChecked` | Yes |

### Recommended Combination

```ts
tseslint.configs.strictTypeChecked,
tseslint.configs.stylisticTypeChecked,
```

## Typed Linting

Requires `parserOptions.projectService: true` so TypeScript's type checker runs on every file. Slower but catches far more bugs.

```ts
{
  languageOptions: {
    parserOptions: {
      projectService: true,
    },
  },
}
```

### Disable for JS Files

```ts
{
  files: ["**/*.js", "**/*.cjs", "**/*.mjs"],
  extends: [tseslint.configs.disableTypeChecked],
}
```

## Config Object Structure

Each object in the array can have:

| Key | Purpose |
|-----|---------|
| `name` | Label for debugging (`"myapp/react"`) |
| `files` | Glob patterns to match (`["**/*.tsx"]`) |
| `ignores` | Glob patterns to exclude |
| `extends` | Array of configs to inherit from |
| `plugins` | Plugin name-to-object map |
| `rules` | Rule name-to-severity map |
| `languageOptions` | Parser, ecmaVersion, globals, parserOptions |
| `settings` | Shared data available to all rules |
| `linterOptions` | `noInlineConfig`, `reportUnusedDisableDirectives` |

## Rule Severity

```ts
rules: {
  "rule-name": "off",
  "rule-name": "warn",
  "rule-name": "error",
  "rule-name": ["error", { option: "value" }],
}
```

## Recommended Custom Rules

Rules worth enabling beyond the presets:

```ts
rules: {
  "no-console": "warn",
  eqeqeq: ["error", "always"],
  "prefer-const": "error",
  "no-var": "error",
  curly: ["error", "all"],
  "no-restricted-imports": ["error", {
    patterns: [{ group: ["../*"], message: "Use absolute imports" }],
  }],
}
```

### TypeScript Overrides

```ts
rules: {
  "@typescript-eslint/no-unused-vars": ["error", {
    argsIgnorePattern: "^_",
    varsIgnorePattern: "^_",
  }],
  "@typescript-eslint/consistent-type-imports": ["error", {
    prefer: "type-imports",
    fixStyle: "inline-type-imports",
  }],
  "@typescript-eslint/no-import-type-side-effects": "error",
  "@typescript-eslint/consistent-type-definitions": ["error", "type"],
  "@typescript-eslint/no-explicit-any": "warn",
  "@typescript-eslint/no-non-null-assertion": "warn",
  "@typescript-eslint/no-floating-promises": "error",
  "@typescript-eslint/no-misused-promises": ["error", {
    checksVoidReturn: { attributes: false },
  }],
  "@typescript-eslint/await-thenable": "error",
  "@typescript-eslint/require-await": "error",
  "@typescript-eslint/restrict-template-expressions": ["error", {
    allowNumber: true,
  }],
  "@typescript-eslint/switch-exhaustiveness-check": "error",
}
```

## React Setup

```ts
import reactPlugin from "eslint-plugin-react";
import reactHooksPlugin from "eslint-plugin-react-hooks";

{
  files: ["**/*.tsx", "**/*.jsx"],
  plugins: {
    react: reactPlugin,
    "react-hooks": reactHooksPlugin,
  },
  extends: [
    reactPlugin.configs.flat.recommended,
    reactPlugin.configs.flat["jsx-runtime"],
  ],
  rules: {
    "react-hooks/rules-of-hooks": "error",
    "react-hooks/exhaustive-deps": "warn",
    "react/prop-types": "off",
    "react/self-closing-comp": "error",
    "react/jsx-no-target-blank": "error",
    "react/jsx-curly-brace-presence": ["error", "never"],
  },
  settings: {
    react: { version: "detect" },
  },
}
```

## Import Sorting

```ts
import simpleImportSort from "eslint-plugin-simple-import-sort";

{
  plugins: { "simple-import-sort": simpleImportSort },
  rules: {
    "simple-import-sort/imports": "error",
    "simple-import-sort/exports": "error",
  },
}
```

## Full Example Config

```ts
import eslint from "@eslint/js";
import { defineConfig, globalIgnores } from "eslint/config";
import reactPlugin from "eslint-plugin-react";
import reactHooksPlugin from "eslint-plugin-react-hooks";
import simpleImportSort from "eslint-plugin-simple-import-sort";
import tseslint from "typescript-eslint";

export default defineConfig(
  globalIgnores(["dist/", "node_modules/", ".next/", "coverage/"]),

  eslint.configs.recommended,
  tseslint.configs.strictTypeChecked,
  tseslint.configs.stylisticTypeChecked,

  {
    name: "typescript",
    languageOptions: {
      parserOptions: { projectService: true },
    },
    plugins: { "simple-import-sort": simpleImportSort },
    rules: {
      "no-console": "warn",
      eqeqeq: ["error", "always"],
      curly: ["error", "all"],
      "simple-import-sort/imports": "error",
      "simple-import-sort/exports": "error",
      "@typescript-eslint/no-unused-vars": ["error", {
        argsIgnorePattern: "^_",
        varsIgnorePattern: "^_",
      }],
      "@typescript-eslint/consistent-type-imports": ["error", {
        prefer: "type-imports",
        fixStyle: "inline-type-imports",
      }],
      "@typescript-eslint/consistent-type-definitions": ["error", "type"],
    },
  },

  {
    name: "react",
    files: ["**/*.tsx", "**/*.jsx"],
    plugins: {
      react: reactPlugin,
      "react-hooks": reactHooksPlugin,
    },
    extends: [
      reactPlugin.configs.flat.recommended,
      reactPlugin.configs.flat["jsx-runtime"],
    ],
    rules: {
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "warn",
      "react/prop-types": "off",
      "react/self-closing-comp": "error",
    },
    settings: { react: { version: "detect" } },
  },

  {
    name: "js-files",
    files: ["**/*.js", "**/*.cjs", "**/*.mjs"],
    extends: [tseslint.configs.disableTypeChecked],
  },
);
```

## Global Ignores

Use `globalIgnores` helper for patterns that apply to all config objects:

```ts
import { globalIgnores } from "eslint/config";

globalIgnores(["dist/", "build/", "node_modules/", ".next/", "coverage/"])
```

## Prettier Integration

Always put `eslint-config-prettier` last so it disables conflicting formatting rules:

```ts
import prettierConfig from "eslint-config-prettier";

export default defineConfig(
  eslint.configs.recommended,
  tseslint.configs.strictTypeChecked,
  prettierConfig,
);
```

## package.json Scripts

```json
{
  "scripts": {
    "lint": "eslint .",
    "lint:fix": "eslint . --fix"
  }
}
```

## Debugging Config

```bash
npx eslint --inspect-config
npx eslint --print-config src/index.ts
```

## Common Gotchas

| Issue | Fix |
|-------|-----|
| Type-checked rules on `.js` files error | Add `disableTypeChecked` for `**/*.js` files |
| `eslint.config.js` treated as CJS | Use `.mjs` extension or set `"type": "module"` in package.json |
| Slow linting | Enable `parserOptions.projectService` (faster than `project: true`) |
| Conflict between TS and ESLint rules | Use `tseslint.configs.eslintRecommended` (auto-included in presets) |
| Need TypeScript config file | Install `jiti` as dev dependency for Node.js < 22.13.0 |
| Rules not applying to `.ts` files | Ensure `files` includes `**/*.ts` or omit `files` for global application |
