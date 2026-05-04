---
name: tool-prisma
description: "Prisma ORM patterns covering schema definition, migrations, client generation, relations, raw queries, seeding, middleware, and performance"
---

## Schema Definition

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  role      Role     @default(USER)
  posts     Post[]
  profile   Profile?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([email])
  @@map("users")
}

model Post {
  id          String     @id @default(cuid())
  title       String
  content     String?
  published   Boolean    @default(false)
  author      User       @relation(fields: [authorId], references: [id], onDelete: Cascade)
  authorId    String
  categories  Category[]
  createdAt   DateTime   @default(now())

  @@index([authorId])
  @@map("posts")
}

enum Role {
  USER
  ADMIN
}
```

### Field Types

| Prisma Type | PostgreSQL | MySQL | Notes |
|-------------|-----------|-------|-------|
| `String` | `text` | `varchar(191)` | Use `@db.VarChar(255)` to override |
| `Int` | `integer` | `int` | |
| `BigInt` | `bigint` | `bigint` | |
| `Float` | `double precision` | `double` | |
| `Decimal` | `decimal(65,30)` | `decimal(65,30)` | Exact precision |
| `Boolean` | `boolean` | `tinyint(1)` | |
| `DateTime` | `timestamp(3)` | `datetime(3)` | |
| `Json` | `jsonb` | `json` | |

## Relations

### One-to-One

```prisma
model User {
  id      String   @id @default(cuid())
  profile Profile?
}

model Profile {
  id     String @id @default(cuid())
  bio    String
  user   User   @relation(fields: [userId], references: [id])
  userId String @unique
}
```

### One-to-Many

```prisma
model User {
  id    String @id @default(cuid())
  posts Post[]
}

model Post {
  id       String @id @default(cuid())
  author   User   @relation(fields: [authorId], references: [id])
  authorId String
}
```

### Many-to-Many (Implicit)

```prisma
model Post {
  id         String     @id @default(cuid())
  categories Category[]
}

model Category {
  id    String @id @default(cuid())
  posts Post[]
}
```

### Many-to-Many (Explicit)

```prisma
model Post {
  id       String         @id @default(cuid())
  tags     PostTag[]
}

model Tag {
  id    String    @id @default(cuid())
  posts PostTag[]
}

model PostTag {
  post   Post   @relation(fields: [postId], references: [id])
  postId String
  tag    Tag    @relation(fields: [tagId], references: [id])
  tagId  String

  @@id([postId, tagId])
}
```

## Migrations

| Command | Purpose |
|---------|---------|
| `npx prisma migrate dev --name init` | Create and apply migration |
| `npx prisma migrate deploy` | Apply pending migrations (production) |
| `npx prisma migrate reset` | Drop DB, reapply all migrations + seed |
| `npx prisma migrate status` | Check migration status |
| `npx prisma db push` | Push schema without migration file (prototyping) |

## Client Generation

```bash
npx prisma generate
```

```typescript
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const users = await prisma.user.findMany();
}

main()
  .finally(() => prisma.$disconnect());
```

### Singleton Pattern (Next.js / Dev)

```typescript
const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma = globalForPrisma.prisma ?? new PrismaClient();

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;
}
```

## CRUD Operations

### Create

```typescript
const user = await prisma.user.create({
  data: {
    email: "alice@example.com",
    name: "Alice",
    posts: {
      create: [{ title: "First Post" }],
    },
  },
  include: { posts: true },
});
```

### Read

```typescript
const user = await prisma.user.findUnique({
  where: { email: "alice@example.com" },
});

const users = await prisma.user.findMany({
  where: { role: "ADMIN" },
  orderBy: { createdAt: "desc" },
  take: 10,
  skip: 0,
});

const userWithPosts = await prisma.user.findFirst({
  where: { id: userId },
  include: { posts: { where: { published: true } } },
});
```

### Update

```typescript
const user = await prisma.user.update({
  where: { id: userId },
  data: { name: "New Name" },
});

await prisma.user.updateMany({
  where: { role: "USER" },
  data: { role: "ADMIN" },
});
```

### Delete

```typescript
await prisma.user.delete({ where: { id: userId } });
await prisma.user.deleteMany({ where: { role: "USER" } });
```

### Upsert

```typescript
const user = await prisma.user.upsert({
  where: { email: "alice@example.com" },
  update: { name: "Alice Updated" },
  create: { email: "alice@example.com", name: "Alice" },
});
```

## Raw Queries

```typescript
const users = await prisma.$queryRaw<User[]>`
  SELECT * FROM users WHERE email LIKE ${`%${domain}`}
`;

await prisma.$executeRaw`
  UPDATE users SET role = 'ADMIN' WHERE id = ${userId}
`;
```

## Seeding

```typescript
// prisma/seed.ts
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  await prisma.user.upsert({
    where: { email: "admin@example.com" },
    update: {},
    create: {
      email: "admin@example.com",
      name: "Admin",
      role: "ADMIN",
    },
  });
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
```

```json
{
  "prisma": {
    "seed": "npx tsx prisma/seed.ts"
  }
}
```

## Middleware

```typescript
const prisma = new PrismaClient().$extends({
  query: {
    $allModels: {
      async findMany({ model, operation, args, query }) {
        args.where = { ...args.where, deletedAt: null };
        return query(args);
      },
    },
  },
});
```

### Logging

```typescript
const prisma = new PrismaClient({
  log: [
    { emit: "event", level: "query" },
    { emit: "stdout", level: "error" },
  ],
});

prisma.$on("query", (e) => {
  if (e.duration > 1000) {
    console.warn(`Slow query (${e.duration}ms): ${e.query}`);
  }
});
```

## Performance

### Select Only Needed Fields

```typescript
const users = await prisma.user.findMany({
  select: {
    id: true,
    email: true,
    name: true,
  },
});
```

### Cursor-Based Pagination

```typescript
const page = await prisma.post.findMany({
  take: 20,
  skip: 1,
  cursor: { id: lastPostId },
  orderBy: { createdAt: "desc" },
});
```

### Batch Operations

```typescript
const [users, posts] = await prisma.$transaction([
  prisma.user.findMany(),
  prisma.post.findMany({ where: { published: true } }),
]);

await prisma.$transaction(async (tx) => {
  const user = await tx.user.update({ where: { id: senderId }, data: { balance: { decrement: 100 } } });
  if (user.balance < 0) {
    throw new Error("Insufficient balance");
  }
  await tx.user.update({ where: { id: receiverId }, data: { balance: { increment: 100 } } });
});
```
