#!/usr/bin/env bash
# One-shot demo: cluster up, break everything, run the Observe agent.
# Heuristic mode, so no LLM API key is required.
set -euo pipefail

CLUSTER="${CLUSTER:-kprompt-demo}"
NS="${NS:-payments}"
SCENARIO="${SCENARIO:-01-crashloop}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT"

make doctor
make up CLUSTER="$CLUSTER" NS="$NS"
make break NS="$NS" SCENARIO="$SCENARIO"

echo "==> waiting 30s for the workload to actually fail"
sleep 30

make status NS="$NS"

echo
echo "==> starting Observe agent (Ctrl-C to stop)"
make agent NS="$NS"
