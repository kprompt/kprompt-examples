#!/usr/bin/env bash
# Kind E2E: 07-dependencies → Coordinator handoff + KubeProbe merge (AG-048…AG-050).
#
# Asserts:
#   1. Coordinator accepts a handoff with suspectNamespace=platform
#   2. --probe-kube merges platform Pod/Event evidence into CoordinatorReply
#   3. mutateAttempted stays false
#   4. Ns agent run with --coordinator-url can surface a handoff line (best-effort)
#
# Usage:
#   make coordinator-e2e
#   KPROMPT=/path/to/kprompt make coordinator-e2e
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="${CLUSTER:-kprompt-demo}"
NS="${NS:-payments}"
COORD_ADDR="${COORD_ADDR:-127.0.0.1:19090}"
COORD_URL="http://${COORD_ADDR}/v1/handoff"
DEMO_SECONDS="${DEMO_SECONDS:-25}"
PRODUCT_BIN="${ROOT}/../kprompt/bin/kprompt"

cd "$ROOT"

resolve_kprompt() {
  if [ -n "${KPROMPT:-}" ] && [ -x "$KPROMPT" ]; then
    return 0
  fi
  # Prefer a freshly built product binary (has --probe-kube).
  if [ -x "$PRODUCT_BIN" ] && "$PRODUCT_BIN" agent coordinator --help 2>&1 | grep -q probe-kube; then
    KPROMPT="$PRODUCT_BIN"
    return 0
  fi
  # shellcheck disable=SC1091
  source "$ROOT/scripts/resolve-kprompt.sh"
  if ! "$KPROMPT" agent coordinator --help 2>&1 | grep -q probe-kube; then
    echo "MISS kprompt with --probe-kube (build sibling: cd ../kprompt && go build -o bin/kprompt ./cmd/kprompt)" >&2
    exit 1
  fi
}

need_python() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "MISS python3 (used to assert CoordinatorReply JSON)" >&2
    exit 1
  fi
}

json_field() {
  # json_field <json> <python-expr-on-obj>
  local raw="$1"
  local expr="$2"
  python3 -c "import json,sys; o=json.loads(sys.argv[1]); print($expr)" "$raw"
}

cleanup() {
  if [ -n "${COORD_PID:-}" ]; then
    kill "$COORD_PID" 2>/dev/null || true
    wait "$COORD_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

resolve_kprompt
need_python
export KPROMPT
echo "==> using $KPROMPT ($("$KPROMPT" version 2>/dev/null || echo unknown))"

make doctor CLUSTER="$CLUSTER" NS="$NS" KPROMPT="$KPROMPT"
make up CLUSTER="$CLUSTER" NS="$NS"
make break SCENARIO=07-dependencies NS="$NS"
make verify NS="$NS"

echo "==> waiting for platform/cache to CrashLoop (probe evidence)"
for _ in $(seq 1 30); do
  if kubectl get pods -n platform -l app=cache -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null | grep -Eq '^[1-9]'; then
    break
  fi
  # Also accept Pending/Running with Ready=False after a few seconds.
  phase="$(kubectl get pods -n platform -l app=cache -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)"
  ready="$(kubectl get pods -n platform -l app=cache -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
  if [ "$phase" = "Running" ] && [ "$ready" = "False" ]; then
    break
  fi
  if [ "$phase" = "Failed" ]; then
    break
  fi
  sleep 2
done
kubectl get pods -n platform -o wide || true

echo "==> starting Coordinator with --probe-kube on $COORD_ADDR"
"$KPROMPT" agent coordinator --addr "$COORD_ADDR" --probe-kube \
  >"/tmp/kprompt-coordinator-e2e.log" 2>&1 &
COORD_PID=$!

for _ in $(seq 1 20); do
  if curl -sf "http://${COORD_ADDR}/healthz" >/dev/null; then
    break
  fi
  sleep 0.25
done
curl -sf "http://${COORD_ADDR}/healthz" >/dev/null

echo "==> POSTing synthetic handoff (suspect=platform)"
handoff_json="$(mktemp)"
cat >"$handoff_json" <<EOF
{
  "apiVersion": "kprompt.io/v1",
  "kind": "CoordinatorHandoff",
  "schemaVersion": "1",
  "fromNamespace": "${NS}",
  "suspectNamespace": "platform",
  "reason": "orders depends on cache.platform.svc.cluster.local — need Coordinator verification",
  "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "report": {
    "apiVersion": "kprompt.io/v1",
    "kind": "InvestigationReport",
    "schemaVersion": "2",
    "namespace": "${NS}",
    "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "summary": "orders CrashLoop: cache.platform.svc.cluster.local connection refused",
    "confidence": 0.75,
    "unknowns": ["state of cache in namespace platform is outside my namespace"],
    "hypotheses": [
      {
        "statement": "cross-namespace cache in platform may be down",
        "confidence": 0.75,
        "primary": true
      }
    ]
  }
}
EOF

