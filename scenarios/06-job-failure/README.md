# 06 · Failed Job / CronJob

Two pieces:

- `reconcile-batch` — a Job that always exits `1`, retries up to `backoffLimit: 2`,
  then goes `Failed`.
- `nightly-settlement` — a CronJob firing every minute that fails the same way, so
  failures keep arriving while you watch.

## What the agent should do

| Stage | Expected |
|-------|----------|
| Watch | Needs `--watch pods,events,jobs,cronjobs` for Job conditions |
| Correlate | Repeated CronJob failures collapse into one Incident, not one per minute |
| Analyze | Root cause distinguishes a batch failure from a serving-workload crashloop |
| Patterns | With `--patterns`, the recurring CronJob failure is the clearest "seen before" case |

## Run

```bash
make break SCENARIO=06-job-failure

kprompt agent run -n payments \
  --watch pods,events,jobs,cronjobs \
  --analyze --health --heuristic --fetch-logs --patterns

make fix SCENARIO=06-job-failure
```

## Notes

The CronJob uses `concurrencyPolicy: Forbid` and a short `startingDeadlineSeconds` so
you get a predictable one-failure-per-minute cadence instead of a pile-up. It keeps
firing until you run `make fix` — handy for demoing alert dedup over a few minutes.
