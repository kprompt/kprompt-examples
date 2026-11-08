#!/usr/bin/env bash
# Record the canonical IC-001 magic-moment loop for README / site hero GIF.
#
# Produces:
#   dist/kprompt-magic-moment.cast
#   dist/kprompt-magic-moment.gif   (if `agg` is installed)
#
# Usage:
#   make record-magic-moment              # prepare kind + record
#   SKIP_UP=1 make record-magic-moment    # reuse already-broken cluster
#   DEMO_SECONDS=25 make record-magic-moment
#
# Requires: asciinema. Optional: agg.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CLUSTER="${CLUSTER:-kprompt-demo}"
NS="${NS:-payments}"
DEMO_SECONDS="${DEMO_SECONDS:-28}"
SKIP_UP="${SKIP_UP:-0}"
OUT_DIR="${OUT_DIR:-$ROOT/dist}"
CAST="$OUT_DIR/kprompt-magic-moment.cast"
GIF="$OUT_DIR/kprompt-magic-moment.gif"
COLS="${COLS:-100}"
ROWS="${ROWS:-28}"

if ! command -v asciinema >/dev/null 2>&1; then
  echo "MISS asciinema — install with:  brew install asciinema" >&2
  exit 1
fi

# shellcheck disable=SC1091
source "$ROOT/scripts/resolve-kprompt.sh"
if ! _resolve_kprompt_magic; then
  echo "MISS kprompt with durable proposals (need v0.12.4+)" >&2
  exit 1
fi
export KPROMPT

mkdir -p "$OUT_DIR"

if [[ "$SKIP_UP" != "1" ]]; then
  echo "==> preparing cluster for magic-moment recording"
  make doctor CLUSTER="$CLUSTER" NS="$NS" KPROMPT="$KPROMPT"
  make up CLUSTER="$CLUSTER" NS="$NS"
  make fix-all NS="$NS" >/dev/null 2>&1 || true
  make break SCENARIO=04-failed-rollout NS="$NS"
  make verify NS="$NS"
else
  echo "==> SKIP_UP=1 — recording against current cluster"
fi

echo
echo "==> recording magic-moment (DEMO_SECONDS=$DEMO_SECONDS) → $CAST"

rec_cmd=(asciinema rec --overwrite --cols "$COLS" --rows "$ROWS"
  --title "kprompt magic moment — Observe → proposal → approve → Learn (heuristic, \$0)"
  --command "env KPROMPT='$KPROMPT' CLUSTER='$CLUSTER' NS='$NS' DEMO_SECONDS='$DEMO_SECONDS' MAGIC_MOMENT_APPROVE=1 SKIP_UP=1 bash -lc '
    set -euo pipefail
    echo \"\$ make magic-moment   # failed rollout → PlanResult → y → Learn\"
    echo
    make -C \"$ROOT\" magic-moment \\
      KPROMPT=\"$KPROMPT\" CLUSTER=\"$CLUSTER\" NS=\"$NS\" \\
      DEMO_SECONDS=\"$DEMO_SECONDS\" MAGIC_MOMENT_APPROVE=1 SKIP_UP=1
  '"
  "$CAST")

"${rec_cmd[@]}"

echo
echo "==> cast ready: $CAST"
echo "    play:  asciinema play $CAST"

if command -v agg >/dev/null 2>&1; then
  echo "==> rendering GIF with agg → $GIF"
  agg --cols "$COLS" --rows "$ROWS" --font-size 15 --speed 1.35 "$CAST" "$GIF"
  echo "    gif:   $GIF ($(du -h "$GIF" | awk '{print $1}'))"
else
  echo "==> skip GIF (install agg: cargo install --git https://github.com/asciinema/agg)"
fi

echo
echo "Publish:"
echo "  cp $GIF ../kprompt/.github/assets/kprompt-magic-moment.gif"
echo "  # website optional: public/social/kprompt-magic-moment.gif"
echo "  Tear down: make down CLUSTER=$CLUSTER"
