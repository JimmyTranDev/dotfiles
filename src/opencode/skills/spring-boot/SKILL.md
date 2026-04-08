---
name: spring-boot
description: Java Spring Boot patterns covering project structure, REST controllers, service layer, JPA entities and repositories, Spring Data queries, dependency injection, configuration, security, validation, exception handling, testing, and common pitfalls
---

## Project Structure

```
src/
├── main/
│   ├── java/com/example/app/
│   │   ├── Application.java
│   │   ├── config/
│   │   ├── controller/
│   │   ├── service/
│   │   ├── repository/
│   │   ├── entity/
│   │   ├── dto/
│   │   ├── mapper/
│   │   ├── exception/
│   │   └── security/
│   └── resources/
│       ├── application.yml
│       ├── application-dev.yml
│       ├── application-prod.yml
│       ├── db/migration/          # Flyway
│       └── static/
└── test/
    └── java/com/example/app/
        ├── controller/
        ├── service/
        └── repository/
```

| Layer | Responsibility |
|-------|---------------|
| `controller/` | HTTP endpoints, request/response mapping, validation |
| `service/` | Business logic, transaction boundaries |
| `repository/` | Data access, JPA queries |
| `entity/` | JPA entity classes (DB tables) |
| `dto/` | Request/response data transfer objects |
| `mapper/` | Entity-to-DTO conversion |
| `config/` | Bean definitions, CORS, security, etc. |
| `exception/` | Custom exceptions and global error handlers |

## Application Entry Point

