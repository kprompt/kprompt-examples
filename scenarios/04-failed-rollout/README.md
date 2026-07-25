# 04 · Failed rollout (Autopilot propose demo)

`checkout` is deployed twice: revision 1 is healthy, revision 2 rolls out a broken
image. `maxUnavailable: 0` means the rollout wedges instead of taking the whole
Deployment down — the classic "bad deploy, old pods still serving" shape.

This is the scenario for the **Autopilot propose-only** path
([ADR-0015](https://github.com/kprompt/kprompt-architecture/blob/main/decisions/ADR-0015-autopilot-mode.md)),
because `rollbackFailedRollout` is the only allowlisted MVP action.

## What the agent should do

| Stage | Expected |
|-------|----------|
| Correlate | Incident tied to the Deployment/ReplicaSet, not just the Pod |
| Analyze | Root cause names the failed revision |
| Autopilot | Emits an `AutopilotProposal` (PlanResult-shaped) for `rollbackFailedRollout` |
| Audit | Proposal appended to `~/.config/kprompt/autopilot/*.jsonl` |
| Applied | **false** — the MVP never applies. Nothing in your cluster changes |

## Run

```bash
make break SCENARIO=04-failed-rollout

kprompt agent run -n payments \
  --watch pods,events,deployments,replicasets \
  --analyze --health --heuristic --autopilot-propose

# The proposal is a suggestion. You roll back, not the agent:
kubectl -n payments rollout undo deployment/checkout

make fix SCENARIO=04-failed-rollout
```

## Notes

Apply the manifest, wait for revision 1 to be ready, then apply the broken patch —
`make break` does both in order. Applying only the broken version would look like a
fresh failed install rather than a failed *rollout*, and Autopilot would have no
prior revision to propose rolling back to.
