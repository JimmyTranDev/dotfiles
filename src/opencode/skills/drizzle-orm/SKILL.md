---
name: drizzle-orm
description: Drizzle ORM patterns covering schema definition, SQL-like and relational queries, relations v2, joins, inserts, updates, deletes, migrations, and dialect-specific features for PostgreSQL, MySQL, and SQLite
---

## Schema Definition

Schemas are dialect-specific. Import table constructors from the relevant core package.

| Dialect | Import | Table Constructor |
|---------|--------|-------------------|
| PostgreSQL | `drizzle-orm/pg-core` | `pgTable` |
| MySQL | `drizzle-orm/mysql-core` | `mysqlTable` |
| SQLite | `drizzle-orm/sqlite-core` | `sqliteTable` |

```ts
import { pgTable, serial, text, timestamp, integer, boolean, uuid, varchar, jsonb } from "drizzle-orm/pg-core"

export const users = pgTable("users", {
  id: uuid().primaryKey().defaultRandom(),
  email: varchar({ length: 255 }).notNull().unique(),
  name: text().notNull(),
  isActive: boolean().notNull().default(true),
  metadata: jsonb().$type<{ plan: string; features: string[] }>(),
  createdAt: timestamp().notNull().defaultNow(),
})

export const posts = pgTable("posts", {
  id: serial().primaryKey(),
  title: text().notNull(),
  content: text(),
  authorId: uuid().notNull().references(() => users.id, { onDelete: "cascade" }),
  publishedAt: timestamp(),
})
```

## Automatic Casing

Use `casing: "snake_case"` on `drizzle()` to auto-map camelCase TS fields to snake_case DB columns.

```ts
import { drizzle } from "drizzle-orm/node-postgres"

const db = drizzle(process.env.DATABASE_URL, {
  schema,
  casing: "snake_case",
})
```

With this enabled, `createdAt` in schema maps to `created_at` in the database without manual column name overrides.

## Inferred Types

Use `$inferSelect` and `$inferInsert` to derive types from table definitions.

```ts
type User = typeof users.$inferSelect
type NewUser = typeof users.$inferInsert
```

## Column Helpers

| Helper | Purpose |
|--------|---------|
| `.notNull()` | Mark column as NOT NULL |
| `.default(value)` | Set default value |
| `.defaultRandom()` | UUID random default |
| `.defaultNow()` | Timestamp current time default |
| `.primaryKey()` | Mark as primary key |
| `.unique()` | Add unique constraint |
| `.references(() => table.col)` | Foreign key reference |
| `.$type<T>()` | Override TypeScript type for JSON columns |
| `.$default(() => val)` | Runtime default (not DB-level) |
| `.$onUpdate(() => val)` | Runtime value on update |

## Select (SQL-like API)

```ts
import { eq, gt, and, or, like, isNull, inArray, between, sql, not, desc, asc } from "drizzle-orm"

const activeUsers = await db
  .select()
  .from(users)
  .where(eq(users.isActive, true))

const filtered = await db
  .select({ id: users.id, email: users.email })
  .from(users)
  .where(and(gt(users.createdAt, new Date("2024-01-01")), like(users.email, "%@example.com")))
  .orderBy(desc(users.createdAt))
  .limit(10)
  .offset(20)
```

## Filter Operators

| Operator | Usage |
|----------|-------|
| `eq(col, val)` | Equal |
| `ne(col, val)` | Not equal |
| `gt(col, val)` | Greater than |
| `gte(col, val)` | Greater than or equal |
| `lt(col, val)` | Less than |
| `lte(col, val)` | Less than or equal |
| `like(col, pattern)` | LIKE pattern |
| `ilike(col, pattern)` | Case-insensitive LIKE (PG only) |
| `inArray(col, vals)` | IN (...) |
| `notInArray(col, vals)` | NOT IN (...) |
| `isNull(col)` | IS NULL |
| `isNotNull(col)` | IS NOT NULL |
| `between(col, a, b)` | BETWEEN a AND b |
| `not(condition)` | Negate condition |
| `and(...conditions)` | AND |
| `or(...conditions)` | OR |
| `exists(subquery)` | EXISTS |
| `sql\`...\`` | Raw SQL escape hatch |

## Insert

```ts
const [newUser] = await db
  .insert(users)
  .values({ email: "alice@example.com", name: "Alice" })
  .returning()

await db.insert(posts).values([
  { title: "First Post", authorId: newUser.id },
  { title: "Second Post", authorId: newUser.id },
])
```

### Upsert (Conflict Handling)

```ts
await db
  .insert(users)
  .values({ id: existingId, email: "new@example.com", name: "Updated" })
  .onConflictDoUpdate({
    target: users.id,
    set: { email: "new@example.com", name: "Updated" },
  })

await db
  .insert(users)
  .values({ email: "maybe@example.com", name: "Maybe" })
  .onConflictDoNothing({ target: users.email })
```

