#!/usr/bin/env bash
# Canonical IC-001 path: one failed rollout, one durable proposal, one explicit
# human approval, post-apply verification, and Learn outcome writeback.
set -euo pipefail

CLUSTER="${CLUSTER:-kprompt-demo}"
NS="${NS:-payments}"
DEMO_SECONDS="${DEMO_SECONDS:-30}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ROOT="${STATE_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/kprompt-magic.XXXXXX")}"
PROPOSALS_DIR="$STATE_ROOT/proposals"
PATTERNS_DIR="$STATE_ROOT/patterns"
POLICY="$ROOT/demo/policy-auto.json"

cd "$ROOT"
source "$ROOT/scripts/resolve-kprompt.sh"
export KPROMPT
if ! _resolve_kprompt_magic; then
  echo "MISS current kprompt with durable agent proposals (need v0.12.2+)" >&2
  echo "  Upgrade: brew upgrade kprompt/tap/kprompt" >&2
  echo "  Or pass a current build: make magic-moment KPROMPT=/path/to/kprompt" >&2
  exit 1
fi
export KPROMPT

echo "==> kprompt magic moment"
echo "    Observe → Reason → Plan → Validate → Approve → Execute → Learn"
echo "    one scenario: failed rollout in namespace $NS"
echo "    binary: $KPROMPT"
echo "    local state: $STATE_ROOT"
echo
echo "    Non-goals: no Secret values · no silent heal · apply stays behind [y/N]"
echo

make doctor CLUSTER="$CLUSTER" NS="$NS" KPROMPT="$KPROMPT"
make up CLUSTER="$CLUSTER" NS="$NS"
make fix-all NS="$NS" >/dev/null 2>&1 || true
make break SCENARIO=04-failed-rollout NS="$NS"
make verify NS="$NS"

echo
echo "==> observe and persist a proposal (${DEMO_SECONDS}s)"
set +e
"$KPROMPT" agent run -n "$NS" \
  --watch pods,events,deployments,replicasets \
  --analyze --health --heuristic --patterns --patterns-dir "$PATTERNS_DIR" \
  --autopilot-propose --autopilot-policy "$POLICY" \
  --proposals-dir "$PROPOSALS_DIR" \
  --duration "${DEMO_SECONDS}s"
agent_status=$?
set -e
if [[ $agent_status -ne 0 ]]; then
  echo "agent exited with status $agent_status" >&2
  exit "$agent_status"
fi

# policyAuto marks allowlisted proposals decision=approved (still applied=false until --approve).
# proposeOnly uses decision=proposed. Either is fine for the human review gate.
proposal_id="$("$KPROMPT" agent proposals list -n "$NS" --proposals-dir "$PROPOSALS_DIR" \
  | awk '$2 == "rollbackFailedRollout" && ($4 == "decision=approved" || $4 == "decision=proposed") && $5 ~ /applied=false/ {print $1}' \
  | tail -1)"
if [[ -z "$proposal_id" ]]; then
  echo "no unapplied rollbackFailedRollout proposal was stored" >&2
  echo "inspect: $KPROMPT agent proposals list -n $NS --proposals-dir $PROPOSALS_DIR" >&2
  exit 1
fi

echo
echo "==> review durable PlanResult-shaped proposal: $proposal_id"
"$KPROMPT" agent proposals show -n "$NS" --id "$proposal_id" --proposals-dir "$PROPOSALS_DIR"
echo
echo "No mutation has happened. The next step uses a narrow policyAuto allowlist."

if [[ ! -t 0 ]]; then
  echo "Non-interactive shell: stopping before approval."
  echo "Review and apply from a TTY:"
  echo "  $KPROMPT agent proposals apply -n $NS --id $proposal_id --proposals-dir $PROPOSALS_DIR --policy $POLICY --patterns --patterns-dir $PATTERNS_DIR --approve"
  exit 0
fi

read -r -p "Apply rollback proposal $proposal_id? [y/N] " answer
if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
  echo "Not applied. Proposal remains at $PROPOSALS_DIR"
  exit 0
fi

echo
echo "==> execute approved proposal, verify, and write Learn outcome"
"$KPROMPT" agent proposals apply -n "$NS" --id "$proposal_id" \
  --proposals-dir "$PROPOSALS_DIR" --policy "$POLICY" --approve --wait \
  --patterns --patterns-dir "$PATTERNS_DIR"

kubectl rollout status -n "$NS" deployment/checkout --timeout=120s
echo
echo "==> Learn evidence"
"$KPROMPT" agent patterns list -n "$NS" --patterns-dir "$PATTERNS_DIR"
echo
echo "Magic moment complete: proposal reviewed, applied, verified, and recorded."
echo "Tear down: make down CLUSTER=$CLUSTER"
