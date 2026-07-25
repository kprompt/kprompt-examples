#!/usr/bin/env bash
# Assert that the scenarios actually reached their intended broken states.
#
# This exists so the repo cannot silently rot: if a base image changes behaviour
# and a "broken" workload quietly starts succeeding, the demo would be showing
# the agent nothing while CI stayed green.
#
# Run after `make break-all` (or after breaking a single scenario — checks are
# skipped for scenarios that are not currently applied).
set -euo pipefail

NS="${NS:-payments}"
TIMEOUT="${TIMEOUT:-240}"

fail=0

# wait_for <description> <predicate-function> [args...]
wait_for() {
  local desc="$1"
  shift
  local deadline=$((SECONDS + TIMEOUT))
  while (( SECONDS < deadline )); do
    if "$@"; then
      echo "ok   $desc"
      return 0
    fi
    sleep 3
  done
  echo "FAIL $desc (not reached within ${TIMEOUT}s)"
  fail=1
}

jp() { # jp <resource> <jsonpath-body>
  kubectl get "$1" -n "$NS" -o "jsonpath={$2}" 2>/dev/null
}

# waiting_reason_matches <app-label> <substring>
waiting_reason_matches() {
  local out
  out="$(kubectl get pods -n "$NS" -l "app=$1" \
    -o 'jsonpath={.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null)"
  [[ "$out" == *"$2"* ]]
}

# terminated_reason_matches <app-label> <substring>
terminated_reason_matches() {
  local out
  out="$(kubectl get pods -n "$NS" -l "app=$1" \
    -o 'jsonpath={.items[*].status.containerStatuses[*].lastState.terminated.reason}' 2>/dev/null)"
  [[ "$out" == *"$2"* ]]
}

# ready_replicas_is <deployment> <count>
ready_replicas_is() {
  [ "$(jp "deploy/$1" .status.readyReplicas)" = "$2" ]
}

pvc_phase_is() {
  [ "$(jp "pvc/$1" .status.phase)" = "$2" ]
}

job_failed() {
  [ "$(jp "job/$1" '.status.conditions[?(@.type=="Failed")].status')" = "True" ]
}

exists() {
  kubectl get "$1" -n "$NS" >/dev/null 2>&1
}

echo "==> baseline"
wait_for "web has 2 ready replicas" ready_replicas_is web 2

if exists deploy/api; then
  echo "==> 01-crashloop"
  wait_for "api pod in CrashLoopBackOff" waiting_reason_matches api CrashLoopBackOff
fi

if exists deploy/worker; then
  echo "==> 02-image-pull"
  wait_for "worker pod cannot pull its image" waiting_reason_matches worker ImagePull
fi

if exists deploy/cache; then
  echo "==> 03-oom"
  wait_for "cache container OOMKilled" terminated_reason_matches cache OOMKilled
fi

if exists deploy/checkout; then
  echo "==> 04-failed-rollout"
  # The bad revision must NOT converge, while revision 1 keeps serving.
  if kubectl rollout status deploy/checkout -n "$NS" --timeout=15s >/dev/null 2>&1; then
    echo "FAIL checkout rollout completed, expected it to stall"
    fail=1
  else
    echo "ok   checkout rollout stalled as expected"
  fi
  wait_for "checkout still serves 2 ready replicas from revision 1" \
    ready_replicas_is checkout 2
fi

if exists pvc/ledger-data; then
  echo "==> 05-pending-pvc"
  wait_for "ledger-data PVC stuck Pending" pvc_phase_is ledger-data Pending
fi

if exists job/reconcile-batch; then
  echo "==> 06-job-failure"
  wait_for "reconcile-batch Job reports Failed" job_failed reconcile-batch
fi

if exists deploy/orders; then
  echo "==> 07-dependencies"
  wait_for "redis Service present for memory discovery" exists svc/redis
  wait_for "postgres Service present for memory discovery" exists svc/postgres
  wait_for "orders pod failing on its cache dependency" \
    waiting_reason_matches orders CrashLoopBackOff
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "some scenarios did not reach their expected broken state:"
  kubectl get pods -n "$NS" -o wide
fi
exit "$fail"