## Update

```ts
const [updated] = await db
  .update(users)
  .set({ isActive: false })
  .where(eq(users.id, userId))
  .returning()
```

## Delete

```ts
const [deleted] = await db
  .delete(users)
  .where(eq(users.id, userId))
  .returning()
```

## Joins

Join type determines TypeScript nullability of the joined side.

| Join | Method | Nullability |
|------|--------|-------------|
| Inner | `.innerJoin()` | Both sides non-null |
| Left | `.leftJoin()` | Right side nullable |
| Right | `.rightJoin()` | Left side nullable |
| Full | `.fullJoin()` | Both sides nullable |

```ts
const postsWithAuthors = await db
  .select({
    postTitle: posts.title,
    authorName: users.name,
    authorEmail: users.email,
  })
  .from(posts)
  .innerJoin(users, eq(posts.authorId, users.id))
  .where(isNotNull(posts.publishedAt))
```

### Multiple Joins

```ts
const result = await db
  .select()
  .from(posts)
  .leftJoin(users, eq(posts.authorId, users.id))
  .leftJoin(comments, eq(comments.postId, posts.id))
```

## Relations v2 (defineRelations)

Define relations separately from schema using `defineRelations`. This powers the relational query API.

```ts
import { defineRelations } from "drizzle-orm"

const relations = defineRelations(schema, (r) => ({
  users: {
    posts: r.many.posts(),
    profile: r.one.profiles(),
  },
  posts: {
    author: r.one.users({
      from: r.posts.authorId,
      to: r.users.id,
    }),
    comments: r.many.comments(),
    tags: r.many.tags({
      through: r.postTags,
    }),
  },
  profiles: {
    user: r.one.users({
      from: r.profiles.userId,
      to: r.users.id,
    }),
  },
  comments: {
    post: r.one.posts({
      from: r.comments.postId,
      to: r.posts.id,
    }),
    author: r.one.users({
      from: r.comments.authorId,
      to: r.users.id,
    }),
  },
}))
```

### Many-to-Many via Junction Table

```ts
export const postTags = pgTable("post_tags", {
  postId: uuid().notNull().references(() => posts.id),
  tagId: uuid().notNull().references(() => tags.id),
})

const relations = defineRelations(schema, (r) => ({
  posts: {
    tags: r.many.tags({ through: r.postTags }),
  },
  tags: {
    posts: r.many.posts({ through: r.postTags }),
  },
}))
```

## Relational Queries (db.query)

The relational query API provides a simpler way to query with nested relations.

```ts
const db = drizzle(client, { schema, relations })

const usersWithPosts = await db.query.users.findMany({
  columns: { id: true, name: true, email: true },
  with: { posts: { columns: { id: true, title: true } } },
  where: { isActive: true },
  orderBy: { createdAt: "desc" },
  limit: 10,
})

const singleUser = await db.query.users.findFirst({
  with: { posts: true, profile: true },
  where: { id: userId },
})
```

### Object-Based Where Filters (v1.0+)

```ts
await db.query.users.findMany({
  where: { isActive: true, email: { like: "%@example.com" } },
})

await db.query.posts.findMany({
  where: {
    OR: [
      { title: { like: "%drizzle%" } },
      { title: { like: "%orm%" } },
    ],
  },
})

await db.query.posts.findMany({
  where: {
    AND: [
      { publishedAt: { isNotNull: true } },
      { createdAt: { gt: new Date("2024-01-01") } },
    ],
  },
})

await db.query.users.findMany({
  where: { NOT: { isActive: false } },
})
```

### Relation Filters

Filter parent records based on related table conditions.

```ts
await db.query.users.findMany({
  where: {
    posts: { title: { like: "%drizzle%" } },
  },
})
```

## Aggregation and Count

```ts
import { count, sum, avg, min, max } from "drizzle-orm"

const [{ totalUsers }] = await db
  .select({ totalUsers: count() })
  .from(users)

const stats = await db
  .select({
    authorId: posts.authorId,
    postCount: count(posts.id),
    latestPost: max(posts.publishedAt),
  })
  .from(posts)
  .groupBy(posts.authorId)
  .having(gt(count(posts.id), 5))

const totalPosts = await db.$count(posts)
const activeUserCount = await db.$count(users, eq(users.isActive, true))
```

## Subqueries

```ts
const avgPostCount = db
  .select({ value: avg(count(posts.id)).as("avg_count") })
  .from(posts)
  .groupBy(posts.authorId)
  .as("avg_post_count")

const prolificAuthors = await db
  .select({ name: users.name, postCount: count(posts.id) })
  .from(users)
  .innerJoin(posts, eq(users.id, posts.authorId))
  .groupBy(users.name)
  .having(gt(count(posts.id), avgPostCount))
```