reply="$(curl -sf -X POST "$COORD_URL" \
  -H 'Content-Type: application/json' \
  --data-binary @"$handoff_json")"
rm -f "$handoff_json"

echo "$reply" | python3 -c 'import json,sys; o=json.load(sys.stdin); m=o.get("merged") or {}; print("suspect=%s mutate=%s evidence=%d routing=%s summary=%s" % (o.get("suspectNamespace"), o.get("mutateAttempted"), len(m.get("evidence") or []), " | ".join(o.get("routing") or []), m.get("summary")))'

mutate="$(json_field "$reply" 'str(o.get("mutateAttempted")).lower()')"
suspect="$(json_field "$reply" 'o.get("suspectNamespace") or ""')"
routing="$(json_field "$reply" '" | ".join(o.get("routing") or [])')"
evidence_n="$(json_field "$reply" 'len(o.get("merged",{}).get("evidence") or [])')"
merged_sum="$(json_field "$reply" 'o.get("merged",{}).get("summary") or ""')"

fail=0
if [ "$mutate" != "false" ]; then
  echo "FAIL mutateAttempted=$mutate (want false)" >&2
  fail=1
fi
if [ "$suspect" != "platform" ]; then
  echo "FAIL suspectNamespace=$suspect (want platform)" >&2
  fail=1
fi
if ! echo "$routing" | grep -qi 'probed namespace platform'; then
  echo "FAIL routing missing probe note: $routing" >&2
  echo "     coordinator log:" >&2
  tail -n 40 /tmp/kprompt-coordinator-e2e.log >&2 || true
  fail=1
fi
if [ "${evidence_n:-0}" -lt 1 ]; then
  echo "FAIL expected merged evidence from kube probe, got $evidence_n" >&2
  fail=1
fi
if ! echo "$merged_sum" | grep -qi 'platform'; then
  echo "FAIL merged.summary should mention platform: $merged_sum" >&2
  fail=1
fi

echo "==> GET /v1/recent"
recent="$(curl -sf "http://${COORD_ADDR}/v1/recent")"
recent_n="$(json_field "$recent" 'len(o) if isinstance(o, list) else 0')"
if [ "${recent_n:-0}" -lt 1 ]; then
  echo "FAIL /v1/recent empty" >&2
  fail=1
fi
echo "    recent handoffs: $recent_n"

echo "==> ns agent run (${DEMO_SECONDS}s) with --coordinator-url (best-effort handoff line)"
set +e
agent_log="$(mktemp)"
"$KPROMPT" agent run -n "$NS" \
  --analyze --heuristic --fetch-logs --memory \
  --coordinator-url "$COORD_URL" \
  --duration "${DEMO_SECONDS}s" \
  >"$agent_log" 2>&1
set -e
if grep -Eiq 'handoff from=|coordinator handoff' "$agent_log"; then
  echo "ok   agent emitted handoff line"
  grep -Ei 'handoff from=|coordinator handoff' "$agent_log" | tail -n 3
else
  echo "note: agent did not emit handoff within ${DEMO_SECONDS}s (synthetic probe path already asserted)"
  tail -n 15 "$agent_log" || true
fi
rm -f "$agent_log"
# Agent may exit non-zero on duration stop; probe asserts above are authoritative.

if [ "$fail" -ne 0 ]; then
  echo "==> coordinator-e2e FAILED"
  exit 1
fi

echo
echo "==> coordinator-e2e PASSED"
echo "    probe merged evidence=$evidence_n mutateAttempted=false suspect=platform"
echo "    tear down: make fix SCENARIO=07-dependencies && make down"
