---
name: review-mobile
description: React Native code review checklist covering render performance, list virtualization, memory leaks, offline handling, gesture conflicts, image optimization, and battery impact
---

## Render Performance

| Issue | Detection | Fix |
|-------|-----------|-----|
| Unnecessary re-renders | Component renders without visible prop change | Use `React.memo`, specific Zustand selectors, `useShallow` |
| Expensive renders in lists | Jank during scroll | Move complex logic out of render, use `useMemo` |
| Inline styles/objects | New object reference every render | Extract to `StyleSheet.create` or module-level const |
| Inline callbacks in lists | New function per render per item | Use `useCallback` or extract to component |
| State updates during animation | Animation stutter | Use `runOnJS` for state, keep animations on UI thread |
| Heavy component tree | Slow initial mount | Lazy load with `React.lazy` or conditional render |

## List Virtualization

| Check | Bad | Good |
|-------|-----|------|
| List component | `ScrollView` with map for 50+ items | `FlashList` or `FlatList` |
| Key extractor | Using index as key | Stable unique ID (`item.id.toString()`) |
| Item height | Variable without estimation | `estimatedItemSize` on FlashList |
| Separator | Inline View in renderItem | `ItemSeparatorComponent` prop |
| Empty state | Conditional render wrapping list | `ListEmptyComponent` prop |
| Over-rendering | No `getItemType` | Provide `getItemType` for heterogeneous lists |

### FlashList (preferred)
```tsx
<FlashList
  data={items}
  renderItem={({ item }) => <ItemComponent item={item} />}
  estimatedItemSize={80}
  keyExtractor={(item) => item.id.toString()}
/>
```

## Memory Leaks

| Source | Pattern | Fix |
|--------|---------|-----|
| Event listeners | `addEventListener` without cleanup | Return cleanup in `useEffect` |
| Timers | `setInterval` without clear | `clearInterval` in cleanup |
| Subscriptions | Zustand/EventEmitter subscribe | Unsubscribe in cleanup |
| Async state updates | `setState` after unmount | Use abort controller or mounted ref |
| Large data in state | Storing full API response | Store only needed fields |
| Image caching | No cache limits | Use `expo-image` with cache policy |

## Offline Handling

| Check | Question |
|-------|----------|
| Network detection | Using `@react-native-community/netinfo`? |
| Optimistic UI | Can user interact without waiting for network? |
| Queue operations | Are mutations queued when offline? |
| Retry logic | Exponential backoff on reconnect? |
| Stale data | Clear indicator when showing cached data? |
| Sync conflicts | Strategy for conflicting offline edits? |

## Image Optimization

| Issue | Fix |
|-------|-----|
| Using `<Image>` from RN | Use `expo-image` (better caching, blurhash, transitions) |
| No placeholder | Add `placeholder` (blurhash) for perceived performance |
| Full-size images in lists | Resize/compress on server, request appropriate size |
| No caching policy | Set `cachePolicy="memory-disk"` |
| Loading many images | Use `priority` prop, lazy load off-screen |

## Gesture Conflicts

| Conflict | Fix |
|----------|-----|
| Scroll + swipe | Use `simultaneousHandlers` in Gesture Handler |
| Tap + long press | `minDurationMs` threshold separation |
| Modal dismiss + scroll | `gestureEnabled: false` on scroll containers in modals |
| Pan + parent scroll | `activeOffsetX`/`activeOffsetY` thresholds |
| Back gesture + drawer | Disable edge swipe when drawer is open |

## Battery Impact

| Drain Source | Mitigation |
|-------------|------------|
| Frequent network polls | Use push notifications or long-poll |
| Location tracking | Request only when needed, use significant changes |
| Background timers | Minimize; use Background Fetch API |
| Animations running off-screen | Stop animations when screen not focused |
| Excessive re-renders | Profile with Flipper/React DevTools |

## Navigation Performance

| Check | Impact |
|-------|--------|
| Heavy screens in stack | Lazy load; don't mount until navigated |
| Unmounted screen updates | Pause subscriptions on unfocused screens |
| Tab screens | Only mount active tab initially |
| Deep stack | Consider reset instead of push for auth flows |

## Security

| Check | Concern |
|-------|---------|
| Sensitive data in AsyncStorage | Use `expo-secure-store` for tokens/secrets |
| API keys in bundle | Move to server or use env variables |
| Screen recording | Use `preventScreenCapture` for sensitive screens |
| Clipboard data | Clear sensitive clipboard content |
| Debug logging in prod | Strip console.log in production builds |

## Testing Considerations

| Area | Approach |
|------|----------|
| Native modules | Mock in test setup (vitest vi.mock) |
| Navigation | Test navigation state, not rendered screens |
| Async storage | Mock with in-memory implementation |
| Network requests | MSW or manual mock |
| Animations | Skip in tests (jest.useFakeTimers) |
