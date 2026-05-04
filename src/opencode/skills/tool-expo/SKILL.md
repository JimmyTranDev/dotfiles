---
name: tool-expo
description: Expo SDK 55 patterns covering app config, environment variables, native modules, splash screen, dev client, EAS reference, and common troubleshooting
---

## App Configuration

**File**: `app.json` or `app.config.ts` (dynamic config)

```ts
import { ExpoConfig, ConfigContext } from 'expo/config';

export default ({ config }: ConfigContext): ExpoConfig => ({
  name: 'MyApp',
  slug: 'my-app',
  version: '1.0.0',
  orientation: 'portrait',
  icon: './assets/icon.png',
  scheme: 'myapp',
  userInterfaceStyle: 'automatic',
  newArchEnabled: true,
  plugins: [
    'expo-router',
    ['expo-splash-screen', { image: './assets/splash.png', resizeMode: 'contain' }],
    ['expo-build-properties', { ios: { newArchEnabled: true }, android: { newArchEnabled: true } }],
  ],
  ios: { bundleIdentifier: 'com.example.myapp', supportsTablet: true },
  android: { package: 'com.example.myapp', adaptiveIcon: { foregroundImage: './assets/adaptive-icon.png' } },
  extra: { eas: { projectId: '...' } },
});
```

## Environment Variables

### In app code (client-side)
```ts
import Constants from 'expo-constants';
const apiUrl = Constants.expoConfig?.extra?.apiUrl;
```

### In app.config.ts
```ts
extra: {
  apiUrl: process.env.API_URL ?? 'https://default.com',
},
```

### EAS Build environment
Set in `eas.json` under `build.{profile}.env` or as EAS Secrets.

## Splash Screen (SDK 55)

```ts
import * as SplashScreen from 'expo-splash-screen';

SplashScreen.preventAutoHideAsync();

// After app is ready:
SplashScreen.hideAsync();
```

Plugin config in `app.json`:
```json
["expo-splash-screen", {
  "image": "./assets/splash.png",
  "resizeMode": "contain",
  "backgroundColor": "#ffffff"
}]
```

## Dev Client

```bash
npx expo start --dev-client    # Start with custom dev client
npx expo run:ios               # Build native iOS
npx expo run:android           # Build native Android
```

Use `expo-dev-client` when you need custom native modules not in Expo Go.

## Common Native Modules

| Package | Purpose | Requires dev client? |
|---------|---------|---------------------|
| `expo-sqlite` | SQLite database | No (Expo Go) |
| `expo-file-system` | File I/O | No |
| `expo-secure-store` | Encrypted key-value | No |
| `expo-crypto` | Crypto operations | No |
| `expo-haptics` | Haptic feedback | No |
| `expo-audio` | Audio playback | No |
| `expo-notifications` | Push notifications | Yes |

## Updates (OTA)

```ts
import * as Updates from 'expo-updates';

const update = await Updates.checkForUpdateAsync();
if (update.isAvailable) {
  await Updates.fetchUpdateAsync();
  await Updates.reloadAsync();
}
```

## EAS Reference

- Build: `eas build --platform ios --profile production`
- Update: `eas update --branch production --message "description"`
- Submit: `eas submit --platform ios`
- Config: `eas.json` defines build profiles (development, preview, production)

See [EAS docs](https://docs.expo.dev/eas/) for full configuration.

## Common Troubleshooting

| Issue | Fix |
|-------|-----|
| Metro bundler cache | `npx expo start --clear` |
| Native module not found | Run `npx expo run:ios` to rebuild native |
| Pods out of date | `cd ios && pod install --repo-update` |
| Android build failure | Check `android/gradle.properties` memory: `org.gradle.jvmargs=-Xmx4g` |
| Type errors in config | Use `app.config.ts` with `ExpoConfig` type |
| Environment variable undefined | Must be in `extra` field, accessed via `Constants.expoConfig.extra` |
