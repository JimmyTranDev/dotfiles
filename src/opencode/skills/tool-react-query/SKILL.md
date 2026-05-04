---
name: tool-react-query
description: TanStack Query patterns covering queries, mutations, invalidation, optimistic updates, prefetching, infinite queries, SSR hydration, and devtools
---

## QueryClient Setup

```tsx
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,
      gcTime: 10 * 60 * 1000,
      retry: 3,
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 1,
    },
  },
});

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}
```

## useQuery Patterns

```tsx
import { useQuery } from "@tanstack/react-query";

export function useUsers() {
  return useQuery({
    queryKey: ["users"],
    queryFn: () => api.getUsers(),
  });
}

export function useUser(id: string) {
  return useQuery({
    queryKey: ["users", id],
    queryFn: () => api.getUser(id),
    enabled: !!id,
  });
}

export function useFilteredPosts(filters: PostFilters) {
  return useQuery({
    queryKey: ["posts", filters],
    queryFn: () => api.getPosts(filters),
    placeholderData: (previousData) => previousData,
  });
}
```

## useMutation Patterns

```tsx
import { useMutation, useQueryClient } from "@tanstack/react-query";

export function useCreateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: CreateUserInput) => api.createUser(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
    onError: (error) => {
      toast.error(error.message);
    },
  });
}

export function useDeleteUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => api.deleteUser(id),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: ["users", id] });
      queryClient.invalidateQueries({ queryKey: ["users"] });
    },
  });
}
```

## Query Invalidation

| Pattern | Code |
|---------|------|
| Exact key | `queryClient.invalidateQueries({ queryKey: ["users", id] })` |
| Prefix match | `queryClient.invalidateQueries({ queryKey: ["users"] })` |
| All queries | `queryClient.invalidateQueries()` |
| Predicate | `queryClient.invalidateQueries({ predicate: (q) => q.queryKey[0] === "users" })` |
| Refetch active | `queryClient.refetchQueries({ queryKey: ["users"], type: "active" })` |
| Remove from cache | `queryClient.removeQueries({ queryKey: ["users", id] })` |
| Set data directly | `queryClient.setQueryData(["users", id], updatedUser)` |

## Optimistic Updates

```tsx
export function useUpdateTodo() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (todo: UpdateTodoInput) => api.updateTodo(todo),
    onMutate: async (newTodo) => {
      await queryClient.cancelQueries({ queryKey: ["todos", newTodo.id] });
      const previous = queryClient.getQueryData<Todo>(["todos", newTodo.id]);
      queryClient.setQueryData<Todo>(["todos", newTodo.id], (old) => ({
        ...old!,
        ...newTodo,
      }));
      return { previous };
    },
    onError: (_err, newTodo, context) => {
      if (context?.previous) {
        queryClient.setQueryData(["todos", newTodo.id], context.previous);
      }
    },
    onSettled: (_data, _err, newTodo) => {
      queryClient.invalidateQueries({ queryKey: ["todos", newTodo.id] });
    },
  });
}
```

## Prefetching

```tsx
export function usePrefetchUser(id: string) {
  const queryClient = useQueryClient();

  const prefetch = () => {
    queryClient.prefetchQuery({
      queryKey: ["users", id],
      queryFn: () => api.getUser(id),
      staleTime: 5 * 60 * 1000,
    });
  };

  return { prefetch };
}

// Usage: prefetch on hover
<Link onMouseEnter={() => prefetch()}>View User</Link>
```

Router loader prefetch:

```ts
export const userLoader = (queryClient: QueryClient) => async ({ params }: { params: { id: string } }) => {
  await queryClient.ensureQueryData({
    queryKey: ["users", params.id],
    queryFn: () => api.getUser(params.id),
  });
  return null;
};
```

## Infinite Queries

```tsx
export function useInfinitePosts() {
  return useInfiniteQuery({
    queryKey: ["posts"],
    queryFn: ({ pageParam }) => api.getPosts({ cursor: pageParam, limit: 20 }),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor,
    getPreviousPageParam: (firstPage) => firstPage.prevCursor,
  });
}

export function PostList() {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfinitePosts();

  const allPosts = data?.pages.flatMap((page) => page.items) ?? [];

  return (
    <div>
      {allPosts.map((post) => (
        <PostCard key={post.id} post={post} />
      ))}
      {hasNextPage && (
        <button onClick={() => fetchNextPage()} disabled={isFetchingNextPage}>
          {isFetchingNextPage ? "Loading..." : "Load More"}
        </button>
      )}
    </div>
  );
}
```

## Dependent Queries

```tsx
export function useUserPosts(userId: string) {
  const userQuery = useQuery({
    queryKey: ["users", userId],
    queryFn: () => api.getUser(userId),
  });

  const postsQuery = useQuery({
    queryKey: ["users", userId, "posts"],
    queryFn: () => api.getUserPosts(userId),
    enabled: !!userQuery.data,
  });

  return { user: userQuery, posts: postsQuery };
}
```

## SSR/Hydration

Next.js App Router:

```tsx
import { dehydrate, HydrationBoundary, QueryClient } from "@tanstack/react-query";

export default async function UsersPage() {
  const queryClient = new QueryClient();

  await queryClient.prefetchQuery({
    queryKey: ["users"],
    queryFn: () => api.getUsers(),
  });

  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      <UserList />
    </HydrationBoundary>
  );
}
```

## Query Keys Factory Pattern

```ts
export const userKeys = {
  all: ["users"] as const,
  lists: () => [...userKeys.all, "list"] as const,
  list: (filters: UserFilters) => [...userKeys.lists(), filters] as const,
  details: () => [...userKeys.all, "detail"] as const,
  detail: (id: string) => [...userKeys.details(), id] as const,
};

export const postKeys = {
  all: ["posts"] as const,
  lists: () => [...postKeys.all, "list"] as const,
  list: (filters: PostFilters) => [...postKeys.lists(), filters] as const,
  detail: (id: string) => [...postKeys.all, "detail", id] as const,
  byUser: (userId: string) => [...postKeys.all, "user", userId] as const,
};

useQuery({ queryKey: userKeys.detail(id), queryFn: () => api.getUser(id) });
queryClient.invalidateQueries({ queryKey: userKeys.lists() });
```

## Error Handling

```tsx
export function useQueryWithError<T>(options: UseQueryOptions<T>) {
  const query = useQuery(options);

  if (query.error) {
    if (query.error instanceof ApiError && query.error.status === 401) {
      redirect("/login");
    }
  }

  return query;
}

// Global error handler
const queryClient = new QueryClient({
  queryCache: new QueryCache({
    onError: (error, query) => {
      if (query.meta?.errorMessage) {
        toast.error(query.meta.errorMessage as string);
      }
    },
  }),
});
```
