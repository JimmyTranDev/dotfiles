---
name: expo-patterns
description: Expo and React Native conventions including component patterns, file-based routing, navigation, NativeWind styling, native modules, and Expo SDK usage
---

## Project Structure (Expo Router)

```
app/
├── (tabs)/
│   ├── _layout.tsx
│   ├── index.tsx
│   └── profile.tsx
├── (auth)/
│   ├── _layout.tsx
│   ├── login.tsx
│   └── register.tsx
├── [id].tsx
├── _layout.tsx
├── +not-found.tsx
└── +html.tsx
src/
├── components/
├── hooks/
├── services/
├── stores/
├── types/
└── utils/
```

- `app/` for file-based routing only — no business logic
- `src/` for all application code (components, hooks, services, stores)
- `_layout.tsx` defines layout wrappers (Stack, Tabs, Drawer)
- Route groups `(name)` organize without affecting URL paths
- Dynamic routes use `[param].tsx` or `[...catchAll].tsx`

## Component Patterns

```tsx
const ProfileCard = ({ name, avatar, onPress }: ProfileCardProps) => {
  return (
    <Pressable
      onPress={onPress}
      className="flex-row items-center gap-3 rounded-xl bg-surface0 p-4"
      accessibilityRole="button"
      accessibilityLabel={`View ${name}'s profile`}
    >
      <Image source={{ uri: avatar }} className="h-12 w-12 rounded-full" />
      <Text className="text-base font-semibold text-text">{name}</Text>
    </Pressable>
  )
}
```

- Use `View`, `Text`, `Pressable`, `Image`, `ScrollView`, `FlatList` from `react-native`
- Never use `<div>`, `<span>`, `<p>`, `<button>` — those are web-only
- `Pressable` over `TouchableOpacity` — more flexible, better API
- Always provide `accessibilityRole` and `accessibilityLabel` on interactive elements

## Styling (NativeWind / Tailwind)

```tsx
<View className="flex-1 bg-base px-4 pt-safe">
  <Text className="text-2xl font-bold text-text">Title</Text>
  <Text className="text-sm text-subtext0">Subtitle</Text>
</View>
```

- **NativeWind v4** — Tailwind CSS compiled to React Native styles
- Use `className` prop on all RN components
- Safe area: `pt-safe`, `pb-safe`, `px-safe` or `SafeAreaView`
- Platform-specific: `ios:shadow-md android:elevation-4`
- Dark mode: `dark:bg-mantle dark:text-text`
- No web-only utilities (`grid`, `cursor-pointer`, `hover:`)

### React Native Flexbox Defaults

| Property | Web Default | React Native Default |
|----------|------------|---------------------|
| `flexDirection` | `row` | `column` |
| `alignItems` | `stretch` | `stretch` |
| `flexShrink` | `1` | `0` |

## Navigation (Expo Router)

### Stack Navigation

```tsx
const StackLayout = () => {
  return (
    <Stack>
      <Stack.Screen name="index" options={{ title: "Home" }} />
      <Stack.Screen name="[id]" options={{ title: "Details" }} />
      <Stack.Screen name="modal" options={{ presentation: "modal" }} />
    </Stack>
  )
}
```

### Tab Navigation

```tsx
const TabLayout = () => {
  return (
    <Tabs>
      <Tabs.Screen
        name="index"
        options={{
          title: "Home",
          tabBarIcon: ({ color, size }) => <HomeIcon color={color} size={size} />,
        }}
      />
      <Tabs.Screen name="profile" options={{ title: "Profile" }} />
    </Tabs>
  )
}
```

### Navigation Actions

```tsx
import { router } from "expo-router"

router.push("/profile/123")
router.replace("/login")
router.back()

import { useLocalSearchParams } from "expo-router"
const { id } = useLocalSearchParams<{ id: string }>()

import { Link } from "expo-router"
<Link href="/settings" asChild>
  <Pressable><Text>Settings</Text></Pressable>
