# kprompt-examples

Runnable demo scenarios for [kprompt](https://github.com/kprompt/kprompt) — a local
Kubernetes cluster with deliberately broken workloads, so you can watch the
**Observe agent** correlate incidents, score namespace health, and propose fixes
against real cluster signals instead of a slide deck.

Everything here runs offline in `--heuristic` mode: **$0 — no LLM provider key, no cloud
account.**

## Requirements

| Tool | Why |
|------|-----|
| [Docker](https://docs.docker.com/get-docker/) (or colima/Podman) | runs the kind node |
| [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) | the cluster |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | applying manifests |
| [kprompt](https://kprompt.ai) | the agent under demo |
| `make` | the shortcuts below |

```bash
brew install kind kubectl
curl -fsSL https://kprompt.ai/install | bash   # v0.5+ with `kprompt agent`
make doctor   # kind, kubectl, docker, and a kprompt that has `agent`
```

## Quickstart

One command — kind cluster, every failure scenario, then the Observe agent for ~45s:

```bash
git clone https://github.com/kprompt/kprompt-examples.git
cd kprompt-examples
make walkthrough
```

That is `up → break-all → verify → agent-full`. Needs **kprompt v0.5+** (`agent`
subcommand). `make doctor` finds a usable binary even when Homebrew still shadows
an older `kprompt` on PATH (common: brew 0.3 vs `~/.local/bin` 0.5).

Step by step:

```bash
make up                          # kind cluster + payments namespace + healthy baseline
make break SCENARIO=01-crashloop # break something on purpose
make verify                      # wait until it is actually broken
make status                      # see the damage
make agent                       # heuristic Observe agent (no LLM key)
```

Tear down when you are done:

```bash
make down   # deletes the kind cluster entirely
```

### Record a 60s clip

One command prepares kind (unless `SKIP_UP=1`), records the Observe agent, and optionally renders a GIF:

```bash
brew install asciinema          # required
# optional GIF: cargo install --git https://github.com/asciinema/agg

make record                     # → dist/kprompt-observe-demo.cast (+ .gif if agg is on PATH)
DEMO_SECONDS=45 make record
SKIP_UP=1 make record           # reuse an already-broken cluster
```

Play locally with `asciinema play dist/kprompt-observe-demo.cast`, or upload with `asciinema upload …`.

## Scenarios

Each directory is self-contained: a `manifests.yaml` plus a README explaining what
the agent is expected to conclude.

| Scenario | Failure | Shows off |
|----------|---------|-----------|
| [`01-crashloop`](scenarios/01-crashloop) | container exits 1 in a loop | incident correlation, `--fetch-logs` evidence |
| [`02-image-pull`](scenarios/02-image-pull) | image tag does not exist | analysis with **no** logs available |
| [`03-oom`](scenarios/03-oom) | allocates past its memory limit | OOM bucketing, `--patterns` seen-before |
| [`04-failed-rollout`](scenarios/04-failed-rollout) | revision 2 stalls, revision 1 still serving | `--autopilot-propose` (propose-only) |
| [`05-pending-pvc`](scenarios/05-pending-pvc) | PVC never binds, pod stays Pending | why `--watch pods,events,pvc` matters |
| [`06-job-failure`](scenarios/06-job-failure) | Job + CronJob keep failing | dedup of recurring batch failures |
| [`07-dependencies`](scenarios/07-dependencies) | orders → platform/cache + local redis/postgres stubs | `--memory` + Coordinator probe (`make coordinator-e2e`) |

**Namespace Agent loop** (memory / patterns / priority / handoff client on top of 01–07):
[docs/namespace-agent-loop.md](./docs/namespace-agent-loop.md).

Switch between them:

```bash
make break SCENARIO=05-pending-pvc
make fix   SCENARIO=05-pending-pvc

make break-all   # everything at once, for a genuinely unhealthy namespace
make fix-all
```

`make break-all` is the best way to see the health score move, since the baseline
`web` Deployment stays healthy the whole time and gives the score something to
weigh against.

`make verify` blocks until whatever you applied has genuinely reached its broken
state — a crashloop needs a couple of restart cycles, an OOM needs the container to
allocate first. Running the agent before that just shows you a namespace mid-startup.
CI runs the same check, so a scenario that quietly stops failing (say a base image
changes behaviour) turns the build red instead of silently making the demo boring.

## The full pipeline

```bash
make agent-full
```

which is:

```bash
kprompt agent run -n payments \
  --watch pods,events,deployments,replicasets,jobs,cronjobs,pvc \
  --analyze --fetch-logs --health --heuristic \
  --memory --patterns --autopilot-propose
```

| Flag | What it adds |
|------|--------------|
| `--analyze` | root cause + recommendation per incident, severity/confidence gated |
| `--fetch-logs` | pulls container logs on demand as evidence |
| `--health` | 0–100 namespace health score and trend |
| `--heuristic` | no LLM calls at all — offline and free |
| `--memory` | injects discovered dependency facts into the analysis |
| `--patterns` | boosts confidence on incidents it has seen before |
| `--autopilot-propose` | emits a propose-only remediation plan, never applies it |

## Running the agent in-cluster

The examples above run the agent from your laptop against the kind cluster. To run it
as a Deployment the way you would in production:

```bash
kubectl -n payments create secret generic kprompt-agent \
  --from-literal=OPENAI_API_KEY="$OPENAI_API_KEY"   # skip in heuristic mode

helm upgrade --install kprompt-agent \
  oci://ghcr.io/kprompt/charts/kprompt-agent \
  -n payments -f agent/values-agent.yaml

kubectl apply -f agent/kpromptagent.yaml
kubectl get kpa payments -n payments -o yaml   # status.healthScore / status.lastAlert
```

RBAC is a **Role + RoleBinding in `payments` only** — read verbs, no ClusterRole.

## What this repo will not show you

Being straight about it, since demo repos are where overclaiming happens:

- **No silent remediation.** Autopilot is propose-only in the current MVP
  ([ADR-0015](https://github.com/kprompt/kprompt-architecture/blob/main/decisions/ADR-0015-autopilot-mode.md)).
  `04-failed-rollout` prints a plan; *you* run `kubectl rollout undo`.
- **No mutations from the agent at all.** Observe mode has read verbs only
  ([ADR-0013](https://github.com/kprompt/kprompt-architecture/blob/main/decisions/ADR-0013-in-cluster-agent.md)).
- **Heuristic analysis is not LLM analysis.** It is deterministic and offline, which
  makes it good for demos and CI, but a real LLM run reads differently. Set
  `--heuristic=false` with a provider key to compare.
- **These workloads are toys.** Redis and Postgres in `07-dependencies` are busybox
  stubs (Service name + env for memory discovery), not databases. Never copy them
  into a real cluster.

## Alternatives to kind

Scenarios are plain manifests, so any cluster works:

```bash
# minikube
minikube start -p kprompt-demo
make base && make break SCENARIO=01-crashloop

# k3d
k3d cluster create kprompt-demo
make base && make break SCENARIO=01-crashloop

# Docker Desktop / OrbStack built-in Kubernetes
kubectl config use-context docker-desktop
make base && make break SCENARIO=01-crashloop
```

Only `make up` and `make down` are kind-specific.

## Contributing

New scenarios are welcome. A scenario needs:

1. A directory under `scenarios/` named `NN-short-name`.
2. A `manifests.yaml` scoped to the `payments` namespace, labelled
   `app.kubernetes.io/part-of: kprompt-examples`.
3. A `README.md` stating the failure and **what the agent should conclude** — a
   scenario is only useful if there is a right answer to check against.
4. An optional executable `break.sh` when a single `kubectl apply` cannot express the
   failure (see `04-failed-rollout`).

Keep resource requests tiny; the whole repo should fit on a single-node laptop
cluster. CI applies every scenario to a real kind cluster, so manifests must be
valid.

## Links

- Product: [github.com/kprompt/kprompt](https://github.com/kprompt/kprompt)
- Agent docs: [kprompt.ai/docs/agent](https://kprompt.ai/docs/agent)
- Architecture decisions: [github.com/kprompt/kprompt-architecture](https://github.com/kprompt/kprompt-architecture)

## License

Apache-2.0 — see [LICENSE](LICENSE).
