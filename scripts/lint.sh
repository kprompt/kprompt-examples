#!/usr/bin/env bash
# Validate scenario manifests against a live API server.
#
# kubectl needs a reachable server to resolve REST mappings, so --dry-run=client
# is not usable offline here. Run `make up` first, or let CI's kind cluster do it.
#
# Two kinds of file are skipped on purpose, because neither is a complete
# manifest: agent/values-agent.yaml (Helm values) and *.patch.yaml (strategic
# merge patches applied on top of an existing object).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NS="${NS:-payments}"

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "no reachable cluster — run 'make up' first" >&2
  exit 1
fi

# Scenario manifests hardcode metadata.namespace, so server dry-run needs the
# namespace to already exist.
if ! kubectl get namespace "$NS" >/dev/null 2>&1; then
  echo "namespace $NS missing — run 'make base' first" >&2
  exit 1
fi

files=()
while IFS= read -r f; do
  files+=("$f")
done < <(find base scenarios -name '*.yaml' ! -name '*.patch.yaml' | sort)

# The KpromptAgent CR only validates once the product CRD is installed.
if kubectl get crd kpromptagents.kprompt.ai >/dev/null 2>&1; then
  files+=("agent/kpromptagent.yaml")
else
  echo "note: skipping agent/kpromptagent.yaml (KpromptAgent CRD not installed)"
fi

fail=0
for f in "${files[@]}"; do
  if out="$(kubectl apply --dry-run=server -f "$f" 2>&1)"; then
    echo "ok   $f"
  else
    echo "FAIL $f"
    echo "$out" | awk '{ print "     " $0 }'
    fail=1
  fi
done

exit "$fail"
