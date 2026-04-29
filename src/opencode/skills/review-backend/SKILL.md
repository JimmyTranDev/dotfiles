---
name: review-backend
description: Backend Java Spring review checklist covering SQL injection, N+1 queries, transaction boundaries, thread safety, validation, and error handling
---

## Critical Security

| Issue | What to Look For | Fix |
|-------|-----------------|-----|
| SQL injection | String concatenation in queries, `@Query` with `+` operator | Use `@Param` with named parameters, `JpaSpecificationExecutor`, or `Criteria` API |
| Mass assignment | `@RequestBody` mapping directly to entity | Use DTOs, never expose entities in controllers |
| Missing auth checks | Endpoints without `@PreAuthorize` or security config | Add method-level or URL-level security |
| Sensitive data in logs | Logging request bodies with PII, passwords, tokens | Mask or exclude sensitive fields |
| Insecure deserialization | `ObjectMapper` with default typing enabled | Disable `DefaultTyping`, use `@JsonTypeInfo` selectively |

## Performance

| Issue | What to Look For | Fix |
|-------|-----------------|-----|
| N+1 queries | `@OneToMany`/`@ManyToOne` without fetch strategy, loops calling repository methods | Use `@EntityGraph`, `JOIN FETCH` in JPQL, or `@BatchSize` |
| Missing pagination | `findAll()` without `Pageable` on large tables | Use `Page<T>` or `Slice<T>` with `Pageable` parameter |
| Connection pool exhaustion | Long-running transactions, missing `@Transactional(readOnly = true)` for reads | Use read-only transactions, reduce transaction scope |
| Missing indexes | Queries filtering/sorting on non-indexed columns | Add `@Index` in entity or Flyway migration |
| Unbounded queries | `findBy*` without `LIMIT`, `IN` clauses with unbounded lists | Add `Pageable`, chunk large `IN` lists |

## Transaction Boundaries

| Issue | What to Look For | Fix |
|-------|-----------------|-----|
| Missing `@Transactional` | Service methods that modify multiple entities without annotation | Add `@Transactional` at service method level |
| Over-broad transactions | `@Transactional` on entire class or controller | Move to specific service methods that need it |
| Read-only not specified | Read operations without `@Transactional(readOnly = true)` | Add `readOnly = true` for query-only methods |
| Nested transaction issues | `@Transactional` calling another `@Transactional` with different propagation | Verify propagation settings, prefer `REQUIRED` default |
| Exception swallowing | `try/catch` inside `@Transactional` that catches and doesn't rethrow | Let exceptions propagate for rollback, or use `@Transactional(noRollbackFor = ...)` |

## Thread Safety

| Issue | What to Look For | Fix |
|-------|-----------------|-----|
| Mutable shared state | Non-final fields in `@Service`/`@Component` beans (singletons) | Use `ThreadLocal`, `AtomicReference`, or make fields final |
| Unsafe date formatting | `SimpleDateFormat` as shared field | Use `DateTimeFormatter` (thread-safe) or `ThreadLocal` |
| Non-thread-safe collections | `HashMap`/`ArrayList` as shared state | Use `ConcurrentHashMap`, `CopyOnWriteArrayList`, or synchronize |

## Validation

| Issue | What to Look For | Fix |
|-------|-----------------|-----|
| Missing input validation | `@RequestBody` DTOs without `@Valid` | Add `@Valid` on controller parameter, validation annotations on DTO fields |
| Incomplete validation | Only checking `@NotNull` but not `@Size`, `@Min`, `@Max`, `@Pattern` | Add appropriate constraints for all fields |
| Missing path variable validation | `@PathVariable` IDs without range checks | Add `@Positive` or custom validation |
| Business rule validation in controller | Complex validation logic in controller instead of service | Move to service layer, throw custom exceptions |

## Error Handling

| Issue | What to Look For | Fix |
|-------|-----------------|-----|
| Generic exception handler | Catching `Exception` and returning 500 for everything | Use `@ControllerAdvice` with specific exception handlers |
| Missing error responses | Endpoints that can fail but don't define error response types | Add `@ApiResponse` annotations, return proper HTTP status codes |
| Incorrect HTTP status codes | 200 for creation (should be 201), 200 for deletion (should be 204) | Use `ResponseEntity.created()`, `ResponseEntity.noContent()` |
| Swallowed exceptions | Empty catch blocks, logging without rethrowing | Log and rethrow, or handle explicitly |
| Async error handling | `@Async` methods without exception handling | Use `AsyncUncaughtExceptionHandler` or return `CompletableFuture` |

## REST API Design

| Issue | What to Look For | Fix |
|-------|-----------------|-----|
| Verb in URL | `/api/getUsers`, `/api/createUser` | Use nouns: `GET /api/users`, `POST /api/users` |
| Missing HATEOAS links | Related resources without navigation links | Add `_links` or use Spring HATEOAS if applicable |
| Inconsistent naming | Mix of camelCase and snake_case in JSON | Standardize via `@JsonNaming` or `ObjectMapper` config |
| Missing `@ResponseStatus` | Controller methods without explicit status codes | Add `@ResponseStatus` or return `ResponseEntity` |
