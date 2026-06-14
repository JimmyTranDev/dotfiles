---
name: code-naming
description: Naming conventions for variables, functions, files, classes, constants, enums, and modules across TypeScript, Java, and shell scripting
---

## General Principles

| Principle | Example |
|-----------|---------|
| Reveal intent | `remainingAttempts` not `r` or `count` |
| Avoid abbreviations | `configuration` not `cfg` |
| Searchable names | `MAX_RETRY_COUNT` not `3` |
| Pronounceable | `customerAddress` not `custAddr` |
| One concept per word | Pick `get`/`fetch`/`retrieve` — use one consistently |
| Domain language | Match business terms exactly |
| Scope-proportional length | Loop var `i` ok, module var needs full name |

### Verb Selection Guide

| Verb | Meaning |
|------|---------|
| `get` | Synchronous accessor, no side effects |
| `fetch` | Async network/IO call |
| `find` | Search that may return null/undefined |
| `create` | Instantiate new thing |
| `build` | Assemble from parts |
| `parse` | Convert from string/raw format |
| `format` | Convert to display string |
| `validate` | Check and return boolean or throw |
| `ensure` | Check and throw if invalid |
| `compute`/`calculate` | Derive from inputs |
| `resolve` | Determine final value from options |
| `to` | Type conversion (`toString`, `toJSON`) |

## TypeScript Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Variable | camelCase | `userEmail` |
| Function | camelCase | `getUserById` |
| Class | PascalCase | `UserService` |
| Interface | PascalCase (no `I` prefix) | `UserRepository` |
| Type alias | PascalCase | `CreateUserInput` |
| Enum | PascalCase | `OrderStatus` |
| Enum member | PascalCase | `OrderStatus.InProgress` |
| Constant | SCREAMING_SNAKE | `MAX_RETRY_COUNT` |
| Generic | Single uppercase or descriptive | `T`, `TResult`, `TInput` |
| Private field | camelCase (no underscore) | `private userId` |
| React component | PascalCase | `UserProfile` |
| Hook | camelCase with `use` prefix | `useAuth` |
| Context | PascalCase + Context | `AuthContext` |
| Higher-order fn | `with`/`create` prefix | `withAuth`, `createLogger` |

### Type Naming Patterns

| Pattern | Convention | Example |
|---------|-----------|---------|
| Props | `ComponentNameProps` | `UserCardProps` |
| State | `ComponentNameState` | `FormState` |
| API response | `EntityNameResponse` | `UserResponse` |
| API request | `CreateEntityRequest` | `CreateUserRequest` |
| Config | `EntityConfig` | `DatabaseConfig` |
| Options | `EntityOptions` | `QueryOptions` |

## Java Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Package | lowercase dotted | `com.company.project.domain` |
| Class | PascalCase | `OrderService` |
| Interface | PascalCase (adjective/noun) | `Serializable`, `UserRepository` |
| Method | camelCase | `findByEmail` |
| Variable | camelCase | `orderTotal` |
| Constant | SCREAMING_SNAKE | `DEFAULT_PAGE_SIZE` |
| Enum | PascalCase | `PaymentStatus` |
| Enum value | SCREAMING_SNAKE | `PAYMENT_PENDING` |
| Generic | Single uppercase | `T`, `E`, `K`, `V` |
| Test class | `ClassNameTest` | `OrderServiceTest` |
| Test method | `should_expectedBehavior_when_condition` | `should_throwException_when_orderNotFound` |

### Spring Naming

| Layer | Suffix | Example |
|-------|--------|---------|
| Controller | `Controller` | `UserController` |
| Service | `Service` | `UserService` |
| Repository | `Repository` | `UserRepository` |
| DTO | `Dto` or purpose | `CreateUserDto`, `UserResponse` |
| Entity | (none) | `User` |
| Config | `Config` | `SecurityConfig` |
| Exception | `Exception` | `UserNotFoundException` |

## Shell Script Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Script file | kebab-case `.sh` | `sync-links.sh` |
| Function | snake_case | `install_packages` |
| Local variable | snake_case | `local file_path` |
| Global variable | SCREAMING_SNAKE | `LOG_LEVEL` |
| Environment var | SCREAMING_SNAKE | `DATABASE_URL` |
| Constants | `readonly` SCREAMING_SNAKE | `readonly MAX_RETRIES=3` |
| Flag variable | `is_`/`has_` prefix | `is_verbose`, `has_error` |

### Script Function Prefixes

| Prefix | Meaning |
|--------|---------|
| `install_` | Install a tool/package |
| `setup_` | Configure something |
| `check_` | Verify condition (return code) |
| `ensure_` | Verify or fix |
| `get_` | Print/return a value |
| `log_` | Output formatted message |
| `run_` | Execute a subprocess |
| `cleanup_` | Remove temp files/state |

## File and Directory Naming

| Context | Convention | Example |
|---------|-----------|---------|
| TypeScript source | camelCase | `userService.ts` |
| React component | PascalCase | `UserCard.tsx` |
| Test file | `*.test.ts` / `*.spec.ts` | `userService.test.ts` |
| Config file | kebab-case | `eslint.config.ts` |
| Shell script | kebab-case | `install-deps.sh` |
| Directory | kebab-case | `user-management/` |
| CSS module | PascalCase `.module.css` | `UserCard.module.css` |
| Constant file | camelCase | `httpStatus.ts` |
| Type file | camelCase | `userTypes.ts` or colocated |
| Migration | timestamp + description | `20240101_create_users.sql` |

## Boolean Naming

| Prefix | Use Case | Example |
|--------|----------|---------|
| `is` | State/condition | `isActive`, `isLoading` |
| `has` | Possession/capability | `hasPermission`, `hasChildren` |
| `can` | Ability/permission | `canEdit`, `canDelete` |
| `should` | Recommendation/expectation | `shouldRetry`, `shouldCache` |
| `was` | Past state | `wasDeleted`, `wasSent` |
| `will` | Future intent | `willRedirect` |

## Collection Naming

| Type | Convention | Example |
|------|-----------|---------|
| Array/List | Plural noun | `users`, `orderItems` |
| Map/Dict | entity + `By` + key | `usersById`, `ordersByStatus` |
| Set | Plural or `uniqueX` | `uniqueEmails`, `visitedNodes` |
| Counts | entity + `Count` | `userCount`, `retryCount` |
| Index | entity + `Index` | `emailIndex` |

## Event Handler Naming

| Context | Pattern | Example |
|---------|---------|---------|
| React prop | `on` + Event | `onClick`, `onSubmit` |
| Handler function | `handle` + Event | `handleClick`, `handleSubmit` |
| Listener | `on` + Entity + Event | `onUserCreated` |
| Callback | `on` + Action + Result | `onFetchComplete`, `onSaveError` |

## Anti-Patterns

| Bad | Good | Reason |
|-----|------|--------|
| `data` | `users`, `orderItems` | Generic, meaningless |
| `info` | `userProfile`, `accountDetails` | Vague |
| `temp` | `pendingOrder` | No intent |
| `flag` | `isEnabled`, `shouldRetry` | No meaning |
| `val`/`value` | `discountAmount` | Context-free |
| `list`/`array` in name | Use plural noun | Redundant type info |
| `IUser` | `User` | Hungarian notation |
| `AbstractBase*` | `*` | Implementation detail leak |
| `Utils`/`Helpers` | Specific module name | Kitchen-sink class |
| `doSomething` | `calculateDiscount` | Meaningless verb |
| `processData` | `validateOrder` | What process? What data? |
| `Manager` | `OrderFulfillment` | Overloaded term |
