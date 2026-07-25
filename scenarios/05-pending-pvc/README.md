# 05 · Pending pod (unbound PVC)

`ledger-data` asks for a StorageClass that does not exist, so the PVC stays `Pending`
forever and the `ledger` Pod never gets scheduled. You get `FailedScheduling` Events
plus a Pod stuck in `Pending`.

## What the agent should do

| Stage | Expected |
|-------|----------|
| Watch | Needs `--watch pods,events,pvc` to see the PVC phase, not just the Pod |
| Correlate | Incident links the Pending Pod to the unbound claim |
| Analyze | Root cause names the missing StorageClass, not "the app is slow to start" |
| Health | Score drops (pod never becomes ready) |

This is the scenario where the default `pods,events` watch set gives a *worse*
answer than the expanded one — useful for showing why `--watch` matters.

## Run

```bash
make break SCENARIO=05-pending-pvc

# Compare the two:
kprompt agent run -n payments --analyze --health --heuristic
kprompt agent run -n payments --watch pods,events,pvc --analyze --health --heuristic

make fix SCENARIO=05-pending-pvc
```

## Notes

kind ships a default StorageClass (`standard`) that would bind immediately, so the
claim deliberately names `kprompt-nonexistent-storage` instead.