```java
@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

`@SpringBootApplication` combines `@Configuration`, `@EnableAutoConfiguration`, and `@ComponentScan`.

## REST Controllers

```java
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping
    public List<UserResponse> getAll() {
        return userService.findAll();
    }

    @GetMapping("/{id}")
    public UserResponse getById(@PathVariable Long id) {
        return userService.findById(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse create(@Valid @RequestBody CreateUserRequest request) {
        return userService.create(request);
    }

    @PutMapping("/{id}")
    public UserResponse update(@PathVariable Long id, @Valid @RequestBody UpdateUserRequest request) {
        return userService.update(id, request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        userService.delete(id);
    }
}
```

### ResponseEntity for Custom Responses

```java
@GetMapping("/{id}")
public ResponseEntity<UserResponse> getById(@PathVariable Long id) {
    return userService.findById(id)
        .map(ResponseEntity::ok)
        .orElse(ResponseEntity.notFound().build());
}

@PostMapping
public ResponseEntity<UserResponse> create(@Valid @RequestBody CreateUserRequest request) {
    UserResponse created = userService.create(request);
    URI location = URI.create("/api/users/" + created.id());
    return ResponseEntity.created(location).body(created);
}
```

### Pagination

```java
@GetMapping
public Page<UserResponse> getAll(
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size,
        @RequestParam(defaultValue = "createdAt,desc") String[] sort) {
    Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
    return userService.findAll(pageable);
}
```

## Service Layer

```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;

    public List<UserResponse> findAll() {
        return userRepository.findAll().stream()
            .map(userMapper::toResponse)
            .toList();
    }

    public UserResponse findById(Long id) {
        User user = userRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("User", id));
        return userMapper.toResponse(user);
    }

    @Transactional
    public UserResponse create(CreateUserRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new DuplicateResourceException("User with email " + request.email() + " already exists");
        }
        User user = userMapper.toEntity(request);
        User saved = userRepository.save(user);
        return userMapper.toResponse(saved);
    }

    @Transactional
    public UserResponse update(Long id, UpdateUserRequest request) {
        User user = userRepository.findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("User", id));
        userMapper.updateEntity(user, request);
        User saved = userRepository.save(user);
        return userMapper.toResponse(saved);
    }

    @Transactional
    public void delete(Long id) {
        if (!userRepository.existsById(id)) {
            throw new ResourceNotFoundException("User", id);
        }
        userRepository.deleteById(id);
    }
}
```

## JPA Entities

```java
@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String password;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role;

    @Column(nullable = false)
    private boolean active = true;

    @CreationTimestamp
    @Column(updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    private Instant updatedAt;

    @OneToMany(mappedBy = "author", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Post> posts = new ArrayList<>();
}
```

### Relationship Annotations

| Annotation | Usage |
|-----------|-------|
| `@OneToMany(mappedBy = "field")` | Parent side of 1:N |
| `@ManyToOne` | Child side of N:1 |
| `@OneToOne` | 1:1 relationship |
| `@ManyToMany` | N:N with join table |
| `@JoinColumn(name = "col")` | FK column on owning side |
| `@JoinTable` | Explicit join table for M:N |

### Fetch Types

| Relationship | Default Fetch | Recommendation |
|-------------|--------------|----------------|
| `@ManyToOne` | EAGER | Keep EAGER or set LAZY with `@EntityGraph` |
| `@OneToMany` | LAZY | Keep LAZY, fetch via query when needed |
| `@OneToOne` | EAGER | Set LAZY if rarely accessed |
| `@ManyToMany` | LAZY | Keep LAZY, use `@EntityGraph` for eager cases |

```java
@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(name = "author_id", nullable = false)
private User author;
```

### Embedded Types

```java
@Embeddable
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class Address {
    private String street;
    private String city;
    private String state;
    private String zipCode;
}

@Entity
public class Customer {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Embedded
    private Address address;
}
```

## Repositories

```java
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    List<User> findByActiveTrue();

    List<User> findByRoleAndActiveTrue(Role role);

    Page<User> findByNameContainingIgnoreCase(String name, Pageable pageable);

    @Query("SELECT u FROM User u WHERE u.createdAt >= :since AND u.active = true")
    List<User> findRecentActiveUsers(@Param("since") Instant since);

    @Query("SELECT u FROM User u JOIN FETCH u.posts WHERE u.id = :id")
    Optional<User> findByIdWithPosts(@Param("id") Long id);

    @Modifying
    @Query("UPDATE User u SET u.active = false WHERE u.lastLoginAt < :cutoff")
    int deactivateInactiveUsers(@Param("cutoff") Instant cutoff);
}
```

### Spring Data Query Method Keywords

| Keyword | Example | JPQL Equivalent |
|---------|---------|----------------|
| `findBy` | `findByName(String)` | `WHERE name = ?` |
| `findAllBy` | `findAllByActive(boolean)` | `WHERE active = ?` |
| `existsBy` | `existsByEmail(String)` | `SELECT CASE WHEN COUNT > 0` |
| `countBy` | `countByRole(Role)` | `SELECT COUNT(*)` |
| `deleteBy` | `deleteByEmail(String)` | `DELETE WHERE email = ?` |
| `And` | `findByNameAndEmail(...)` | `AND` |
| `Or` | `findByNameOrEmail(...)` | `OR` |
| `Between` | `findByCreatedAtBetween(...)` | `BETWEEN ? AND ?` |
| `LessThan` | `findByAgeLessThan(int)` | `< ?` |
| `GreaterThan` | `findByAgeGreaterThan(int)` | `> ?` |
| `Like` | `findByNameLike(String)` | `LIKE ?` |
| `Containing` | `findByNameContaining(String)` | `LIKE %?%` |
| `IgnoreCase` | `findByNameIgnoreCase(String)` | `UPPER(name) = UPPER(?)` |
| `OrderBy` | `findByActiveOrderByNameAsc(...)` | `ORDER BY name ASC` |
| `In` | `findByRoleIn(List<Role>)` | `IN (?)` |
| `IsNull` | `findByDeletedAtIsNull()` | `IS NULL` |
| `IsNotNull` | `findByDeletedAtIsNotNull()` | `IS NOT NULL` |
| `True`/`False` | `findByActiveTrue()` | `= true` |
| `Top`/`First` | `findTop5ByOrderByCreatedAtDesc()` | `LIMIT 5` |

### Specifications (Dynamic Queries)

```java
public class UserSpecifications {

    public static Specification<User> hasName(String name) {
        return (root, query, cb) -> cb.like(cb.lower(root.get("name")), "%" + name.toLowerCase() + "%");
    }

    public static Specification<User> isActive() {
        return (root, query, cb) -> cb.isTrue(root.get("active"));
    }

