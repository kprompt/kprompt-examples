# Namespace Agent loop (demo guide)

Exercises the **Namespace Agent** path on top of the existing Observe scenarios
([AG-046](https://github.com/kprompt/kprompt-architecture/issues/204)).

No new broken workloads required — reuse `01`–`07`, then layer NA flags.

Contracts: [ADR-0016](https://github.com/kprompt/kprompt-architecture/blob/main/decisions/ADR-0016-namespace-agent.md) · docs in kprompt: [namespace-agent.md](https://github.com/kprompt/kprompt/blob/main/docs/namespace-agent.md).

## Prerequisites

```bash
make doctor
make up
make break-all   # or a single SCENARIO=
make verify
```

Use **kprompt** built from main (v0.5+ with NA flags). Prefer `--heuristic` so the
walkthrough stays offline.

## Loop A — Multi-signal RCA

Shows detectors → causal chain → InvestigationReport-shaped analysis.

```bash
make break SCENARIO=03-oom
make verify

kprompt agent run -n payments \
  --analyze --health --heuristic --fetch-logs \
  --duration 45s
```

| Expect | Why |
|--------|-----|
| Severity critical / objective outage | AG-030 priority + OOM detector |
| Root cause mentions memory exhaustion | AG-026 / AG-028 chain, not “CrashLoop” alone |
| Recommendation is check/verify style | Observe — no mutate |

## Loop B — Memory is not proof

```bash
make break SCENARIO=07-dependencies
make verify

kprompt agent memory discover -n payments
kprompt agent memory list -n payments

kprompt agent run -n payments \
  --analyze --heuristic --memory --fetch-logs \
  --duration 45s
```

| Expect | Why |
|--------|-----|
| `redis` / `postgres` facts listed | AG-015 discover |
| Prompt / context shows `namespace_memory (evidence, not proof)` | AG-034 |
| Confidence capped if only memory, no Events/logs | memory ≠ proof |

## Loop C — Patterns + outcome learning

```bash
make break SCENARIO=01-crashloop
make verify

# First pass learns the signature
kprompt agent run -n payments --analyze --heuristic --patterns --duration 30s

# Second pass should annotate “Seen before”
kprompt agent run -n payments --analyze --heuristic --patterns --duration 30s
```

Recover / FP (when Slack ask is wired in a richer demo):

- Alert recovered → pattern `Confirmed` weight up (AG-033)
- Slack `false positive` with `--patterns --slack-ask` → dampens boost

## Loop D — GitOps evidence (opt-in)

Only if Argo/Flux CRs exist **in `payments`** (kind demos usually skip this).

```bash
kprompt agent run -n payments \
  --analyze --heuristic --gitops-evidence \
  --duration 30s
```

| Expect | Why |
|--------|-----|
| `gitops:` evidence or `degraded: gitops` | AG-035 honesty — never invent sync state |

## Loop E — Coordinator handoff + kube probe

Needs scenario **07-dependencies** (payments `orders` → platform `cache`).

```bash
make break SCENARIO=07-dependencies
make verify

# One-shot assert (preferred): synthetic handoff + --probe-kube merge
make coordinator-e2e
```

Manual two-terminal path:

```bash
# Terminal A — Coordinator with read-only probe (mutate=off)
kprompt agent coordinator --addr :9090 --probe-kube

# Terminal B — ns agent
kprompt agent run -n payments \
  --analyze --heuristic --fetch-logs --memory \
  --coordinator-url http://127.0.0.1:9090/v1/handoff \
  --duration 45s
```

Handoff fires when report summary/Unknowns mention `cache.platform.svc` / namespace platform.
Inspect:

```bash
curl -s http://127.0.0.1:9090/v1/recent | python3 -m json.tool | head -40
```

| Expect | Why |
|--------|-----|
| `CoordinatorReply` with `mutateAttempted: false` | AG-037 / ADR-0017 |
| `routing` contains `probed namespace platform` | AG-050 KubeProbe |
| `merged.evidence` non-empty | platform CrashLoop pods/events |
| `suspectNamespace: platform` | AG-048 extraction / envelope |
| Slack bot thread follow-up (optional) | AG-053 `FormatReply` when `--slack` + coordinator-url |

## Full NA-ish one-liner

```bash
kprompt agent run -n payments \
  --analyze --health --heuristic --fetch-logs \
  --memory --patterns \
  --duration 60s
```

## What this demo does **not** show

- Silent Autopilot apply
- ClusterRole namespace agents
- Coordinator workload mutate (service is receive/merge only)
- Invented Prometheus/OTel numbers

See [agent-ops.md](https://github.com/kprompt/kprompt/blob/main/docs/agent-ops.md) for RBAC/cost runbook.
