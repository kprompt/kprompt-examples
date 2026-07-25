# 02 · ImagePullBackOff

`worker` references an image tag that does not exist in any registry the cluster can
reach. The Pod never starts; kubelet emits `Failed` / `ErrImagePull` /
`ImagePullBackOff` Events.

## What the agent should do

| Stage | Expected |
|-------|----------|
| Correlate | One Incident for the pull failure |
| Logs | Nothing to fetch — the container never ran. The analysis must not claim it read logs |
| Analyze | Root cause names the unresolvable image reference, recommendation is a tag/registry fix |
| Health | Score drops (pod never becomes ready) |

This is the useful counter-case to `01-crashloop`: a good analysis should *not*
hallucinate log evidence when there is none.

## Run

```bash
make break SCENARIO=02-image-pull
kprompt agent run -n payments --analyze --health --heuristic
make fix SCENARIO=02-image-pull
```