    public static Specification<User> hasRole(Role role) {
        return (root, query, cb) -> cb.equal(root.get("role"), role);
    }
}
```

Repository must extend `JpaSpecificationExecutor<User>`:

```java
public interface UserRepository extends JpaRepository<User, Long>, JpaSpecificationExecutor<User> {}
```

Usage:

```java
Specification<User> spec = Specification.where(UserSpecifications.isActive())
    .and(UserSpecifications.hasRole(Role.ADMIN));
List<User> admins = userRepository.findAll(spec);
```

### Entity Graphs

```java
@EntityGraph(attributePaths = {"posts", "posts.comments"})
Optional<User> findWithPostsAndCommentsById(Long id);
```

## DTOs and Records

```java
public record CreateUserRequest(
    @NotBlank String name,
    @Email @NotBlank String email,
    @Size(min = 8) String password
) {}

public record UpdateUserRequest(
    @NotBlank String name,
    @Email String email
) {}

public record UserResponse(
    Long id,
    String name,
    String email,
    Role role,
    boolean active,
    Instant createdAt
) {}
```

## Mappers

### Manual Mapper

```java
@Component
public class UserMapper {

    public UserResponse toResponse(User user) {
        return new UserResponse(
            user.getId(),
            user.getName(),
            user.getEmail(),
            user.getRole(),
            user.isActive(),
            user.getCreatedAt()
        );
    }

    public User toEntity(CreateUserRequest request) {
        return User.builder()
            .name(request.name())
            .email(request.email())
            .password(request.password())
            .role(Role.USER)
            .active(true)
            .build();
    }

    public void updateEntity(User user, UpdateUserRequest request) {
        user.setName(request.name());
        if (request.email() != null) {
            user.setEmail(request.email());
        }
    }
}
```

### MapStruct

```java
@Mapper(componentModel = "spring")
public interface UserMapper {

    UserResponse toResponse(User user);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "role", constant = "USER")
    @Mapping(target = "active", constant = "true")
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    User toEntity(CreateUserRequest request);

    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateEntity(@MappingTarget User user, UpdateUserRequest request);
}
```

## Validation

### Common Annotations

| Annotation | Purpose |
|-----------|---------|
| `@NotNull` | Must not be null |
| `@NotBlank` | Must not be null or blank (strings) |
| `@NotEmpty` | Must not be null or empty (collections, strings) |
| `@Size(min, max)` | Size constraints |
| `@Min(value)` / `@Max(value)` | Numeric bounds |
| `@Email` | Email format |
| `@Pattern(regexp)` | Regex match |
| `@Positive` / `@PositiveOrZero` | Positive number |
| `@Past` / `@Future` | Date constraints |
| `@Valid` | Cascade validation to nested objects |

### Custom Validator

```java
@Target({ElementType.FIELD})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = UniqueEmailValidator.class)
public @interface UniqueEmail {
    String message() default "Email already exists";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

@Component
@RequiredArgsConstructor
public class UniqueEmailValidator implements ConstraintValidator<UniqueEmail, String> {

    private final UserRepository userRepository;

    @Override
    public boolean isValid(String email, ConstraintValidatorContext context) {
        return email != null && !userRepository.existsByEmail(email);
    }
}
```

## Exception Handling

### Custom Exceptions

```java
@ResponseStatus(HttpStatus.NOT_FOUND)
public class ResourceNotFoundException extends RuntimeException {
    public ResourceNotFoundException(String resource, Object id) {
        super(resource + " not found with id: " + id);
    }
}

@ResponseStatus(HttpStatus.CONFLICT)
public class DuplicateResourceException extends RuntimeException {
    public DuplicateResourceException(String message) {
        super(message);
    }
}
```

### Global Exception Handler

```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ProblemDetail handleNotFound(ResourceNotFoundException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
    }

