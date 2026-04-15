---
name: meta-structure
description: Project directory layout, file placement rules, and architectural organization for TypeScript and React applications
---

## Project Root Layout

```
src/
  app/                  # Routes / pages (Next.js, React Router, Expo Router)
  components/           # Shared UI components
  hooks/                # Shared custom hooks
  lib/                  # Core utilities, clients, and framework wrappers
  services/             # Business logic, API calls, data access
  stores/               # Global state (Zustand, Jotai, Redux)
  types/                # Shared type definitions
  consts/               # Shared constants and enums
  schemas/              # Zod schemas and validation
  config/               # App configuration (env, feature flags)
  assets/               # Static assets (images, fonts, icons)
  styles/               # Global styles, theme config, Tailwind setup
  test/                 # Test utilities, fixtures, mocks
```

## File Placement Decision Tree

| Content | Location |
|---------|----------|
| React component | `components/<componentName>/index.tsx` |
| Page / route | `app/<route>/page.tsx` or `app/<route>/index.tsx` |
| Custom hook | `hooks/<hookName>/index.ts` |
| Business logic | `services/<domainName>.ts` |
| API client / fetch wrapper | `lib/<clientName>.ts` |
| Zod schema | `schemas/<domainName>.ts` |
| Shared type / interface | `types/<domainName>.ts` |
| Shared constant / enum | `consts/<domainName>.ts` |
| Global state store | `stores/<storeName>.ts` |
| Test utility / mock | `test/<utilityName>.ts` |
| Environment config | `config/env.ts` |
| Feature flag config | `config/features.ts` |

## Component Directory Structure

Each component gets its own folder. Co-locate supporting files alongside the entry point.

```
components/
  userCard/
    index.tsx           # Component implementation and export
    types.ts            # Props and internal types
    consts.ts           # Component-specific constants
    utils.ts            # Component-specific helpers
    hooks.ts            # Component-specific hooks
    userCard.test.tsx   # Component tests
```

Rules:
- `index.tsx` is always the entry point — import as `@/components/userCard`
- Only extract supporting files when they exceed ~30 lines or are reused within the folder
- Never create a supporting file with only one small export — keep it inline in `index.tsx`

## Hook Directory Structure

```
hooks/
  useAuth/
    index.ts
    types.ts
    utils.ts
  useDebounce/
    index.ts
```

## Feature-Based Organization

For large apps, group by feature/domain rather than by type. Each feature contains its own components, hooks, services, and types.

```
src/
  features/
    auth/
      components/
        loginForm/
          index.tsx
        signupForm/
          index.tsx
      hooks/
        useAuth/
          index.ts
      services/
        authService.ts
      schemas/
        authSchemas.ts
      types/
        authTypes.ts
    dashboard/
      components/
      hooks/
      services/
      types/
  components/           # Truly shared components (buttons, inputs, layout)
  hooks/                # Truly shared hooks
  lib/                  # Framework-level utilities
```

When to use feature-based:
- More than ~15 components in `components/`
- Multiple developers working on independent features
- Clear domain boundaries exist (auth, billing, dashboard, settings)

When to keep flat structure:
- Small apps with fewer than ~15 components
- Single developer
- No clear domain boundaries

## Route / Page Structure

### Next.js (App Router)

```
app/
  layout.tsx            # Root layout
  page.tsx              # Home page
  loading.tsx           # Loading UI
  error.tsx             # Error boundary
  not-found.tsx         # 404 page
  dashboard/
    layout.tsx
    page.tsx
    settings/
      page.tsx
  api/
    users/
      route.ts
```

### Expo Router

```
app/
  _layout.tsx           # Root layout
  index.tsx             # Home screen
  (tabs)/
    _layout.tsx         # Tab navigator
    home.tsx
    profile.tsx
  (auth)/
    _layout.tsx
    login.tsx
    signup.tsx
  [id].tsx              # Dynamic route
```

### React Router (Vite)

```
app/
  routes/
    home.tsx
    dashboard.tsx
    dashboard.settings.tsx
    users.$id.tsx
  root.tsx
  routeConfig.ts
```

## Services Layer

Services contain business logic and data access. One file per domain.

```
services/
  userService.ts        # User CRUD, profile logic
  authService.ts        # Login, logout, token refresh
  notificationService.ts
```

Pattern:
```ts
export const userService = {
  getById: async (id: string): Promise<User> => { ... },
  create: async (data: CreateUserInput): Promise<User> => { ... },
  update: async (id: string, data: UpdateUserInput): Promise<User> => { ... },
  delete: async (id: string): Promise<void> => { ... },
}
```

## Lib Layer

Framework wrappers, third-party clients, and core utilities. No business logic.

```
lib/
  apiClient.ts          # Fetch/axios wrapper with auth headers
  db.ts                 # Database client (Prisma, Drizzle)
  redis.ts              # Cache client
  logger.ts             # Logging utility
  cn.ts                 # Class name merge utility (clsx + twMerge)
```

## State Management

```
stores/
  authStore.ts          # Auth state (user, token, isAuthenticated)
  uiStore.ts            # UI state (sidebar, modals, theme)
  cartStore.ts          # Domain state (shopping cart)
```

Pattern (Zustand):
```ts
type AuthState = {
  user: User | null
  isAuthenticated: boolean
  login: (credentials: Credentials) => Promise<void>
  logout: () => void
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      isAuthenticated: false,
      login: async (credentials) => { ... },
      logout: () => set({ user: null, isAuthenticated: false }),
    }),
    { name: "auth-storage" },
  ),
)
```

## Schemas Layer

Zod schemas as the single source of truth for validation and type derivation.

```
schemas/
  userSchemas.ts        # User-related schemas
  authSchemas.ts        # Auth-related schemas
  commonSchemas.ts      # Shared schemas (pagination, ids)
```

## Config Layer

```
config/
  env.ts                # Environment variable parsing (Zod + process.env)
  features.ts           # Feature flags
  navigation.ts         # Route definitions and nav config
```

## Test Organization

```
test/
  setup.ts              # Global test setup (vitest.setup.ts)
  mocks/
    handlers.ts         # MSW request handlers
    data.ts             # Factory functions for test data
  utils/
    render.tsx          # Custom render with providers
    testDb.ts           # Test database utilities
```

Co-locate unit tests next to source files. Put integration and e2e tests in `test/`.

| Test Type | Location |
|-----------|----------|
| Unit test | `components/userCard/userCard.test.tsx` |
| Hook test | `hooks/useAuth/useAuth.test.ts` |
| Service test | `services/userService.test.ts` |
| Integration test | `test/integration/<feature>.test.ts` |
| E2E test | `test/e2e/<flow>.test.ts` or `e2e/<flow>.spec.ts` (Playwright) |

## Import Aliases

Configure path aliases in `tsconfig.json` to avoid deep relative imports.

| Alias | Maps To |
|-------|---------|
| `@/*` | `src/*` |
| `@/components/*` | `src/components/*` |
| `@/lib/*` | `src/lib/*` |
| `@/test/*` | `test/*` |

Prefer `@/components/userCard` over `../../../components/userCard`.

## What This Skill Does NOT Cover

- How to write TypeScript types and patterns — see **ts-total-typescript** skill
- Naming conventions and code style rules — see **code-conventions** skill
- UI component design patterns and theming — see **ui-designer** skill
- Code deduplication and extraction — see **code-deduplicator** skill
- Merging over-separated files — see **code-consolidator** skill
