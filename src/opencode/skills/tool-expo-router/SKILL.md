---
name: tool-expo-router
description: Expo Router v55 file-based routing patterns covering layouts, dynamic routes, tabs, modals, typed routes, deep linking, and navigation utilities
---

## File-Based Routing

Routes live in `app/` directory. File path = URL path.

| File | Route |
|------|-------|
| `app/index.tsx` | `/` |
| `app/about.tsx` | `/about` |
| `app/users/[id].tsx` | `/users/:id` |
| `app/[...missing].tsx` | Catch-all (404) |
| `app/(tabs)/index.tsx` | `/` (inside tab group) |

## Layouts

`_layout.tsx` files wrap child routes:

```tsx
import { Stack } from 'expo-router';

export default function RootLayout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: 'Home' }} />
      <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
    </Stack>
  );
}
```

### Layout Types

| Component | Use Case |
|-----------|----------|
| `Stack` | Push/pop navigation |
| `Tabs` | Bottom tab navigation |
| `Drawer` | Drawer navigation |
| `Slot` | Render child without navigator |

## Tab Navigation

```tsx
import { Tabs } from 'expo-router';

export default function TabLayout() {
  return (
    <Tabs>
      <Tabs.Screen name="index" options={{ title: 'Home', tabBarIcon: ({color}) => <Icon color={color} /> }} />
      <Tabs.Screen name="settings" options={{ title: 'Settings' }} />
    </Tabs>
  );
}
```

## Groups

Parenthesized directories `(name)` create route groups without affecting the URL:

```
app/(tabs)/index.tsx    → /
app/(tabs)/explore.tsx  → /explore
app/(auth)/login.tsx    → /login
```

## Dynamic Routes

```tsx
import { useLocalSearchParams } from 'expo-router';

export default function UserScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <Text>User {id}</Text>;
}
```

## Navigation

```tsx
import { router, Link, useRouter } from 'expo-router';

// Imperative
router.push('/users/123');
router.replace('/home');
router.back();
router.navigate('/path');     // smart: push if new, pop if exists in stack
router.dismiss();             // dismiss modal
router.dismissAll();          // dismiss all modals

// Declarative
<Link href="/about">About</Link>
<Link href={{ pathname: '/users/[id]', params: { id: '123' } }}>User</Link>
```

## Modals

Present screens as modals:

```tsx
// In _layout.tsx
<Stack.Screen name="modal" options={{ presentation: 'modal' }} />
```

```tsx
// Navigate to modal
router.push('/modal');
// Dismiss
router.dismiss();
```

## Typed Routes

Enable in app config (`app.json`):
```json
{ "expo": { "experiments": { "typedRoutes": true } } }
```

Generates route types into `.expo/types`, providing autocomplete and type-checking for `href` in `<Link>` and `router.push()`.

## Deep Linking

Configure in `app.json`:
```json
{ "scheme": "myapp" }
```

Links: `myapp://path/to/screen`

Universal links require associated domains configuration in `app.json` under `ios.associatedDomains`.

## Protected Routes

Pattern: check auth in layout, redirect if needed:

```tsx
import { Redirect } from 'expo-router';

export default function ProtectedLayout() {
  const { isAuthenticated } = useAuth();
  if (!isAuthenticated) {
    return <Redirect href="/login" />;
  }
  return <Slot />;
}
```

## Route Loading States

```tsx
export default function Layout() {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ headerShown: false }} />
    </Stack>
  );
}

// Unstable: loading states per-route
export function unstable_settings() {
  return { initialRouteName: 'index' };
}
```

## Common Patterns

### Hide header for a screen
```tsx
<Stack.Screen name="screen" options={{ headerShown: false }} />
```

### Conditional initial route
```tsx
export const unstable_settings = { initialRouteName: '(tabs)' };
```

### Navigation from outside React
```tsx
import { router } from 'expo-router';
router.push('/somewhere');
```