    @ExceptionHandler(DuplicateResourceException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public ProblemDetail handleDuplicate(DuplicateResourceException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        problem.setTitle("Validation failed");
        Map<String, String> errors = new HashMap<>();
        ex.getBindingResult().getFieldErrors()
            .forEach(e -> errors.put(e.getField(), e.getDefaultMessage()));
        problem.setProperty("errors", errors);
        return problem;
    }

    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public ProblemDetail handleGeneral(Exception ex) {
        log.error("Unhandled exception", ex);
        return ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred");
    }
}
```

## Configuration

### application.yml

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/mydb
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false
    properties:
      hibernate:
        default_batch_fetch_size: 16
        format_sql: true
  flyway:
    enabled: true
    locations: classpath:db/migration

server:
  port: 8080

logging:
  level:
    org.hibernate.SQL: DEBUG
    org.hibernate.type.descriptor.sql.BasicBinder: TRACE
```

### Configuration Properties

```java
@ConfigurationProperties(prefix = "app")
@Validated
public record AppProperties(
    @NotBlank String name,
    @NotNull SecurityProperties security,
    @NotNull CorsProperties cors
) {
    public record SecurityProperties(
        @NotBlank String jwtSecret,
        @Positive long jwtExpirationMs
    ) {}

    public record CorsProperties(
        List<String> allowedOrigins,
        List<String> allowedMethods
    ) {}
}
```

Enable with `@EnableConfigurationProperties(AppProperties.class)` on a `@Configuration` class.

```yaml
app:
  name: my-service
  security:
    jwt-secret: ${JWT_SECRET}
    jwt-expiration-ms: 86400000
  cors:
    allowed-origins:
      - http://localhost:3000
    allowed-methods:
      - GET
      - POST
      - PUT
      - DELETE
```

### Profiles

| Profile | Purpose | Activation |
|---------|---------|-----------|
| `dev` | Local development | `spring.profiles.active=dev` |
| `test` | Test configuration | `@ActiveProfiles("test")` |
| `prod` | Production | `SPRING_PROFILES_ACTIVE=prod` |

Profile-specific config: `application-{profile}.yml` overrides `application.yml`.

```java
@Profile("dev")
@Configuration
public class DevConfig {
    @Bean
    public CommandLineRunner seedData(UserRepository repo) {
        return args -> {
            if (repo.count() == 0) {
                repo.save(User.builder().name("Dev User").email("dev@test.com").build());
            }
        };
    }
}
```

## Dependency Injection

### Preferred: Constructor Injection

```java
@Service
@RequiredArgsConstructor
public class OrderService {
    private final OrderRepository orderRepository;
    private final UserService userService;
    private final PaymentGateway paymentGateway;
}
```

`@RequiredArgsConstructor` (Lombok) generates a constructor for all `final` fields. Spring auto-injects when there's a single constructor.

### Qualifiers

```java
public interface NotificationSender {
    void send(String to, String message);
}

@Service("emailSender")
public class EmailNotificationSender implements NotificationSender { ... }

@Service("smsSender")
public class SmsNotificationSender implements NotificationSender { ... }

@Service
@RequiredArgsConstructor
public class NotificationService {
    @Qualifier("emailSender")
    private final NotificationSender sender;
}
```

### Conditional Beans

| Annotation | Condition |
|-----------|-----------|
| `@ConditionalOnProperty(name, havingValue)` | Property matches value |
| `@ConditionalOnMissingBean` | No existing bean of type |
| `@ConditionalOnClass` | Class is on classpath |
| `@ConditionalOnProfile` | Active profile matches |

## Spring Security

### SecurityFilterChain (Spring Security 6+)

```java
@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtFilter;

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .requestMatchers(HttpMethod.GET, "/api/posts/**").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
```

### JWT Filter

```java
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final UserDetailsService userDetailsService;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                     FilterChain chain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header == null || !header.startsWith("Bearer ")) {
            chain.doFilter(request, response);
            return;
        }

        String token = header.substring(7);
        String username = jwtService.extractUsername(token);

        if (username != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            UserDetails userDetails = userDetailsService.loadUserByUsername(username);
            if (jwtService.isTokenValid(token, userDetails)) {
                UsernamePasswordAuthenticationToken auth =
                    new UsernamePasswordAuthenticationToken(userDetails, null, userDetails.getAuthorities());
                auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                SecurityContextHolder.getContext().setAuthentication(auth);
            }
        }

        chain.doFilter(request, response);
    }
}
```

### Method Security

```java
@EnableMethodSecurity
@Configuration
public class MethodSecurityConfig {}

@Service
public class PostService {
    @PreAuthorize("hasRole('ADMIN') or #userId == authentication.principal.id")
    public void deletePost(Long userId, Long postId) { ... }

    @PreAuthorize("isAuthenticated()")
    public Post createPost(CreatePostRequest request) { ... }
}
```

## Caching

```java
@EnableCaching
@Configuration
public class CacheConfig {}

@Service
public class ProductService {

    @Cacheable(value = "products", key = "#id")
    public ProductResponse findById(Long id) { ... }

    @CachePut(value = "products", key = "#result.id")
    public ProductResponse update(Long id, UpdateProductRequest request) { ... }

    @CacheEvict(value = "products", key = "#id")
    public void delete(Long id) { ... }

    @CacheEvict(value = "products", allEntries = true)
    public void clearCache() {}
}
```

## Scheduling

```java
@EnableScheduling
@Configuration
public class SchedulingConfig {}

@Component
@RequiredArgsConstructor
@Slf4j
public class CleanupTask {

    private final UserService userService;

    @Scheduled(cron = "0 0 2 * * *")
    public void deactivateInactiveUsers() {
        int count = userService.deactivateInactiveUsers();
        log.info("Deactivated {} inactive users", count);
    }

    @Scheduled(fixedRate = 60000)
    public void healthCheck() {
        log.debug("Health check ping");
    }
}
```

## Events

```java
public record UserCreatedEvent(Long userId, String email) {}

@Service
@RequiredArgsConstructor
public class UserService {
    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public UserResponse create(CreateUserRequest request) {
        User saved = userRepository.save(userMapper.toEntity(request));
        eventPublisher.publishEvent(new UserCreatedEvent(saved.getId(), saved.getEmail()));
        return userMapper.toResponse(saved);
    }
}

@Component
@RequiredArgsConstructor
@Slf4j
public class UserEventListener {

    private final EmailService emailService;

    @EventListener
    public void onUserCreated(UserCreatedEvent event) {
        log.info("User created: {}", event.userId());
        emailService.sendWelcome(event.email());
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void afterUserCreated(UserCreatedEvent event) {
        log.info("Post-commit: send analytics for user {}", event.userId());
    }
}
```

## Flyway Migrations

Migration files in `src/main/resources/db/migration/`:

| Naming | Purpose |
|--------|---------|
| `V1__create_users.sql` | Versioned migration |
| `V2__add_posts_table.sql` | Next version |
| `R__refresh_views.sql` | Repeatable migration |

```sql
-- V1__create_users.sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'USER',
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_active ON users(active);
```

## Testing

### Slice Tests

| Annotation | Scope | Use For |
|-----------|-------|---------|
| `@WebMvcTest(Controller.class)` | Controller layer only | Testing endpoints, validation |
| `@DataJpaTest` | JPA + DB layer only | Repository queries |
| `@SpringBootTest` | Full context | Integration tests |
| `@SpringBootTest(webEnvironment = RANDOM_PORT)` | Full server | End-to-end with TestRestTemplate |

### Controller Test

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UserService userService;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void getById_returnsUser() throws Exception {
        UserResponse response = new UserResponse(1L, "Alice", "alice@test.com", Role.USER, true, Instant.now());
        when(userService.findById(1L)).thenReturn(response);

        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Alice"))
            .andExpect(jsonPath("$.email").value("alice@test.com"));
    }

