# 03 · OOMKilled

`cache` allocates ~200 MiB while its container limit is 32 MiB, so the kernel OOM
killer terminates it. The Pod restarts and terminates again, giving you
`lastState.terminated.reason: OOMKilled` and a restart loop.

## What the agent should do

| Stage | Expected |
|-------|----------|
| Correlate | One Incident bucketed as an OOM (not lumped in with plain crashloops) |
| Analyze | Root cause names the memory limit, recommendation is raise limit / reduce footprint |
| Patterns | Run twice with `--patterns` — the second run should say **Seen before** and raise confidence |
| Health | Score drops |

## Run

```bash
make break SCENARIO=03-oom
kprompt agent run -n payments --analyze --health --heuristic --patterns
make fix SCENARIO=03-oom
```

## Notes

`OOMKilled` shows up in the Pod status rather than as a dedicated Event, which is why
this scenario is a good check that the watcher reads container state and not just
Events.
