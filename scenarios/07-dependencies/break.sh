#!/usr/bin/env bash
# Apply 07-dependencies across payments (consumer) + platform (suspect cache).
# kubectl apply -n would rewrite platform objects into payments — avoid that.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NS="${NS:-payments}"

echo "==> ensuring namespace $NS"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl apply -f "$ROOT/base/namespace.yaml"

echo "==> applying platform suspect namespace (cross-ns cache)"
kubectl apply -f "$ROOT/scenarios/07-dependencies/platform.yaml"

echo "==> applying payments consumer + local redis/postgres stubs"
kubectl apply -f "$ROOT/scenarios/07-dependencies/manifests.yaml"
