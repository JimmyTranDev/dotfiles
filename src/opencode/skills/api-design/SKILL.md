---
name: api-design
description: "REST and GraphQL API design covering naming conventions, versioning, pagination, error responses, rate limiting, and documentation"
---

## REST Naming Conventions

| Pattern | Example | Rule |
|---------|---------|------|
| Collection | `/users` | Plural nouns |
| Resource | `/users/123` | Singular identifier |
| Sub-resource | `/users/123/orders` | Nested relationship |
| Action | `/users/123/activate` | Verb only when no CRUD fit |
| Filter | `/users?status=active` | Query params for filtering |
| Search | `/users?q=alice` | `q` for full-text search |

### Naming Rules

- Lowercase with hyphens: `/user-profiles` not `/userProfiles`
- No trailing slashes: `/users` not `/users/`
- No file extensions: `/users/123` not `/users/123.json`
- No verbs in resource paths: `/orders` not `/getOrders`

## HTTP Methods

| Method | Purpose | Idempotent | Request Body |
|--------|---------|------------|-------------|
| `GET` | Read resource(s) | Yes | No |
| `POST` | Create resource | No | Yes |
| `PUT` | Full replace | Yes | Yes |
| `PATCH` | Partial update | Yes | Yes |
| `DELETE` | Remove resource | Yes | Optional |

## Status Codes

| Code | Meaning | When to Use |
|------|---------|-------------|
| `200` | OK | Successful GET, PUT, PATCH |
| `201` | Created | Successful POST (return Location header) |
| `204` | No Content | Successful DELETE |
| `400` | Bad Request | Invalid input, validation failure |
| `401` | Unauthorized | Missing or invalid auth |
| `403` | Forbidden | Valid auth, insufficient permissions |
| `404` | Not Found | Resource doesn't exist |
| `409` | Conflict | Duplicate, state conflict |
| `422` | Unprocessable | Valid JSON, semantic errors |
| `429` | Too Many Requests | Rate limit exceeded |
| `500` | Internal Error | Unexpected server failure |

## Pagination

### Offset-Based

```
GET /users?page=2&limit=20

Response:
{
  "data": [...],
  "meta": {
    "page": 2,
    "limit": 20,
    "total": 156,
    "totalPages": 8
  }
}
```

### Cursor-Based (Preferred for large datasets)

```
GET /users?limit=20&cursor=eyJpZCI6MTAwfQ

Response:
{
  "data": [...],
  "meta": {
    "limit": 20,
    "hasMore": true,
    "nextCursor": "eyJpZCI6MTIwfQ"
  }
}
```

| Strategy | Pros | Cons |
|----------|------|------|
| Offset | Jumpable pages, simple | Skips/dupes on insert, slow at high offsets |
| Cursor | Consistent, performant | No random page access |

## Error Response Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      {
        "field": "email",
        "message": "Must be a valid email address",
        "code": "INVALID_FORMAT"
      },
      {
        "field": "age",
        "message": "Must be at least 18",
        "code": "MIN_VALUE"
      }
    ],
    "requestId": "req_abc123"
  }
}
```

### Error Code Categories

| Prefix | Category |
|--------|----------|
| `AUTH_*` | Authentication/authorization |
| `VALIDATION_*` | Input validation |
| `NOT_FOUND_*` | Resource not found |
| `CONFLICT_*` | State conflicts |
| `RATE_*` | Rate limiting |
| `INTERNAL_*` | Server errors |

## Versioning Strategies

| Strategy | Example | Pros | Cons |
|----------|---------|------|------|
| URL path | `/v1/users` | Explicit, cacheable | URL pollution |
| Header | `Accept: application/vnd.api+json;version=2` | Clean URLs | Hidden, harder to test |
| Query param | `/users?version=2` | Easy to test | Cache key issues |

### Recommendation: URL path versioning

- Major version in URL: `/v1/`, `/v2/`
- Non-breaking changes don't bump version
- Support N-1 version minimum
- Deprecation header: `Deprecation: true`

## Rate Limiting

### Response Headers

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 67
X-RateLimit-Reset: 1700000060
Retry-After: 30
```

### Strategies

| Algorithm | Behavior |
|-----------|----------|
| Fixed window | N requests per time window |
| Sliding window | Smoothed fixed window |
| Token bucket | Burst-friendly with steady refill |
| Leaky bucket | Fixed output rate, queue excess |

### Tiered Limits

| Tier | Rate | Scope |
|------|------|-------|
| Anonymous | 60/hour | IP |
| Authenticated | 1000/hour | API key |
| Premium | 10000/hour | API key |

## GraphQL Schema Design

```graphql
type User {
  id: ID!
  email: String!
  name: String!
  orders(first: Int, after: String): OrderConnection!
  createdAt: DateTime!
}

type OrderConnection {
  edges: [OrderEdge!]!
  pageInfo: PageInfo!
}

type OrderEdge {
  node: Order!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  endCursor: String
}

type Query {
  user(id: ID!): User
  users(filter: UserFilter, first: Int, after: String): UserConnection!
}

type Mutation {
  createUser(input: CreateUserInput!): CreateUserPayload!
  updateUser(id: ID!, input: UpdateUserInput!): UpdateUserPayload!
}

input CreateUserInput {
  email: String!
  name: String!
}

type CreateUserPayload {
  user: User
  errors: [UserError!]!
}
```

### GraphQL Best Practices

- Use `Connection` pattern for lists (Relay spec)
- Input types for mutations (`CreateXInput`)
- Payload types with `errors` field for mutations
- Avoid deeply nested queries (max depth 5-7)
- Use DataLoader for N+1 prevention

## Authentication Patterns

| Pattern | Use Case | Token Location |
|---------|----------|----------------|
| Bearer JWT | Stateless APIs | `Authorization: Bearer <token>` |
| API Key | Server-to-server | `X-API-Key: <key>` or query param |
| OAuth 2.0 | Third-party access | Authorization header |
| Session cookie | Browser apps | `Cookie: session=<id>` |

### JWT Structure

```
Authorization: Bearer eyJhbGc...

Payload: {
  "sub": "user-123",
  "iat": 1700000000,
  "exp": 1700003600,
  "scope": "read write"
}
```

### Token Refresh Flow

1. Access token (short-lived: 15-60 min)
2. Refresh token (long-lived: 7-30 days)
3. `POST /auth/refresh` with refresh token → new access token
4. Rotate refresh token on use (one-time use)
