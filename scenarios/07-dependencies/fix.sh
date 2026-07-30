#!/usr/bin/env bash
# Tear down 07-dependencies (payments + platform).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> deleting payments consumer + stubs"
kubectl delete -f "$ROOT/scenarios/07-dependencies/manifests.yaml" --ignore-not-found

echo "==> deleting platform suspect namespace resources"
kubectl delete -f "$ROOT/scenarios/07-dependencies/platform.yaml" --ignore-not-found
