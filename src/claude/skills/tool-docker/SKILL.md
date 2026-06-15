---
name: tool-docker
description: Docker patterns covering Dockerfile best practices, multi-stage builds, Compose services, networking, volumes, health checks, and production optimization
---

## Dockerfile Patterns

| Instruction | Purpose | Best Practice |
|-------------|---------|---------------|
| `FROM` | Base image | Use specific tags, never `latest` |
| `RUN` | Execute commands | Chain with `&&`, clean up in same layer |
| `COPY` | Add files | Copy dependency files first for cache |
| `WORKDIR` | Set directory | Use absolute paths |
| `EXPOSE` | Document port | Does not publish, documentation only |
| `ENTRYPOINT` | Fixed command | Use exec form `["binary"]` |
| `CMD` | Default args | Use exec form, overridable |

```dockerfile
FROM node:20-alpine AS base
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production
COPY . .
USER node
EXPOSE 3000
ENTRYPOINT ["node"]
CMD ["dist/server.js"]
```

### Layer Ordering (most stable → least stable)

1. System dependencies (`apt-get`, `apk add`)
2. Language runtime setup
3. Dependency manifests (`package.json`, `pom.xml`)
4. Dependency install (`npm ci`, `mvn dependency:resolve`)
5. Application source code
6. Build step

## Multi-Stage Builds

```dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules
USER appuser
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

### Java Multi-Stage

```dockerfile
FROM eclipse-temurin:21-jdk AS builder
WORKDIR /app
COPY pom.xml mvnw ./
COPY .mvn .mvn
RUN ./mvnw dependency:resolve
COPY src ./src
RUN ./mvnw package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

## Docker Compose

```yaml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
      target: runner
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://<user>:<password>@db:5432/myapp
      - REDIS_URL=redis://cache:6379
    depends_on:
      db:
        condition: service_healthy
      cache:
        condition: service_started
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: mydb
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 5s
      timeout: 3s
      retries: 5

  cache:
    image: redis:7-alpine
    volumes:
      - redisdata:/data

volumes:
  pgdata:
  redisdata:
```

## Networking

| Network Type | Use Case |
|-------------|----------|
| `bridge` (default) | Single-host container communication |
| `host` | Container shares host network stack |
| `none` | No networking |
| Custom bridge | Isolated service groups with DNS |

```yaml
services:
  api:
    networks:
      - frontend
      - backend
  db:
    networks:
      - backend

networks:
  frontend:
  backend:
    internal: true
```

## Volumes

| Mount Type | Syntax | Use Case |
|-----------|--------|----------|
| Named volume | `mydata:/app/data` | Persistent data (DBs) |
| Bind mount | `./src:/app/src` | Development live reload |
| tmpfs | `tmpfs: /tmp` | Sensitive ephemeral data |

### Development Overrides

```yaml
services:
  api:
    volumes:
      - ./src:/app/src
      - /app/node_modules
```

## Health Checks

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1
```

| Parameter | Default | Recommendation |
|-----------|---------|----------------|
| `interval` | 30s | 10-30s for prod |
| `timeout` | 30s | 3-5s |
| `start-period` | 0s | Match app startup time |
| `retries` | 3 | 3-5 |

## Production Optimization

| Technique | Impact |
|-----------|--------|
| Alpine base images | 5-50MB vs 200-900MB |
| Multi-stage builds | Only runtime deps in final image |
| `.dockerignore` | Faster builds, smaller context |
| `npm ci --production` | No devDependencies |
| Non-root user | Security hardening |
| Read-only filesystem | `--read-only` flag |
| Resource limits | Prevent resource exhaustion |

### .dockerignore

```
node_modules
.git
.env*
dist
*.md
.vscode
coverage
```

### Resource Limits in Compose

```yaml
services:
  api:
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.25"
          memory: 128M
```

## Common Commands

| Command | Purpose |
|---------|---------|
| `docker build -t name:tag .` | Build image |
| `docker run -d -p 3000:3000 name` | Run detached |
| `docker exec -it container sh` | Shell into container |
| `docker logs -f container` | Follow logs |
| `docker compose up -d` | Start services |
| `docker compose down -v` | Stop and remove volumes |
| `docker system prune -af` | Clean everything |
| `docker stats` | Live resource usage |
| `docker inspect container` | Full container details |
| `docker cp container:/path ./local` | Copy files out |
