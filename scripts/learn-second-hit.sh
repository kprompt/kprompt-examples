#!/usr/bin/env bash
# IC-009 — Second-hit Learn demo: same failed-rollout fingerprint twice in kind.
# Hit 1 records apply_success → patterns. Hit 2 should show Learn bias
# (actionConfidence / learnNote / weight·confirmed) — evidence, not proof.
set -euo pipefail

CLUSTER="${CLUSTER:-kprompt-demo}"
NS="${NS:-payments}"
DEMO_SECONDS="${DEMO_SECONDS:-30}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ROOT="${STATE_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/kprompt-learn2.XXXXXX")}"
PROPOSALS_DIR="$STATE_ROOT/proposals"
PATTERNS_DIR="$STATE_ROOT/patterns"
POLICY="$ROOT/demo/policy-auto.json"
HIT1_JSON="$STATE_ROOT/hit1-proposal.json"
HIT2_JSON="$STATE_ROOT/hit2-proposal.json"

cd "$ROOT"
source "$ROOT/scripts/resolve-kprompt.sh"
export KPROMPT
if ! _resolve_kprompt_magic; then
  echo "MISS current kprompt with durable agent proposals (need v0.12.2+)" >&2
  exit 1
fi

echo "==> kprompt Learn second-hit (IC-009)"
echo "    Same scenario twice: 04-failed-rollout → propose → approve → verify → Learn"
echo "    Then break again and show Learn bias on the second proposal."
echo "    binary: $KPROMPT"
echo "    local state: $STATE_ROOT"
echo
echo "    Honesty: Learn weight / learnNote nudge ranking only."
echo "    MinConfidence still uses raw alert confidence (evidence-not-proof)."
echo "    Non-goals: no Secret values · no silent heal · apply stays behind --approve"
echo

mkdir -p "$PROPOSALS_DIR" "$PATTERNS_DIR"

make doctor CLUSTER="$CLUSTER" NS="$NS" KPROMPT="$KPROMPT"
if [[ "${SKIP_UP:-0}" != "1" ]]; then
  make up CLUSTER="$CLUSTER" NS="$NS"
  make fix-all NS="$NS" >/dev/null 2>&1 || true
fi

# Logs go to stderr; only the proposal id is printed on stdout (for capture).
propose_one() {
  local label="$1"
  make break SCENARIO=04-failed-rollout NS="$NS" >&2
  make verify NS="$NS" >&2

  echo >&2
  echo "==> [$label] observe + propose (${DEMO_SECONDS}s)" >&2
  set +e
  "$KPROMPT" agent run -n "$NS" \
    --watch pods,events,deployments,replicasets \
    --analyze --health --heuristic --patterns --patterns-dir "$PATTERNS_DIR" \
    --autopilot-propose --autopilot-policy "$POLICY" \
    --proposals-dir "$PROPOSALS_DIR" \
    --duration "${DEMO_SECONDS}s" >&2
  local agent_status=$?
  set -e
  if [[ $agent_status -ne 0 ]]; then
    echo "agent exited with status $agent_status" >&2
    exit "$agent_status"
  fi

  local proposal_id
  proposal_id="$("$KPROMPT" agent proposals list -n "$NS" --proposals-dir "$PROPOSALS_DIR" \
    | awk '$2 == "rollbackFailedRollout" && ($4 == "decision=approved" || $4 == "decision=proposed") && $5 ~ /applied=false/ {print $1}' \
    | tail -1)"
  if [[ -z "$proposal_id" ]]; then
    echo "no unapplied rollbackFailedRollout proposal ($label)" >&2
    "$KPROMPT" agent proposals list -n "$NS" --proposals-dir "$PROPOSALS_DIR" >&2 || true
    exit 1
  fi
  printf '%s\n' "$proposal_id"
}

echo "==> HIT 1 — first fingerprint (builds Learn store)"
hit1_id="$(propose_one hit1)"
"$KPROMPT" agent proposals show -n "$NS" --id "$hit1_id" --proposals-dir "$PROPOSALS_DIR" >"$HIT1_JSON"
echo "    proposal: $hit1_id"
python3 - "$HIT1_JSON" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
print("    actionConfidence=%s learnNote=%r" % (p.get("actionConfidence"), p.get("learnNote") or ""))
PY

echo
echo "==> HIT 1 — apply + verify + Learn writeback"
"$KPROMPT" agent proposals apply -n "$NS" --id "$hit1_id" \
  --proposals-dir "$PROPOSALS_DIR" --policy "$POLICY" --approve --wait \
  --patterns --patterns-dir "$PATTERNS_DIR"
kubectl rollout status -n "$NS" deployment/checkout --timeout=120s

echo
echo "==> patterns after hit 1"
"$KPROMPT" agent patterns list -n "$NS" --patterns-dir "$PATTERNS_DIR"

echo
echo "==> HIT 2 — same fingerprint (expect Learn bias note)"
# Fresh proposal files; keep patterns so Learn bias is visible.
rm -rf "$PROPOSALS_DIR"
mkdir -p "$PROPOSALS_DIR"
hit2_id="$(propose_one hit2)"
"$KPROMPT" agent proposals show -n "$NS" --id "$hit2_id" --proposals-dir "$PROPOSALS_DIR" >"$HIT2_JSON"
echo "    proposal: $hit2_id"

echo
echo "==> Compare hit1 → hit2 (visible Learn signals)"
python3 - "$HIT1_JSON" "$HIT2_JSON" <<'PY'
import json,sys
a=json.load(open(sys.argv[1]))
b=json.load(open(sys.argv[2]))
def row(label,p):
    print("%s  action=%s  actionConfidence=%s" % (label, p.get("actionId") or p.get("actionID"), p.get("actionConfidence")))
    note=(p.get("learnNote") or "").strip()
    print("         learnNote: %s" % (note if note else "(empty — first hit often has no prior bias)"))
row("hit1", a)
row("hit2", b)
note2=(b.get("learnNote") or "")
ok = "Learn bias" in note2 or "lastAction" in note2.lower() or "weight=" in note2
print()
if ok:
    print("PASS visible Learn bias on second hit (evidence-not-proof — does not skip Safety).")
else:
    print("WARN second-hit learnNote empty — check patterns list / signature match; still not a silent heal.")
    sys.exit(2)
PY

echo
echo "==> patterns after hit 2 (propose only — apply optional)"
"$KPROMPT" agent patterns list -n "$NS" --patterns-dir "$PATTERNS_DIR"
echo
echo "Second-hit demo complete. Artifacts: $STATE_ROOT"
echo "Optional apply hit2: $KPROMPT agent proposals apply -n $NS --id $hit2_id --proposals-dir $PROPOSALS_DIR --policy $POLICY --patterns --patterns-dir $PATTERNS_DIR --approve --wait"
echo "Tear down: make down CLUSTER=$CLUSTER"
