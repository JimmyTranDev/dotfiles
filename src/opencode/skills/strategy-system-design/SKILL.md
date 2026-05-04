---
name: strategy-system-design
description: "System design patterns covering load balancing, caching layers, message queues, database scaling, CAP theorem, and common architectures"
---

## Load Balancing Strategies

| Algorithm | Behavior | Use Case |
|-----------|----------|----------|
| Round Robin | Sequential distribution | Equal-capacity servers |
| Weighted Round Robin | Proportional to weight | Mixed-capacity servers |
| Least Connections | Route to least busy | Long-lived connections |
| IP Hash | Consistent by client IP | Session affinity |
| Random | Random selection | Simple, stateless |
| Least Response Time | Fastest server wins | Latency-sensitive |

### Load Balancer Layers

| Layer | Example | Scope |
|-------|---------|-------|
| DNS | Route 53, Cloudflare | Global distribution |
| L4 (Transport) | AWS NLB, HAProxy TCP | TCP/UDP forwarding |
| L7 (Application) | AWS ALB, Nginx, Envoy | HTTP routing, path-based |

### Health Check Pattern

```
LB → GET /health → 200 OK (healthy)
LB → GET /health → 503 (unhealthy) → remove from pool
LB → GET /health → 200 OK → re-add after N successes
```

## Caching Layers

| Layer | Latency | Capacity | Example |
|-------|---------|----------|---------|
| Browser cache | 0ms | Client storage | Cache-Control headers |
| CDN | 1-50ms | Distributed edge | CloudFront, Cloudflare |
| Application cache | 1-5ms | Process memory | In-memory Map/LRU |
| Distributed cache | 1-10ms | Cluster memory | Redis, Memcached |
| Database cache | 5-20ms | DB buffer pool | Query result cache |

### Cache Invalidation Strategies

| Strategy | Consistency | Complexity |
|----------|-------------|-----------|
| TTL-based | Eventual | Low |
| Write-through | Strong | Medium |
| Write-behind | Eventual | High |
| Event-driven | Near real-time | Medium |
| Versioned keys | Strong for reads | Low |

### When to Cache

```
Cache when:
├── Read-heavy (read:write > 10:1)
├── Expensive to compute
├── Tolerant of staleness
└── Predictable access patterns

Don't cache when:
├── Write-heavy data
├── Requires real-time consistency
├── Low hit rate expected
└── Data is unique per request
```

## Message Queues

| System | Model | Ordering | Use Case |
|--------|-------|----------|----------|
| RabbitMQ | Queue + Pub/Sub | Per-queue FIFO | Task distribution |
| Apache Kafka | Log-based | Per-partition | Event streaming, replay |
| AWS SQS | Queue | Best-effort (FIFO available) | Simple async tasks |
| AWS SNS | Pub/Sub | No ordering | Fan-out notifications |
| Redis Streams | Log-based | Per-stream | Lightweight streaming |

### Queue Patterns

| Pattern | Description |
|---------|-------------|
| Work Queue | Multiple workers competing for tasks |
| Pub/Sub | Broadcast to all subscribers |
| Fan-out | One message triggers multiple consumers |
| Dead Letter Queue | Failed messages for inspection |
| Priority Queue | Process high-priority first |
| Delayed Queue | Process after specified delay |

### Delivery Guarantees

| Level | Meaning | Trade-off |
|-------|---------|-----------|
| At-most-once | May lose messages | Fastest, no duplication |
| At-least-once | May duplicate | Requires idempotent consumers |
| Exactly-once | No loss, no duplication | Complex, performance cost |

## Database Scaling

### Replication

| Type | Write | Read | Consistency |
|------|-------|------|-------------|
| Single primary | Primary only | Primary + replicas | Eventual for reads |
| Multi-primary | Any node | Any node | Conflict resolution needed |
| Synchronous | Waits for replica | Both | Strong |
| Asynchronous | Returns immediately | Eventual | Highest throughput |

### Sharding Strategies

| Strategy | Method | Pros | Cons |
|----------|--------|------|------|
| Range-based | Shard by ID range | Simple, range queries | Hot spots |
| Hash-based | Hash(key) % N | Even distribution | No range queries |
| Directory-based | Lookup table | Flexible | Lookup overhead |
| Geographic | By region | Data locality | Cross-region complexity |

### Partitioning

