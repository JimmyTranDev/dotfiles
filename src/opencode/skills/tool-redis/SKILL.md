---
name: tool-redis
description: "Redis CLI patterns covering connection, data types, pub/sub, caching strategies, TTL management, transactions, and Lua scripting"
---

## Connection

```bash
redis-cli -h localhost -p 6379
redis-cli -u redis://user:password@host:6379/0
redis-cli --tls -h prod-redis.example.com -p 6380 -a $REDIS_PASSWORD
redis-cli -n 2  # select database 2
```

| Command | Purpose |
|---------|---------|
| `PING` | Check connectivity (returns PONG) |
| `SELECT 1` | Switch to database 1 |
| `DBSIZE` | Number of keys in current DB |
| `INFO memory` | Memory usage stats |
| `INFO clients` | Connected clients |
| `FLUSHDB` | Clear current database |
| `MONITOR` | Real-time command stream |

## Data Types

### Strings

```redis
SET user:1:name "Alice"
GET user:1:name
SETNX lock:order:123 "worker-1"
SETEX session:abc 3600 '{"userId":1}'
INCR counter:visits
INCRBY counter:score 10
MSET key1 "val1" key2 "val2"
MGET key1 key2
```

### Hashes

```redis
HSET user:1 name "Alice" email "alice@example.com" age 30
HGET user:1 name
HGETALL user:1
HINCRBY user:1 age 1
HDEL user:1 email
HEXISTS user:1 name
```

### Lists

```redis
LPUSH queue:tasks "task1" "task2"
RPUSH queue:tasks "task3"
LPOP queue:tasks
RPOP queue:tasks
BRPOP queue:tasks 30
LRANGE queue:tasks 0 -1
LLEN queue:tasks
```

### Sets

```redis
SADD tags:post:1 "typescript" "react" "nextjs"
SMEMBERS tags:post:1
SISMEMBER tags:post:1 "react"
SINTER tags:post:1 tags:post:2
SUNION tags:post:1 tags:post:2
SCARD tags:post:1
```

### Sorted Sets

```redis
ZADD leaderboard 100 "player1" 200 "player2" 150 "player3"
ZRANGE leaderboard 0 -1 WITHSCORES
ZREVRANGE leaderboard 0 9
ZRANK leaderboard "player1"
ZINCRBY leaderboard 50 "player1"
ZRANGEBYSCORE leaderboard 100 200
ZCARD leaderboard
```

## Pub/Sub

```redis
SUBSCRIBE channel:notifications
PUBLISH channel:notifications '{"type":"alert","msg":"deploy complete"}'
PSUBSCRIBE channel:*
UNSUBSCRIBE channel:notifications
```

### Usage Pattern

- Publisher: fire-and-forget broadcast
- Subscriber: real-time event listeners
- No persistence — missed messages are lost
- Use Streams for persistent messaging

### Streams (Persistent Pub/Sub)

```redis
XADD events * type "order" userId "123"
XREAD COUNT 10 BLOCK 5000 STREAMS events 0
XRANGE events - +
XLEN events
```

## Caching Strategies

| Strategy | Pattern | Use Case |
|----------|---------|----------|
| Cache-aside | App reads cache, misses hit DB | General purpose |
| Write-through | App writes cache + DB together | Strong consistency |
| Write-behind | App writes cache, async to DB | High write throughput |
| Read-through | Cache auto-fetches on miss | Transparent caching |

### Cache-Aside Implementation

```
GET key → hit → return
         → miss → query DB → SET key value EX ttl → return
```

### Cache Invalidation Patterns

| Pattern | Command | When |
|---------|---------|------|
| Time-based | `SET key val EX 300` | Known staleness tolerance |
| Event-based | `DEL key` on write | Strong consistency needed |
| Tag-based | `DEL user:1:*` via Lua | Related key groups |
| Versioned | `SET key:v2 val` | Schema changes |

## TTL Management

```redis
SET key "value" EX 3600        # seconds
SET key "value" PX 60000       # milliseconds
EXPIRE key 300                 # set TTL on existing key
PEXPIRE key 5000               # milliseconds
TTL key                        # remaining seconds (-1 = no TTL, -2 = expired)
PTTL key                       # remaining milliseconds
PERSIST key                    # remove TTL
EXPIREAT key 1700000000        # Unix timestamp
```

### TTL Best Practices

- Always set TTL on cache keys (prevent memory leaks)
- Use jitter to avoid thundering herd: `base_ttl + random(0, base_ttl * 0.1)`
- Short TTL (60-300s) for frequently changing data
- Long TTL (3600-86400s) for static reference data

## Transactions (MULTI/EXEC)

```redis
MULTI
SET account:1:balance 500
SET account:2:balance 1500
EXEC
```

```redis
WATCH account:1:balance
val = GET account:1:balance
MULTI
SET account:1:balance (val - 100)
EXEC
```

| Command | Purpose |
|---------|---------|
| `MULTI` | Start transaction |
| `EXEC` | Execute queued commands |
| `DISCARD` | Abort transaction |
| `WATCH key` | Optimistic lock (abort on change) |
| `UNWATCH` | Clear all watches |

## Lua Scripting

```redis
EVAL "return redis.call('GET', KEYS[1])" 1 mykey

EVAL "
  local current = redis.call('GET', KEYS[1])
  if current == ARGV[1] then
    return redis.call('DEL', KEYS[1])
  end
  return 0
" 1 lock:resource "owner-id"
```

### Rate Limiter (Sliding Window)

```redis
EVAL "
  local key = KEYS[1]
  local limit = tonumber(ARGV[1])
  local window = tonumber(ARGV[2])
  local now = tonumber(ARGV[3])
  redis.call('ZREMRANGEBYSCORE', key, 0, now - window)
  local count = redis.call('ZCARD', key)
  if count < limit then
    redis.call('ZADD', key, now, now .. math.random())
    redis.call('EXPIRE', key, window)
    return 1
  end
  return 0
" 1 ratelimit:user:123 100 60000 <current_ms>
```

## Common Patterns

### Distributed Lock

```redis
SET lock:resource "owner-uuid" NX EX 30
DEL lock:resource  # only if still owner (use Lua)
```

### Session Storage

```redis
SETEX session:token123 86400 '{"userId":1,"roles":["admin"]}'
GET session:token123
DEL session:token123
```

### Counting and Analytics

```redis
PFADD unique:visitors:2024-01 "user1" "user2"
PFCOUNT unique:visitors:2024-01
BITSET logins:user:1 0 1  # day 0 logged in
BITCOUNT logins:user:1
```

### Key Naming Convention

```
{entity}:{id}:{field}     → user:123:name
{entity}:{id}             → user:123 (hash)
{scope}:{entity}:{id}    → cache:user:123
{queue}:{name}            → queue:emails
```
