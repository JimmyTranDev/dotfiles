---
name: java-spring-senior
description: Senior Java Spring Boot architecture covering microservices, DDD, CQRS, event-driven systems, distributed transactions, observability, production hardening, and team patterns
---

## What This Skill Covers

Senior-level architecture decisions, distributed system patterns, and production-grade concerns for Java Spring Boot applications. For basic Spring Boot patterns (controllers, services, JPA, security, testing), load the **tool-spring-boot** skill.

## Domain-Driven Design

### Package by Bounded Context

```
src/main/java/com/example/
├── order/
│   ├── domain/
│   │   ├── Order.java              # Aggregate root
│   │   ├── OrderLine.java          # Entity within aggregate
│   │   ├── OrderStatus.java        # Value object (enum)
│   │   ├── Money.java              # Value object
│   │   └── OrderRepository.java    # Repository interface (domain layer)
│   ├── application/
│   │   ├── PlaceOrderCommand.java
│   │   ├── PlaceOrderHandler.java
│   │   └── OrderQueryService.java
│   ├── infrastructure/
│   │   ├── JpaOrderRepository.java
│   │   ├── OrderKafkaPublisher.java
│   │   └── OrderJpaEntity.java     # Persistence model (separate from domain)
│   └── api/
│       ├── OrderController.java
│       └── OrderDto.java
├── inventory/
│   ├── domain/
│   ├── application/
│   ├── infrastructure/
│   └── api/
└── shared/
    └── kernel/
        ├── DomainEvent.java
        ├── AggregateRoot.java
        └── ValueObject.java
```

### Aggregate Root Pattern

```java
public abstract class AggregateRoot<ID> {

    @Getter
    private final List<DomainEvent> domainEvents = new ArrayList<>();

    protected void registerEvent(DomainEvent event) {
        domainEvents.add(event);
    }

    public List<DomainEvent> clearEvents() {
        List<DomainEvent> events = List.copyOf(domainEvents);
        domainEvents.clear();
        return events;
    }
}

public class Order extends AggregateRoot<OrderId> {

    private OrderId id;
    private CustomerId customerId;
    private List<OrderLine> lines = new ArrayList<>();
    private OrderStatus status;
    private Money totalAmount;

    public static Order place(CustomerId customerId, List<OrderLine> lines) {
        Order order = new Order();
        order.id = OrderId.generate();
        order.customerId = customerId;
        order.lines = List.copyOf(lines);
        order.status = OrderStatus.PLACED;
        order.totalAmount = lines.stream()
            .map(OrderLine::subtotal)
            .reduce(Money.ZERO, Money::add);
        order.registerEvent(new OrderPlacedEvent(order.id, order.customerId, order.totalAmount));
        return order;
    }

    public void cancel(String reason) {
        if (status == OrderStatus.SHIPPED) {
            throw new OrderDomainException("Cannot cancel a shipped order");
        }
        status = OrderStatus.CANCELLED;
        registerEvent(new OrderCancelledEvent(id, reason));
    }
}
```

### Value Objects

```java
public record Money(BigDecimal amount, Currency currency) {

    public static final Money ZERO = new Money(BigDecimal.ZERO, Currency.getInstance("USD"));

    public Money {
        if (amount.scale() > 2) {
            throw new IllegalArgumentException("Money cannot have more than 2 decimal places");
        }
    }

    public Money add(Money other) {
        if (!currency.equals(other.currency)) {
            throw new IllegalArgumentException("Cannot add different currencies");
        }
        return new Money(amount.add(other.amount), currency);
    }
}

public record OrderId(UUID value) {
    public static OrderId generate() {
        return new OrderId(UUID.randomUUID());
    }

    public static OrderId of(String raw) {
        return new OrderId(UUID.fromString(raw));
    }
}
```

### Separate Domain Model from Persistence Model

