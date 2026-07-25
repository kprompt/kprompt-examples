#!/usr/bin/env bash
# Sellable one-shot walkthrough:
#   make up → break-all → verify → agent-full
#
# Heuristic mode — no LLM key. Stops after DEMO_SECONDS (default 45) so it is
# safe to paste into a live demo or record with asciinema.
set -euo pipefail

CLUSTER="${CLUSTER:-kprompt-demo}"
NS="${NS:-payments}"
DEMO_SECONDS="${DEMO_SECONDS:-45}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT"

# Prefer a kprompt that actually has `agent` (v0.5+). PATH may still point at
# an older Homebrew install.
# shellcheck source=resolve-kprompt.sh
source "$ROOT/scripts/resolve-kprompt.sh"
export KPROMPT
echo "==> using $KPROMPT ($("$KPROMPT" version 2>/dev/null || echo unknown))"

make doctor CLUSTER="$CLUSTER" NS="$NS" KPROMPT="$KPROMPT"
make up CLUSTER="$CLUSTER" NS="$NS"
make break-all NS="$NS"
make verify NS="$NS"
make status NS="$NS"

echo
echo "==> Observe agent for ${DEMO_SECONDS}s (Ctrl-C to stop early)"
echo "    $KPROMPT agent run -n $NS --watch pods,events,deployments,replicasets,jobs,cronjobs,pvc \\"
echo "      --analyze --fetch-logs --health --heuristic --memory --patterns --autopilot-propose"
echo

set +e
make agent-full NS="$NS" KPROMPT="$KPROMPT" &
pid=$!
(
  sleep "$DEMO_SECONDS"
  kill "$pid" 2>/dev/null
) &
waiter=$!
wait "$pid" 2>/dev/null
status=$?
kill "$waiter" 2>/dev/null
wait "$waiter" 2>/dev/null
set -e

echo
echo "==> walkthrough done (agent exit=$status)"
echo "    keep watching:  make agent-full NS=$NS KPROMPT=$KPROMPT"
echo "    tear down:      make down CLUSTER=$CLUSTER"
