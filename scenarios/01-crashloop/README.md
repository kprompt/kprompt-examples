# 01 · CrashLoopBackOff

The `api` container starts, logs a bit, then exits `1`. Kubernetes restarts it with
increasing backoff, so you get a steady stream of `BackOff` / `Failed` Events plus a
Pod stuck in `CrashLoopBackOff`.

## What the agent should do

| Stage | Expected |
|-------|----------|
| Watch | Pod + Event stream for `api-*` |
| Correlate | One Incident grouping the restarts (not one alert per restart) |
| Logs | `--fetch-logs` picks up `boom` from the previous container |
| Analyze | Root cause points at the failing start command / exit code 1 |
| Health | Score drops; trend goes down |

## Run

```bash
make break SCENARIO=01-crashloop
kprompt agent run -n payments --analyze --health --heuristic --fetch-logs
make fix SCENARIO=01-crashloop
```

## Notes

`restartPolicy` stays `Always` (the Deployment default) — that is what produces the
loop. The log line before the exit exists on purpose so `--fetch-logs` has something
to quote in the analysis.
