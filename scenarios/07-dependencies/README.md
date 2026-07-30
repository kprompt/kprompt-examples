# 07 · Dependencies (namespace memory + Coordinator cross-ns demo)

Adds a realistic dependency graph:

- **payments:** local `redis` / `postgres` stubs (memory discovery) + failing `orders`
- **platform:** CrashLooping `cache` Service that `orders` actually dials

`orders` sets `REDIS_URL=redis://cache.platform.svc.cluster.local:6379/0` so
Namespace Agent Unknowns / summary can name **namespace platform**, and the
Coordinator `--probe-kube` path has real Pods/Events to merge.

## What the agent should do

| Stage | Expected |
|-------|----------|
| Discover | `redis` and `postgres` show up as `dependency` facts (local Services) |
| Source | Service name (`redis`), image stubs, env (`REDIS_URL`, `DATABASE_URL`) |
| Cross-ns | `REDIS_URL` / logs mention `cache.platform.svc` → suspect `platform` |
| Analyze | Root cause reasons about the dependency instead of only "container exited 1" |
| Coordinator | `make coordinator-e2e` → probe merges platform evidence, `mutateAttempted=false` |

## Run

```bash
make break SCENARIO=07-dependencies

# Inspect what memory learned
kprompt agent memory discover -n payments
kprompt agent memory list -n payments

# Then watch with memory injected into the analyzer context
kprompt agent run -n payments --analyze --health --heuristic --memory --fetch-logs

# Full Coordinator correlation E2E (probe + /v1/recent)
make coordinator-e2e

make fix SCENARIO=07-dependencies
```

## Notes

Redis and Postgres in **payments** are **busybox stubs**, not real databases.
The real failure is the cross-ns `cache` in **platform** (also a stub that exits).

Facts are stored locally (`~/.config/kprompt/memory`) by default and never uploaded.
Use `--memory-backend configmap` for the in-cluster variant.