```java
@Entity
@Table(name = "orders")
@Getter
@Setter
@NoArgsConstructor
class OrderJpaEntity {

    @Id
    private UUID id;
    private UUID customerId;

    @Enumerated(EnumType.STRING)
    private OrderStatus status;

    private BigDecimal totalAmount;
    private String currency;

    @OneToMany(cascade = CascadeType.ALL, orphanRemoval = true)
    @JoinColumn(name = "order_id")
    private List<OrderLineJpaEntity> lines = new ArrayList<>();
}

@Repository
@RequiredArgsConstructor
class JpaOrderRepository implements OrderRepository {

    private final OrderJpaEntityRepository jpa;
    private final OrderPersistenceMapper mapper;
    private final ApplicationEventPublisher eventPublisher;

    @Override
    @Transactional
    public void save(Order order) {
        OrderJpaEntity entity = mapper.toJpa(order);
        jpa.save(entity);
        order.clearEvents().forEach(eventPublisher::publishEvent);
    }

    @Override
    public Optional<Order> findById(OrderId id) {
        return jpa.findById(id.value()).map(mapper::toDomain);
    }
}
```

## CQRS

### Command Side

```java
public sealed interface Command permits PlaceOrderCommand, CancelOrderCommand {}

public record PlaceOrderCommand(
    UUID customerId,
    List<OrderLineRequest> lines
) implements Command {}

@Service
@RequiredArgsConstructor
public class PlaceOrderHandler {

    private final OrderRepository orderRepository;
    private final InventoryChecker inventoryChecker;

    @Transactional
    public OrderId handle(PlaceOrderCommand command) {
        command.lines().forEach(line ->
            inventoryChecker.ensureAvailable(line.productId(), line.quantity())
        );
        List<OrderLine> lines = command.lines().stream()
            .map(l -> new OrderLine(ProductId.of(l.productId()), l.quantity(), Money.of(l.unitPrice())))
            .toList();
        Order order = Order.place(CustomerId.of(command.customerId()), lines);
        orderRepository.save(order);
        return order.getId();
    }
}
```

### Query Side

```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class OrderQueryService {

    private final JdbcTemplate jdbc;

    public OrderSummaryDto findSummary(UUID orderId) {
        return jdbc.queryForObject("""
            SELECT o.id, o.status, o.total_amount, o.currency, o.created_at,
                   c.name as customer_name
            FROM orders o JOIN customers c ON o.customer_id = c.id
            WHERE o.id = ?
            """,
            (rs, i) -> new OrderSummaryDto(
                rs.getObject("id", UUID.class),
                rs.getString("status"),
                rs.getBigDecimal("total_amount"),
                rs.getString("customer_name"),
                rs.getTimestamp("created_at").toInstant()
            ),
            orderId
        );
    }

    public Page<OrderListDto> search(OrderSearchCriteria criteria, Pageable pageable) {
        // Use JdbcTemplate or jOOQ for complex read queries
        // Avoid loading full aggregate for read-only views
    }
}
```

### When to Use CQRS

| Use CQRS | Skip CQRS |
|-----------|-----------|
| Read/write models diverge significantly | Simple CRUD with matching read/write shapes |
| Complex queries spanning multiple aggregates | Single aggregate reads |
| Different scaling needs for reads vs writes | Low traffic, uniform load |
| Event sourcing is in play | No audit trail requirements |

## Event-Driven Architecture

### Domain Events with Spring

```java
public interface DomainEvent {
    Instant occurredAt();
    String eventType();
}

public record OrderPlacedEvent(
    OrderId orderId,
    CustomerId customerId,
    Money totalAmount,
    Instant occurredAt
) implements DomainEvent {

    public OrderPlacedEvent(OrderId orderId, CustomerId customerId, Money totalAmount) {
        this(orderId, customerId, totalAmount, Instant.now());
    }

    @Override
    public String eventType() {
        return "order.placed";
    }
}
```

### Transactional Outbox Pattern

