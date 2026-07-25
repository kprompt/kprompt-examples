# 07 · Dependencies (namespace memory demo)

Adds a realistic dependency graph to `payments`: a Redis and a Postgres, plus an
`orders` app wired to both through env vars — and failing with connection errors.

Namespace memory discovers dependencies from **Service names, container images, and
env var names**, so all three signals are present here on purpose.

## What the agent should do

| Stage | Expected |
|-------|----------|
| Discover | `redis` and `postgres` show up as `dependency` facts |
| Source | Service name (`redis`), image (`postgres:16-alpine`), env (`REDIS_URL`, `DATABASE_URL`) |
| Relevance | The connection-refused incident text mentions redis, so those facts get injected into the analyzer context |
| Analyze | Root cause reasons about the dependency instead of only "container exited 1" |

## Run

```bash
make break SCENARIO=07-dependencies

# Inspect what memory learned
kprompt agent memory discover -n payments
kprompt agent memory list -n payments

# Then watch with memory injected into the analyzer context
kprompt agent run -n payments --analyze --health --heuristic --memory --fetch-logs

make fix SCENARIO=07-dependencies
```

## Notes

Redis and Postgres here are **busybox stubs**, not real databases. Memory discovery
keys off Service names (`redis`, `postgres`) and env vars (`REDIS_URL`,
`DATABASE_URL`) — pulling `postgres:16` / `redis:7` on a crowded kind node often
fails with disk pressure (`initdb: No space left on device`) and turns the demo
into a storage incident instead of a dependency story.

The `orders` app points at `redis-master` (a hostname that does not resolve) while
the actual Service is `redis`, which is why it fails with connection refused. That
mismatch is the kind of thing the memory facts help an analysis catch.

Facts are stored locally (`~/.config/kprompt/memory`) by default and never uploaded.
Use `--memory-backend configmap` for the in-cluster variant.