    @Test
    void create_withInvalidInput_returnsBadRequest() throws Exception {
        CreateUserRequest request = new CreateUserRequest("", "not-an-email", "short");

        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.errors").isNotEmpty());
    }
}
```

### Repository Test

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class UserRepositoryTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private UserRepository userRepository;

    @Test
    void findByEmail_returnsUser() {
        User user = User.builder().name("Alice").email("alice@test.com").password("pass").role(Role.USER).build();
        userRepository.save(user);

        Optional<User> found = userRepository.findByEmail("alice@test.com");

        assertThat(found).isPresent();
        assertThat(found.get().getName()).isEqualTo("Alice");
    }
}
```

### Service Test

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private UserMapper userMapper;

    @InjectMocks
    private UserService userService;

    @Test
    void findById_whenNotFound_throwsException() {
        when(userRepository.findById(1L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> userService.findById(1L))
            .isInstanceOf(ResourceNotFoundException.class)
            .hasMessageContaining("User");
    }
}
```

### Integration Test

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class UserIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void createAndGetUser() {
        CreateUserRequest request = new CreateUserRequest("Alice", "alice@test.com", "password123");

        ResponseEntity<UserResponse> createResponse = restTemplate.postForEntity("/api/users", request, UserResponse.class);
        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        ResponseEntity<UserResponse> getResponse = restTemplate.getForEntity(
            "/api/users/" + createResponse.getBody().id(), UserResponse.class);
        assertThat(getResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(getResponse.getBody().name()).isEqualTo("Alice");
    }
}
```