```java
@Entity
@Table(name = "outbox_events")
@Getter
@Setter
@NoArgsConstructor
class OutboxEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String aggregateType;

    @Column(nullable = false)
    private UUID aggregateId;

    @Column(nullable = false)
    private String eventType;

    @Column(columnDefinition = "jsonb", nullable = false)
    private String payload;

    @Column(nullable = false)
    private Instant createdAt;

    private Instant publishedAt;
}

@Service
@RequiredArgsConstructor
class OutboxPublisher {

    private final OutboxEventRepository outboxRepository;
    private final ObjectMapper objectMapper;

    @TransactionalEventListener(phase = TransactionPhase.BEFORE_COMMIT)
    public void handleDomainEvent(DomainEvent event) {
        OutboxEvent outbox = new OutboxEvent();
        outbox.setAggregateType(extractAggregateType(event));
        outbox.setAggregateId(extractAggregateId(event));
        outbox.setEventType(event.eventType());
        outbox.setPayload(objectMapper.writeValueAsString(event));
        outbox.setCreatedAt(event.occurredAt());
        outboxRepository.save(outbox);
    }
}

@Component
@RequiredArgsConstructor
@Slf4j
class OutboxPoller {

    private final OutboxEventRepository outboxRepository;
    private final KafkaTemplate<String, String> kafkaTemplate;

    @Scheduled(fixedDelay = 1000)
    @Transactional
    public void publishPending() {
        List<OutboxEvent> events = outboxRepository.findByPublishedAtIsNullOrderByCreatedAt();
        for (OutboxEvent event : events) {
            kafkaTemplate.send(event.getEventType(), event.getAggregateId().toString(), event.getPayload());
            event.setPublishedAt(Instant.now());
        }
    }
}
```

### Kafka Consumer with Idempotency

```java
@Component
@RequiredArgsConstructor
@Slf4j
public class OrderEventConsumer {

    private final ProcessedEventRepository processedEventRepository;
    private final InventoryService inventoryService;

    @KafkaListener(topics = "order.placed", groupId = "inventory-service")
    @Transactional
    public void handleOrderPlaced(ConsumerRecord<String, String> record) {
        String eventId = record.headers().lastHeader("event-id") != null
            ? new String(record.headers().lastHeader("event-id").value())
            : record.key() + "-" + record.offset();

        if (processedEventRepository.existsById(eventId)) {
            log.info("Skipping duplicate event: {}", eventId);
            return;
        }

        OrderPlacedPayload payload = objectMapper.readValue(record.value(), OrderPlacedPayload.class);
        inventoryService.reserveStock(payload.orderId(), payload.lines());

        processedEventRepository.save(new ProcessedEvent(eventId, Instant.now()));
    }
}
```

## Distributed Transactions

### Saga Pattern (Orchestration)

```java
@Service
@RequiredArgsConstructor
@Slf4j
public class OrderSaga {

    private final PaymentService paymentService;
    private final InventoryService inventoryService;
    private final ShippingService shippingService;
    private final OrderRepository orderRepository;

    @Transactional
    public void execute(OrderId orderId) {
        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new ResourceNotFoundException("Order", orderId));

        try {
            PaymentId paymentId = paymentService.charge(order.getCustomerId(), order.getTotalAmount());
            try {
                inventoryService.reserve(order.getLines());
                try {
                    shippingService.schedule(order);
                    order.markConfirmed();
                } catch (Exception e) {
                    log.error("Shipping failed, compensating", e);
                    inventoryService.release(order.getLines());
                    paymentService.refund(paymentId);
                    order.markFailed("Shipping failed: " + e.getMessage());
                }
            } catch (Exception e) {
                log.error("Inventory reservation failed, compensating", e);
                paymentService.refund(paymentId);
                order.markFailed("Inventory unavailable: " + e.getMessage());
            }
        } catch (Exception e) {
            log.error("Payment failed", e);
            order.markFailed("Payment declined: " + e.getMessage());
        }

        orderRepository.save(order);
    }
}
```

### Saga Decision Table

| Pattern | Use When | Complexity | Consistency |
|---------|----------|------------|-------------|
| Orchestration Saga | Clear sequential steps, central coordinator | Medium | Eventual |
| Choreography Saga | Loose coupling, services react to events | High (hard to trace) | Eventual |
| Two-Phase Commit | Strong consistency required (rare in microservices) | High | Strong |
| Local transactions only | Single service boundary | Low | Strong |

## Microservice Communication

### Synchronous (REST/gRPC)

```java
@Configuration
public class RestClientConfig {

    @Bean
    public RestClient inventoryClient(RestClient.Builder builder) {
        return builder
            .baseUrl("http://inventory-service:8080")
            .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
            .requestInterceptor(new PropagateTracingInterceptor())
            .build();
    }
}

@Service
@RequiredArgsConstructor
public class InventoryClient {

    private final RestClient inventoryClient;

    public StockLevel checkStock(UUID productId) {
        return inventoryClient.get()
            .uri("/api/stock/{productId}", productId)
            .retrieve()
            .body(StockLevel.class);
    }
}
```

### Circuit Breaker with Resilience4j