## CTEs (Common Table Expressions)

```ts
const recentPosts = db.$with("recent_posts").as(
  db.select().from(posts).where(gt(posts.publishedAt, new Date("2024-01-01")))
)

const result = await db
  .with(recentPosts)
  .select()
  .from(recentPosts)
  .innerJoin(users, eq(recentPosts.authorId, users.id))
```

## Transactions

```ts
const result = await db.transaction(async (tx) => {
  const [user] = await tx.insert(users).values({ email: "tx@example.com", name: "TX User" }).returning()
  await tx.insert(posts).values({ title: "First Post", authorId: user.id })
  return user
})
```

### Nested Transactions (Savepoints)

```ts
await db.transaction(async (tx) => {
  await tx.insert(users).values({ email: "outer@example.com", name: "Outer" })

  await tx.transaction(async (nested) => {
    await nested.insert(users).values({ email: "inner@example.com", name: "Inner" })
  })
})
```

## Prepared Statements

```ts
import { placeholder } from "drizzle-orm"

const getUserById = db
  .select()
  .from(users)
  .where(eq(users.id, placeholder("id")))
  .prepare("get_user_by_id")

const user = await getUserById.execute({ id: userId })
```

## Dynamic Queries

```ts
const buildUserQuery = (filters: { email?: string; isActive?: boolean }) => {
  let query = db.select().from(users).$dynamic()

  if (filters.email) {
    query = query.where(like(users.email, `%${filters.email}%`))
  }
  if (filters.isActive !== undefined) {
    query = query.where(eq(users.isActive, filters.isActive))
  }

  return query
}
```

## getColumns

Use `getColumns` to spread columns or exclude specific ones.

```ts
import { getColumns } from "drizzle-orm"

const { password, ...safeColumns } = getColumns(users)

const safeUsers = await db.select(safeColumns).from(users)
```

## Raw SQL

```ts
import { sql } from "drizzle-orm"

const result = await db.execute(sql`SELECT * FROM users WHERE id = ${userId}`)

const withRaw = await db
  .select({
    id: users.id,
    fullName: sql<string>`concat(${users.name}, ' (', ${users.email}, ')')`,
  })
  .from(users)
```

## Drizzle Kit (Migrations)

| Command | Purpose |
|---------|---------|
| `drizzle-kit generate` | Generate SQL migration files from schema changes |
| `drizzle-kit migrate` | Apply pending migrations |
| `drizzle-kit push` | Push schema directly to DB (dev only, no migration files) |
| `drizzle-kit pull` | Introspect existing DB and generate schema |
| `drizzle-kit studio` | Open Drizzle Studio GUI |
| `drizzle-kit check` | Check for schema consistency |
| `drizzle-kit up` | Upgrade migration snapshots |

### drizzle.config.ts

```ts
import { defineConfig } from "drizzle-kit"

export default defineConfig({
  dialect: "postgresql",
  schema: "./src/db/schema.ts",
  out: "./drizzle",
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
  casing: "snake_case",
})
```

## Driver Setup

| Driver | Package | Init |
|--------|---------|------|
| node-postgres (pg) | `drizzle-orm/node-postgres` | `drizzle(pool)` or `drizzle(connectionString)` |
| Neon HTTP | `drizzle-orm/neon-http` | `drizzle(neon(url))` |
| Neon WebSocket | `drizzle-orm/neon-serverless` | `drizzle(pool)` |
| PlanetScale | `drizzle-orm/planetscale-serverless` | `drizzle(connection)` |
| Turso/LibSQL | `drizzle-orm/libsql` | `drizzle(client)` |
| Bun SQLite | `drizzle-orm/bun-sqlite` | `drizzle(db)` |
| Better-sqlite3 | `drizzle-orm/better-sqlite3` | `drizzle(db)` |
| D1 (Cloudflare) | `drizzle-orm/d1` | `drizzle(env.DB)` |
| Vercel Postgres | `drizzle-orm/vercel-postgres` | `drizzle(sql)` |

```ts
import { drizzle } from "drizzle-orm/node-postgres"
import * as schema from "./schema"

const db = drizzle(process.env.DATABASE_URL, { schema, relations })
```

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Forgetting `.returning()` on insert/update/delete | PG/SQLite support `returning()`, MySQL uses `$returningId()` |
| Using `relations()` from `drizzle-orm` (v0.x) | Use `defineRelations()` in v1.0+ |
| Using `getTableColumns` (v0.x) | Use `getColumns` in v1.0+ |
| Not passing `schema` + `relations` to `drizzle()` | Required for `db.query` relational API |
| Expecting non-null on left join columns | Left joins make joined side nullable in TS |
| Using `push` in production | Use `generate` + `migrate` for production deployments |
| Missing `casing` in both `drizzle()` and `drizzle.config.ts` | Set `casing: "snake_case"` in both if using auto-casing |
