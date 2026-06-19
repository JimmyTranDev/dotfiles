---
name: tool-zustand
description: Zustand v5 store patterns covering slices, useShallow, persist middleware, subscriptions, selectors, async actions, testing, and React Query integration
---

## Basic Store

```tsx
import { create } from 'zustand';

interface CounterStore {
  count: number;
  increment: () => void;
  decrement: () => void;
  reset: () => void;
}

const useCounterStore = create<CounterStore>((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 })),
  decrement: () => set((state) => ({ count: state.count - 1 })),
  reset: () => set({ count: 0 }),
}));
```

## Selectors (Preventing Re-renders)

```tsx
const count = useCounterStore((state) => state.count);
const increment = useCounterStore((state) => state.increment);
```

### useShallow for Multiple Selectors

```tsx
import { useShallow } from 'zustand/react/shallow';

const { count, increment } = useCounterStore(
  useShallow((state) => ({ count: state.count, increment: state.increment }))
);
```

## Slice Pattern

Split large stores into composable slices:

```tsx
interface AuthSlice {
  user: User | null;
  login: (user: User) => void;
  logout: () => void;
}

interface SettingsSlice {
  theme: 'light' | 'dark';
  setTheme: (theme: 'light' | 'dark') => void;
}

type AppStore = AuthSlice & SettingsSlice;

const createAuthSlice: StateCreator<AppStore, [], [], AuthSlice> = (set) => ({
  user: null,
  login: (user) => set({ user }),
  logout: () => set({ user: null }),
});

const createSettingsSlice: StateCreator<AppStore, [], [], SettingsSlice> = (set) => ({
  theme: 'light',
  setTheme: (theme) => set({ theme }),
});

const useAppStore = create<AppStore>()((...a) => ({
  ...createAuthSlice(...a),
  ...createSettingsSlice(...a),
}));
```

## Async Actions

```tsx
const useStore = create<Store>((set, get) => ({
  data: null,
  isLoading: false,
  error: null,
  fetchData: async (id: string) => {
    set({ isLoading: true, error: null });
    try {
      const data = await api.fetch(id);
      set({ data, isLoading: false });
    } catch (error) {
      set({ error: error.message, isLoading: false });
    }
  },
}));
```

## Persist Middleware

```tsx
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';

const useStore = create<Store>()(
  persist(
    (set) => ({ /* state and actions */ }),
    {
      name: 'store-key',
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (state) => ({ theme: state.theme }),
    }
  )
);
```

### Persist Options

| Option | Purpose |
|--------|---------|
| `name` | Storage key |
| `storage` | Storage adapter (AsyncStorage, localStorage, etc.) |
| `partialize` | Select which state to persist |
| `version` | Schema version for migrations |
| `migrate` | Migration function between versions |
| `onRehydrateStorage` | Callback when store rehydrates |

## Subscriptions (Outside React)

Basic subscribe fires on every change with full state:

```tsx
const unsub = useStore.subscribe((state, prevState) => {
  if (state.count !== prevState.count) {
    console.log('Count changed:', prevState.count, '->', state.count);
  }
});
```

Selector-based subscribe (single key + previous value) requires the `subscribeWithSelector` middleware:
```tsx
import { subscribeWithSelector } from 'zustand/middleware';

const useStore = create<Store>()(
  subscribeWithSelector((set) => ({ /* ... */ }))
);

useStore.subscribe(
  (state) => state.count,
  (count) => { /* react to change */ },
  { fireImmediately: true }
);
```

## Get State Outside React

```tsx
const currentCount = useStore.getState().count;
useStore.getState().increment();
```

## React Query Integration

Coordinate Zustand (client state) with React Query (server state):

```tsx
const useAppStore = create<AppStore>((set) => ({
  selectedCourseId: null,
  setSelectedCourse: (id: string) => set({ selectedCourseId: id }),
}));

function CourseView() {
  const courseId = useAppStore((s) => s.selectedCourseId);

  const { data: course } = useQuery({
    queryKey: ['course', courseId],
    queryFn: () => fetchCourse(courseId!),
    enabled: !!courseId,
  });

  return <CourseCard course={course} />;
}
```

### Cache Invalidation from Store Actions

```tsx
import { useQueryClient } from '@tanstack/react-query';

function useActions() {
  const queryClient = useQueryClient();

  const updateAndInvalidate = async () => {
    useStore.getState().doSomething();
    await queryClient.invalidateQueries({ queryKey: ['relevant-data'] });
  };

  return { updateAndInvalidate };
}
```

## Testing Stores

```tsx
import { act } from '@testing-library/react';

it('should increment', () => {
  const { getState } = useCounterStore;

  act(() => { getState().increment(); });

  expect(getState().count).toBe(1);
});
```

Reset between tests:
```tsx
beforeEach(() => {
  useCounterStore.setState({ count: 0 });
});
```

## Common Pitfalls

| Issue | Fix |
|-------|-----|
| Component re-renders on unrelated state | Use specific selectors or `useShallow` |
| Stale state in async | Use `get()` inside async, not closure variable |
| Persist not working | Ensure `createJSONStorage` wraps the storage adapter |
| Middleware order matters | `persist` should be the outermost middleware |
| v5 removed the default export | Use named `import { create } from 'zustand'` |