```java
@Service
@RequiredArgsConstructor
public class PaymentServiceClient {

    private final RestClient paymentClient;

    @CircuitBreaker(name = "payment", fallbackMethod = "paymentFallback")
    @Retry(name = "payment")
    @TimeLimiter(name = "payment")
    public CompletableFuture<PaymentResult> charge(PaymentRequest request) {
        PaymentResult result = paymentClient.post()
            .uri("/api/payments")
            .body(request)
            .retrieve()
            .body(PaymentResult.class);
        return CompletableFuture.completedFuture(result);
    }

    private CompletableFuture<PaymentResult> paymentFallback(PaymentRequest request, Throwable t) {
        return CompletableFuture.completedFuture(PaymentResult.deferred(request.orderId()));
    }
}
```

```yaml
resilience4j:
  circuitbreaker:
    instances:
      payment:
        sliding-window-size: 10
        failure-rate-threshold: 50
        wait-duration-in-open-state: 30s
        permitted-number-of-calls-in-half-open-state: 3
  retry:
    instances:
      payment:
        max-attempts: 3
        wait-duration: 500ms
        exponential-backoff-multiplier: 2
  timelimiter:
    instances:
      payment:
        timeout-duration: 3s
```

### Service Communication Decision Table

| Pattern | Latency | Coupling | Use For |
|---------|---------|----------|---------|
| REST (synchronous) | Higher | Tight | Simple request/response, real-time needs |
| gRPC | Lower | Tight (schema) | High-throughput internal communication |
| Kafka (async events) | Variable | Loose | Event notification, eventual consistency |
| RabbitMQ (async commands) | Low | Medium | Task queues, work distribution |

## Observability

### Structured Logging with MDC

```java
@Component
public class CorrelationIdFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                     FilterChain chain) throws ServletException, IOException {
        String correlationId = Optional.ofNullable(request.getHeader("X-Correlation-Id"))
            .orElse(UUID.randomUUID().toString());
        MDC.put("correlationId", correlationId);
        MDC.put("service", "order-service");
        response.setHeader("X-Correlation-Id", correlationId);
        try {
            chain.doFilter(request, response);
        } finally {
            MDC.clear();
        }
    }
}
```

```yaml
logging:
  pattern:
    console: "%d{ISO8601} [%thread] %-5level [%X{correlationId}] %logger{36} - %msg%n"
```

### Micrometer Metrics

```java
@Service
@RequiredArgsConstructor
public class OrderService {

    private final MeterRegistry meterRegistry;
    private final Timer orderProcessingTimer;

    public OrderService(MeterRegistry meterRegistry, OrderRepository orderRepository) {
        this.meterRegistry = meterRegistry;
        this.orderProcessingTimer = Timer.builder("order.processing.duration")
            .description("Time to process an order")
            .tag("service", "order")
            .register(meterRegistry);
    }

    public OrderId placeOrder(PlaceOrderCommand command) {
        return orderProcessingTimer.record(() -> {
            OrderId id = doPlaceOrder(command);
            meterRegistry.counter("order.placed.total", "status", "success").increment();
            return id;
        });
    }
}
```

### Health Checks for Dependencies

```java
@Component
@RequiredArgsConstructor
public class KafkaHealthIndicator implements HealthIndicator {

    private final KafkaAdmin kafkaAdmin;

    @Override
    public Health health() {
        try (AdminClient client = AdminClient.create(kafkaAdmin.getConfigurationProperties())) {
            client.listTopics().names().get(5, TimeUnit.SECONDS);
            return Health.up().build();
        } catch (Exception e) {
            return Health.down().withException(e).build();
        }
    }
}
```

## Production Hardening

### Graceful Shutdown

```yaml
server:
  shutdown: graceful

spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s
```

### Rate Limiting with Bucket4j

```java
@Configuration
public class RateLimitConfig {

    @Bean
    public Bucket rateLimitBucket() {
        return Bucket.builder()
            .addLimit(BandwidthBuilder.builder()
                .capacity(100)
                .refillGreedy(100, Duration.ofMinutes(1))
                .build())
            .build();
    }
}

@RestControllerAdvice
@RequiredArgsConstructor
public class RateLimitInterceptor implements HandlerInterceptor {

    private final Bucket bucket;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response,
                              Object handler) {
        if (!bucket.tryConsume(1)) {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            return false;
        }
        return true;
    }
}
```