</Link>
```

## Lists

```tsx
const ItemList = ({ items }: { items: Item[] }) => {
  return (
    <FlashList
      data={items}
      renderItem={({ item }) => <ItemRow item={item} />}
      estimatedItemSize={72}
      keyExtractor={(item) => item.id}
    />
  )
}
```

- **FlashList** (`@shopify/flash-list`) over `FlatList` for performance
- Always provide `estimatedItemSize` for FlashList
- Use `keyExtractor` — never rely on index
- `SectionList` for grouped data with headers
- Never nest scrollables (`ScrollView` inside `FlatList`)

## State Management

| Scope | Tool | When |
|-------|------|------|
| Component-local | `useState`, `useReducer` | UI toggles, form inputs |
| Cross-component | Zustand | Cart, auth, preferences |
| Server state | TanStack Query | API data, caching, sync |
| Persistent | `expo-secure-store` | Tokens, secrets |
| Persistent | `@react-native-async-storage/async-storage` | Non-sensitive preferences |
| URL state | Expo Router params | Screen-specific state |

## Expo SDK Common Modules

| Module | Purpose |
|--------|---------|
| `expo-camera` | Camera access and barcode scanning |
| `expo-image-picker` | Photo/video selection from library or camera |
| `expo-file-system` | Read/write local files |
| `expo-secure-store` | Encrypted key-value storage |
| `expo-notifications` | Push and local notifications |
| `expo-location` | GPS and geolocation |
| `expo-haptics` | Haptic feedback |
| `expo-linking` | Deep linking and URL handling |
| `expo-constants` | App config values at runtime |
| `expo-device` | Device info (model, OS, etc.) |
| `expo-updates` | OTA updates |
| `expo-splash-screen` | Splash screen control |
| `expo-font` | Custom font loading |
| `expo-image` | High-performance image component |

## Error Handling

```tsx
import * as SplashScreen from "expo-splash-screen"
import { ErrorBoundary } from "react-error-boundary"

const AppFallback = ({ error, resetErrorBoundary }: FallbackProps) => (
  <View className="flex-1 items-center justify-center bg-base p-4">
    <Text className="text-lg font-bold text-red">Something went wrong</Text>
    <Text className="mt-2 text-sm text-subtext0">{error.message}</Text>
    <Pressable onPress={resetErrorBoundary} className="mt-4 rounded-lg bg-blue px-6 py-3">
      <Text className="font-semibold text-base">Try Again</Text>
    </Pressable>
  </View>
)
```

## Platform-Specific Code

```tsx
import { Platform } from "react-native"

const shadowStyle = Platform.select({
  ios: "shadow-md",
  android: "elevation-4",
  default: "shadow-md",
})

// File-based: Component.ios.tsx / Component.android.tsx
```

## Performance

- Use `expo-image` over `Image` — built-in caching, blurhash placeholders
- FlashList over FlatList for long lists
- `useCallback` for callbacks passed to list items
- Minimize bridge crossings — batch native calls
- Avoid inline objects/arrays in `style` or render — hoist to module scope
- Use `React.memo` for list items and heavy subtrees
- Profile with React DevTools and Flipper

## Environment & Config

```tsx
// app.config.ts
export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  extra: {
    apiUrl: process.env.EXPO_PUBLIC_API_URL,
  },
})

// Usage
import Constants from "expo-constants"
const apiUrl = Constants.expoConfig?.extra?.apiUrl
```

- Prefix public env vars with `EXPO_PUBLIC_`
- Use `app.config.ts` (dynamic) over `app.json` (static)
- Access config via `expo-constants` at runtime

## EAS Build & Submit

| Command | Purpose |
|---------|---------|
| `eas build --platform ios` | Build iOS binary |
| `eas build --platform android` | Build Android binary |
| `eas submit --platform ios` | Submit to App Store |
| `eas submit --platform android` | Submit to Google Play |
| `eas update` | Push OTA update |
| `eas build --profile preview` | Build for internal testing |

## Testing

| Tool | Scope |
|------|-------|
| Jest + `@testing-library/react-native` | Unit & component tests |
| Maestro | E2E UI flows |
| Detox | E2E native integration |
| `expo-test` | Expo-specific test utilities |
