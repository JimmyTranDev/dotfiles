---
name: tool-nativewind
description: NativeWind v4 patterns covering setup, className prop, dark mode, tailwind-variants integration, platform-specific styles, and safe area handling for React Native
---

## Setup (v4)

NativeWind v4 uses Tailwind CSS v4 under the hood.

**Required packages**: `nativewind`, `tailwindcss`, `react-native-reanimated`, `react-native-safe-area-context`

**Metro config** (`metro.config.js`):
```js
const { withNativeWind } = require('nativewind/metro');
const config = getDefaultConfig(__dirname);
module.exports = withNativeWind(config, { input: './global.css' });
```

**Global CSS** (`global.css`):
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

**Import in root layout**:
```tsx
import '../global.css';
```

## className Prop

NativeWind v4 uses `className` on all React Native components:

```tsx
import { View, Text, Pressable } from 'react-native';

<View className="flex-1 items-center justify-center bg-white dark:bg-black">
  <Text className="text-lg font-bold text-gray-900 dark:text-white">Hello</Text>
  <Pressable className="mt-4 rounded-lg bg-blue-500 px-6 py-3 active:bg-blue-600">
    <Text className="text-white font-semibold">Press me</Text>
  </Pressable>
</View>
```

## Dark Mode

Uses `useColorScheme()` from `nativewind`:

```tsx
import { useColorScheme } from 'nativewind';

function ThemeToggle() {
  const { colorScheme, toggleColorScheme } = useColorScheme();
  return (
    <Pressable onPress={toggleColorScheme}>
      <Text className="dark:text-white">{colorScheme}</Text>
    </Pressable>
  );
}
```

Apply dark styles with `dark:` prefix:
```tsx
<View className="bg-white dark:bg-gray-900">
  <Text className="text-black dark:text-white">Adaptive</Text>
</View>
```

## Platform-Specific Styles

Use platform prefixes:
```tsx
<View className="p-4 ios:p-6 android:p-5">
  <Text className="text-base ios:text-lg">Platform text</Text>
</View>
```

## Tailwind Variants Integration

`tailwind-variants` (tv) for component variants:

```tsx
import { tv } from 'tailwind-variants';

const button = tv({
  base: 'rounded-lg px-4 py-2 font-semibold',
  variants: {
    color: {
      primary: 'bg-blue-500 text-white',
      secondary: 'bg-gray-200 text-gray-800 dark:bg-gray-700 dark:text-white',
      danger: 'bg-red-500 text-white',
    },
    size: {
      sm: 'px-3 py-1.5 text-sm',
      md: 'px-4 py-2 text-base',
      lg: 'px-6 py-3 text-lg',
    },
  },
  defaultVariants: { color: 'primary', size: 'md' },
});

function Button({ color, size, children }) {
  return (
    <Pressable className={button({ color, size })}>
      <Text className="font-semibold text-inherit">{children}</Text>
    </Pressable>
  );
}
```

## Safe Area

Use `react-native-safe-area-context`:

```tsx
import { SafeAreaView } from 'react-native-safe-area-context';

<SafeAreaView className="flex-1 bg-white dark:bg-black">
  {/* content */}
</SafeAreaView>
```

Or with `useSafeAreaInsets()` for custom padding:
```tsx
import { useSafeAreaInsets } from 'react-native-safe-area-context';

function Screen() {
  const insets = useSafeAreaInsets();
  return <View style={{ paddingTop: insets.top }} className="flex-1">{/* ... */}</View>;
}
```

## Responsive Design

NativeWind doesn't support breakpoints the same as web Tailwind. Use platform prefixes and Dimensions/useWindowDimensions for responsive logic.

## Common Pitfalls

| Issue | Solution |
|-------|----------|
| Styles not applying | Ensure `global.css` imported in root layout |
| `className` not recognized | Component must be from `react-native` or wrapped with `cssInterop` |
| Dark mode not working | Use `useColorScheme` from `nativewind`, not `react-native` |
| Custom components | Use `cssInterop(Component, { className: 'style' })` to enable className |
| Animations | Combine with `react-native-reanimated` for animated styles |
| `gap` not working | Use `gap-*` classes (supported in RN 0.71+) |

## cssInterop for Custom Components

```tsx
import { cssInterop } from 'nativewind';
import { Image } from 'expo-image';

cssInterop(Image, { className: 'style' });

// Now supports className:
<Image className="h-40 w-40 rounded-full" source={{ uri: '...' }} />
```
