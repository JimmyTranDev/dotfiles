---
name: tool-supabase
description: Supabase patterns covering client setup, auth flows, database queries, real-time subscriptions, storage, edge functions, RLS policies, and TypeScript types
---

## Client Setup

```ts
import { createClient } from "@supabase/supabase-js";
import type { Database } from "./database.types";

export const supabase = createClient<Database>(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);
```

Server-side (Next.js App Router):

```ts
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createSupabaseServer() {
  const cookieStore = await cookies();

  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookieStore.set(name, value, options);
          });
        },
      },
    }
  );
}
```

## Auth

### Email/Password

```ts
const { data, error } = await supabase.auth.signUp({
  email: "user@example.com",
  password: "securepassword",
});

const { data, error } = await supabase.auth.signInWithPassword({
  email: "user@example.com",
  password: "securepassword",
});

await supabase.auth.signOut();
```

### OAuth

```ts
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: "google",
  options: {
    redirectTo: `${window.location.origin}/auth/callback`,
  },
});
```

### Session Management

```ts
const { data: { session } } = await supabase.auth.getSession();
const { data: { user } } = await supabase.auth.getUser();

supabase.auth.onAuthStateChange((event, session) => {
  if (event === "SIGNED_IN") {
    router.push("/dashboard");
  }
  if (event === "SIGNED_OUT") {
    router.push("/login");
  }
});
```

## Database Queries

### Select

```ts
const { data, error } = await supabase
  .from("posts")
  .select("id, title, content, created_at, author:profiles(name, avatar_url)")
  .eq("published", true)
  .order("created_at", { ascending: false })
  .limit(20);

const { data, error } = await supabase
  .from("posts")
  .select("*", { count: "exact" })
  .range(0, 9);
```

### Insert

```ts
const { data, error } = await supabase
  .from("posts")
  .insert({ title: "New Post", content: "Body", author_id: userId })
  .select()
  .single();

const { data, error } = await supabase
  .from("tags")
  .insert([{ name: "react" }, { name: "typescript" }])
  .select();
```

### Update

```ts
const { data, error } = await supabase
  .from("posts")
  .update({ title: "Updated Title" })
  .eq("id", postId)
  .select()
  .single();
```

### Delete

```ts
const { error } = await supabase
  .from("posts")
  .delete()
  .eq("id", postId);
```

### Filters

| Filter | Code |
|--------|------|
| Equal | `.eq("col", value)` |
| Not equal | `.neq("col", value)` |
| Greater than | `.gt("col", value)` |
| Less than | `.lt("col", value)` |
| In array | `.in("col", [1, 2, 3])` |
| Like | `.like("col", "%pattern%")` |
| ILike | `.ilike("col", "%pattern%")` |
| Is null | `.is("col", null)` |
| Contains (array) | `.contains("tags", ["react"])` |
| Text search | `.textSearch("col", "query")` |
| Or | `.or("col1.eq.val1,col2.eq.val2")` |

### Joins

```ts
const { data } = await supabase
  .from("posts")
  .select(`
    id,
    title,
    author:profiles!author_id(name),
    comments(id, body, user:profiles!user_id(name))
  `)
  .eq("id", postId)
  .single();
```

## Real-time Subscriptions

```ts
const channel = supabase
  .channel("posts-changes")
  .on(
    "postgres_changes",
    { event: "*", schema: "public", table: "posts", filter: "author_id=eq.123" },
    (payload) => {
      if (payload.eventType === "INSERT") {
        setPosts((prev) => [payload.new as Post, ...prev]);
      }
      if (payload.eventType === "DELETE") {
        setPosts((prev) => prev.filter((p) => p.id !== payload.old.id));
      }
    }
  )
  .subscribe();

return () => {
  supabase.removeChannel(channel);
};
```

Presence:

```ts
const channel = supabase.channel("room-1");

channel
  .on("presence", { event: "sync" }, () => {
    const state = channel.presenceState();
    setOnlineUsers(Object.values(state).flat());
  })
  .subscribe(async (status) => {
    if (status === "SUBSCRIBED") {
      await channel.track({ user_id: userId, online_at: new Date().toISOString() });
    }
  });
```

## Storage

```ts
const { data, error } = await supabase.storage
  .from("avatars")
  .upload(`${userId}/avatar.png`, file, {
    cacheControl: "3600",
    upsert: true,
    contentType: file.type,
  });

const { data } = supabase.storage
  .from("avatars")
  .getPublicUrl(`${userId}/avatar.png`);

const { data, error } = await supabase.storage
  .from("private-files")
  .createSignedUrl("path/to/file.pdf", 3600);

const { data, error } = await supabase.storage
  .from("avatars")
  .download(`${userId}/avatar.png`);

const { error } = await supabase.storage
  .from("avatars")
  .remove([`${userId}/avatar.png`]);
```

## Edge Functions

Invoke:

```ts
const { data, error } = await supabase.functions.invoke("process-payment", {
  body: { amount: 1000, currency: "usd" },
});
```

Edge function (Deno):

```ts
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { amount, currency } = await req.json();

  const { data, error } = await supabase
    .from("payments")
    .insert({ amount, currency, status: "pending" })
    .select()
    .single();

  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  });
});
```

## Row Level Security Policies

```sql
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public posts are viewable by everyone"
  ON posts FOR SELECT
  USING (published = true);

CREATE POLICY "Users can insert their own posts"
  ON posts FOR INSERT
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can update their own posts"
  ON posts FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can delete their own posts"
  ON posts FOR DELETE
  USING (auth.uid() = author_id);

CREATE POLICY "Admins can do everything"
  ON posts FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );
```

| Policy Part | Purpose |
|-------------|---------|
| `USING` | Filters which existing rows are visible/affected |
| `WITH CHECK` | Validates new/updated row data |
| `auth.uid()` | Current authenticated user's ID |
| `auth.jwt()` | Full JWT claims |

## TypeScript Type Generation

```bash
npx supabase gen types typescript --project-id your-project-id > src/database.types.ts
```

Usage with typed client:

```ts
import type { Database } from "./database.types";

type Post = Database["public"]["Tables"]["posts"]["Row"];
type InsertPost = Database["public"]["Tables"]["posts"]["Insert"];
type UpdatePost = Database["public"]["Tables"]["posts"]["Update"];
```
