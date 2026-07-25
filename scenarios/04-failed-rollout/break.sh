#!/usr/bin/env bash
# Two-step break: land a healthy revision 1, then roll out a broken revision 2.
# Applying only the broken spec would look like a failed fresh install, and
# Autopilot would have no prior revision to propose a rollback to.
set -euo pipefail

NS="${NS:-payments}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> applying healthy revision 1"
kubectl apply -n "$NS" -f "$DIR/manifests.yaml"

echo "==> waiting for revision 1 to become available"
kubectl rollout status -n "$NS" deployment/checkout --timeout=120s

echo "==> rolling out broken revision 2 (will stall on purpose)"
kubectl patch -n "$NS" deployment/checkout \
  --type=strategic \
  --patch-file "$DIR/broken.yaml"

echo "==> revision history"
kubectl rollout history -n "$NS" deployment/checkout
echo
echo "Rollout is now stalled. Old pods keep serving (maxUnavailable: 0)."