| Type | Split By | Example |
|------|----------|---------|
| Horizontal | Rows | Users A-M → shard1, N-Z → shard2 |
| Vertical | Columns | User core → table1, profile → table2 |
| Functional | Feature | Orders DB, Inventory DB, Users DB |

### Scaling Decision Tree

```
Need more read throughput?
├── Yes → Add read replicas
└── No → Need more write throughput?
    ├── Yes → Shard the database
    └── No → Need lower latency?
        ├── Yes → Add caching layer
        └── No → Need more storage?
            └── Yes → Partition or archive
```

## CAP Theorem

| Property | Meaning |
|----------|---------|
| **C**onsistency | All nodes see same data at same time |
| **A**vailability | Every request gets a response |
| **P**artition tolerance | System works despite network splits |

### You Can Pick Two (during partition)

| Choice | Sacrifice | Systems |
|--------|-----------|---------|
| CP | Availability during partition | MongoDB, HBase, Redis Cluster |
| AP | Consistency during partition | Cassandra, DynamoDB, CouchDB |
| CA | Not possible in distributed systems | Single-node RDBMS only |

### PACELC Extension

During **P**artition: choose **A** or **C**
**E**lse (normal operation): choose **L**atency or **C**onsistency

| System | Partition | Normal |
|--------|-----------|--------|
| DynamoDB | PA | EL (low latency) |
| MongoDB | PC | EC (consistent) |
| Cassandra | PA | EL (tunable) |
| PostgreSQL | PC | EC |

## Common Architectures

### Microservices

```
Client → API Gateway → Service A → Database A
                     → Service B → Database B
                     → Service C → Cache → Database C
```

| Concern | Solution |
|---------|----------|
| Discovery | Consul, Kubernetes DNS |
| Communication | REST, gRPC, async messaging |
| Data | Database per service |
| Transactions | Saga pattern, eventual consistency |
| Observability | Distributed tracing (Jaeger, Zipkin) |
| Resilience | Circuit breaker, retry, bulkhead |

### Event-Driven

```
Producer → Event Bus → Consumer A
                     → Consumer B
                     → Consumer C (projections)
```

| Component | Role |
|-----------|------|
| Event Producer | Publishes domain events |
| Event Bus | Kafka, EventBridge, NATS |
| Event Consumer | Reacts to events asynchronously |
| Event Store | Append-only event log |
| Projection | Materialized read model |

### CQRS (Command Query Responsibility Segregation)

```
Write Path: Command → Validate → Write Model → Event Store → Publish Event
Read Path:  Query → Read Model (denormalized, optimized)
Event Handler: Event → Update Read Model
```

| Aspect | Write Side | Read Side |
|--------|-----------|-----------|
| Model | Normalized, consistent | Denormalized, fast |
| Store | RDBMS or Event Store | NoSQL, cache, search |
| Scale | Optimized for writes | Optimized for reads |
| Consistency | Strong | Eventually consistent |

## Estimation Framework

### Back-of-Envelope Numbers

| Operation | Latency |
|-----------|---------|
| L1 cache ref | 0.5 ns |
| L2 cache ref | 7 ns |
| RAM ref | 100 ns |
| SSD random read | 150 μs |
| HDD seek | 10 ms |
| Network round trip (same DC) | 0.5 ms |
| Network round trip (cross-continent) | 150 ms |

### Capacity Estimation

| Metric | Formula |
|--------|---------|
| QPS | Daily users × actions/user / 86400 |
| Peak QPS | Average QPS × 2-3 |
| Storage/year | Records/day × record size × 365 |
| Bandwidth | QPS × response size |
| Servers needed | Peak QPS / single server capacity |

### Common Scale Numbers

| Scale | Magnitude |
|-------|-----------|
| 1 million seconds | ~11.5 days |
| 1 billion seconds | ~31.7 years |
| 1 million requests/day | ~12 QPS |
| 100 million requests/day | ~1,150 QPS |
| 1 TB storage | ~1M records at 1KB each |

### SLA Math

| Availability | Downtime/year | Downtime/month |
|-------------|---------------|----------------|
| 99% | 3.65 days | 7.2 hours |
| 99.9% | 8.76 hours | 43.8 min |
| 99.99% | 52.6 min | 4.3 min |
| 99.999% | 5.26 min | 26.3 sec |