## Actuator

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized
  health:
    db:
      enabled: true
```

Custom health indicator:

```java
@Component
public class ExternalServiceHealthIndicator implements HealthIndicator {

    @Override
    public Health health() {
        boolean isUp = checkExternalService();
        return isUp ? Health.up().build() : Health.down().withDetail("reason", "Service unreachable").build();
    }
}
```

## Async Operations

```java
@EnableAsync
@Configuration
public class AsyncConfig {
    @Bean
    public Executor taskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(4);
        executor.setMaxPoolSize(8);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("async-");
        executor.initialize();
        return executor;
    }
}

@Service
public class NotificationService {
    @Async
    public CompletableFuture<Void> sendBulkNotifications(List<String> emails) {
        emails.forEach(this::sendEmail);
        return CompletableFuture.completedFuture(null);
    }
}
```

## Common Annotations Reference

| Annotation | Layer | Purpose |
|-----------|-------|---------|
| `@RestController` | Controller | REST controller with `@ResponseBody` |
| `@RequestMapping` | Controller | Base path mapping |
| `@GetMapping` / `@PostMapping` / `@PutMapping` / `@DeleteMapping` / `@PatchMapping` | Controller | HTTP method mappings |
| `@PathVariable` | Controller | URL path variable |
| `@RequestParam` | Controller | Query parameter |
| `@RequestBody` | Controller | JSON request body |
| `@Valid` | Controller | Trigger validation |
| `@ResponseStatus` | Controller | HTTP status code |
| `@Service` | Service | Service component |
| `@Transactional` | Service | Transaction boundary |
| `@Repository` | Repository | Repository component |
| `@Entity` | Entity | JPA entity |
| `@Table` | Entity | Table mapping |
| `@Id` | Entity | Primary key |
| `@GeneratedValue` | Entity | Auto-generated ID |
| `@Column` | Entity | Column mapping |
| `@Component` | Any | Generic Spring bean |
| `@Configuration` | Config | Configuration class |
| `@Bean` | Config | Bean factory method |
| `@Value("${prop}")` | Any | Inject property value |
| `@Slf4j` | Any | Lombok logger |
| `@RequiredArgsConstructor` | Any | Lombok constructor for final fields |

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| N+1 queries with lazy loading | Use `JOIN FETCH`, `@EntityGraph`, or `@BatchSize` |
| `LazyInitializationException` | Fetch within transaction scope, or use DTO projections |
| `spring.jpa.open-in-view=true` (default) | Set to `false` — avoids lazy loading in controllers |
| Mutable entities leaking outside transactions | Return DTOs from service layer, not entities |
| `@Transactional` on private methods | Must be on public methods (proxy-based AOP) |
| `@Transactional` self-invocation | Calling a `@Transactional` method from the same class bypasses proxy — extract to separate bean |
| Missing `@Modifying` on update/delete JPQL | Required for non-select JPQL queries |
| Field injection (`@Autowired` on field) | Use constructor injection with `@RequiredArgsConstructor` |
| Catching exceptions inside `@Transactional` | Transaction won't roll back — re-throw or use `@Transactional(noRollbackFor=...)` |
| Not using `ddl-auto: validate` in production | Never use `create` or `update` in prod — use Flyway/Liquibase |
| Circular dependencies | Refactor to break cycle, or use `@Lazy` on one injection point |
| `@SpringBootTest` for unit tests | Use `@WebMvcTest`, `@DataJpaTest`, or plain Mockito instead |