### Database Connection Pool Tuning

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      idle-timeout: 300000
      connection-timeout: 20000
      max-lifetime: 1200000
      leak-detection-threshold: 60000
```

| Parameter | Guideline |
|-----------|-----------|
| `maximum-pool-size` | `(2 * CPU cores) + effective_disk_spindles` as baseline, tune under load |
| `minimum-idle` | Set equal to `maximum-pool-size` for steady traffic |
| `connection-timeout` | 20-30s, fail fast rather than queue indefinitely |
| `leak-detection-threshold` | Set to 2x your longest expected query time |

### Flyway in Multi-Instance Deployments

```yaml
spring:
  flyway:
    enabled: true
    baseline-on-migrate: true
    out-of-order: false
    lock-retry-count: 10
```

Migration rules for zero-downtime deployments:

| Safe Operation | Unsafe Operation | Migration Strategy |
|---------------|-----------------|-------------------|
| Add nullable column | Rename column | Add new -> migrate data -> drop old (3 deploys) |
| Add index concurrently | Drop column in use | Remove code references first, drop column next deploy |
| Add new table | Change column type | Add new column -> migrate -> drop old |
| Add default value | Add NOT NULL to existing column | Backfill nulls first, then add constraint |

## Testing Strategy for Senior Engineers

### Test Pyramid Ratios

| Level | Ratio | Speed | Scope |
|-------|-------|-------|-------|
| Unit (domain logic) | 70% | ms | Single class/method |
| Integration (slices) | 20% | seconds | Component + dependencies |
| E2E (full stack) | 10% | minutes | Full request flow |

### Architecture Tests with ArchUnit

```java
@AnalyzeClasses(packages = "com.example")
class ArchitectureTest {

    @ArchTest
    static final ArchRule domainShouldNotDependOnInfrastructure =
        noClasses().that().resideInAPackage("..domain..")
            .should().dependOnClassesThat().resideInAPackage("..infrastructure..");

    @ArchTest
    static final ArchRule controllersShouldNotAccessRepositories =
        noClasses().that().resideInAPackage("..api..")
            .should().dependOnClassesThat().resideInAPackage("..infrastructure..");

    @ArchTest
    static final ArchRule servicesShouldBeTransactional =
        classes().that().resideInAPackage("..application..")
            .and().areAnnotatedWith(Service.class)
            .should().beAnnotatedWith(Transactional.class);
}
```

### Testcontainers Shared Setup

```java
public abstract class IntegrationTestBase {

    static final PostgreSQLContainer<?> POSTGRES =
        new PostgreSQLContainer<>("postgres:16-alpine")
            .withReuse(true);

    static final KafkaContainer KAFKA =
        new KafkaContainer(DockerImageName.parse("confluentinc/cp-kafka:7.5.0"))
            .withReuse(true);

    static {
        POSTGRES.start();
        KAFKA.start();
    }

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("spring.kafka.bootstrap-servers", KAFKA::getBootstrapServers);
    }
}
```

## API Versioning

| Strategy | Example | Pros | Cons |
|----------|---------|------|------|
| URI path | `/api/v1/orders` | Simple, explicit | URL pollution |
| Header | `Accept: application/vnd.app.v1+json` | Clean URLs | Less discoverable |
| Query param | `/api/orders?version=1` | Easy to test | Not RESTful |

```java
@RestController
@RequestMapping("/api/v1/orders")
public class OrderControllerV1 { }

@RestController
@RequestMapping("/api/v2/orders")
public class OrderControllerV2 { }
```

## Configuration Management

### Multi-Environment Config

```yaml
# application.yml (defaults)
app:
  feature-flags:
    new-checkout: false
    async-notifications: true

---
# application-prod.yml
app:
  feature-flags:
    new-checkout: ${FEATURE_NEW_CHECKOUT:false}
```

### Secrets Management

| Approach | Use When |
|----------|----------|
| Environment variables | Simple deployments, CI/CD pipelines |
| Spring Cloud Config | Centralized config across services |
| HashiCorp Vault | Secrets rotation, fine-grained access control |
| AWS Secrets Manager / GCP Secret Manager | Cloud-native deployments |

Never store secrets in `application.yml` committed to version control. Use `${ENV_VAR}` placeholders or external secret stores.
