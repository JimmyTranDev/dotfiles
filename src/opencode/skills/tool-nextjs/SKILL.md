---
name: tool-nextjs
description: "Next.js patterns covering App Router, Server Components, middleware, API routes, ISR, caching, metadata, and deployment"
---

## App Router Structure

```
app/
├── layout.tsx              # Root layout (required)
├── page.tsx                # Home route
├── loading.tsx             # Suspense fallback
├── error.tsx               # Error boundary
├── not-found.tsx           # 404 page
├── global-error.tsx        # Root error boundary
├── (group)/               # Route group (no URL segment)
│   └── page.tsx
├── [slug]/                # Dynamic segment
│   └── page.tsx
├── [...slug]/             # Catch-all segment
│   └── page.tsx
├── [[...slug]]/           # Optional catch-all
│   └── page.tsx
└── @modal/                # Parallel route (named slot)
    └── page.tsx
```

## Server Components (Default)

- All components in `app/` are Server Components by default
- Can directly `await` async operations
- Cannot use hooks, browser APIs, or event handlers
- Cannot pass functions as props to Client Components
- Import server-only utilities with `import 'server-only'`

```tsx
async function ProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await db.product.findUnique({ where: { id } })
  return <ProductDetail product={product} />
}
```

## Client Components

- Mark with `'use client'` directive at top of file
- Required for: hooks, event handlers, browser APIs, third-party libs needing state
- Place `'use client'` boundary as low as possible in the tree
- Children of Client Components can still be Server Components if passed as `children`

## Data Fetching Patterns

### Server Component Fetch
```tsx
async function Page() {
  const data = await fetch('https://api.example.com/data', {
    next: { revalidate: 3600 }
  })
  return <Component data={await data.json()} />
}
```

### Caching Options
| Option | Behavior |
|--------|----------|
| `{ cache: 'force-cache' }` | Cache indefinitely (default in production) |
| `{ cache: 'no-store' }` | No caching, always fresh |
| `{ next: { revalidate: N } }` | ISR: revalidate every N seconds |
| `{ next: { tags: ['tag'] } }` | Tag-based on-demand revalidation |

### On-Demand Revalidation
```tsx
import { revalidateTag, revalidatePath } from 'next/cache'

revalidateTag('products')
revalidatePath('/products')
revalidatePath('/products', 'layout')
```

## Route Handlers (API Routes)

```tsx
// app/api/users/route.ts
import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const query = searchParams.get('q')
  return NextResponse.json({ results: [] })
}

export async function POST(request: NextRequest) {
  const body = await request.json()
  return NextResponse.json({ created: true }, { status: 201 })
}
```

### Route Handler Caching
- GET handlers are cached by default when no `Request` object is used
- Add `export const dynamic = 'force-dynamic'` to opt out

## Middleware

```tsx
// middleware.ts (root of project)
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  if (!request.cookies.get('session')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }
  return NextResponse.next()
}

export const config = {
  matcher: ['/dashboard/:path*', '/api/:path*']
}
```

### Middleware Capabilities
- Rewrite, redirect, set headers, set cookies
- Cannot access database or heavy computation (runs on Edge)
- Runs before every matched request
- Use matcher to limit scope

## Metadata

### Static Metadata
```tsx
export const metadata: Metadata = {
  title: 'Page Title',
  description: 'Page description',
  openGraph: { title: 'OG Title', images: ['/og.png'] },
}
```

### Dynamic Metadata
```tsx
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params
  const product = await getProduct(id)
  return { title: product.name, description: product.description }
}
```

## Static Generation

```tsx
export async function generateStaticParams() {
  const posts = await getPosts()
  return posts.map((post) => ({ slug: post.slug }))
}

export const dynamicParams = false // 404 for unknown params
```

## Route Segment Config

```tsx
export const dynamic = 'auto' | 'force-dynamic' | 'force-static' | 'error'
export const revalidate = 0 | number | false
export const fetchCache = 'auto' | 'force-cache' | 'force-no-store'
export const runtime = 'nodejs' | 'edge'
export const preferredRegion = 'auto' | 'global' | 'home' | string[]
```

## Server Actions

```tsx
// app/actions.ts
'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'

export async function createPost(formData: FormData) {
  const title = formData.get('title') as string
  await db.post.create({ data: { title } })
  revalidatePath('/posts')
  redirect('/posts')
}
```

### Usage in Forms
```tsx
<form action={createPost}>
  <input name="title" />
  <button type="submit">Create</button>
</form>
```

## Image Optimization

```tsx
import Image from 'next/image'

<Image
  src="/hero.png"
  alt="Hero"
  width={1200}
  height={630}
  priority          // LCP image
  placeholder="blur"
  blurDataURL={blurUrl}
/>
```

## Deployment Checklist

- Set `output: 'standalone'` in `next.config.js` for Docker
- Configure `images.remotePatterns` for external image domains
- Set proper `headers()` for security (CSP, HSTS)
- Use `NEXT_PUBLIC_` prefix for client-side env vars only
- Enable ISR with proper `revalidate` values
- Configure `redirects()` and `rewrites()` in next.config
- Set `poweredByHeader: false`
- Use `compress: true` (or offload to reverse proxy)

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Using hooks in Server Components | Move to Client Component |
| Passing functions from Server to Client | Use Server Actions or serialize |
| Large Client Component boundaries | Split and push `'use client'` down |
| Fetching in Client when Server suffices | Move fetch to Server Component |
| Missing `loading.tsx` for slow pages | Add Suspense boundaries |
| Env vars exposed to client without prefix | Use `NEXT_PUBLIC_` prefix |
| Middleware doing heavy computation | Move logic to API route |
| Not handling `params` as Promise (Next 15+) | Await params before use |
