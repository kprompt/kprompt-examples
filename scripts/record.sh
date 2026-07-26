#!/usr/bin/env bash
# Record a shareable Observe-agent walkthrough.
#
# Produces:
#   dist/kprompt-observe-demo.cast   (asciinema)
#   dist/kprompt-observe-demo.gif    (if `agg` is installed)
#
# Usage:
#   make record                 # DEMO_SECONDS=60
#   DEMO_SECONDS=45 make record
#   make record SKIP_UP=1       # reuse an already-broken kind cluster
#
# Requires: asciinema. Optional: agg (https://github.com/asciinema/agg).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CLUSTER="${CLUSTER:-kprompt-demo}"
NS="${NS:-payments}"
DEMO_SECONDS="${DEMO_SECONDS:-60}"
SKIP_UP="${SKIP_UP:-0}"
OUT_DIR="${OUT_DIR:-$ROOT/dist}"
CAST="$OUT_DIR/kprompt-observe-demo.cast"
GIF="$OUT_DIR/kprompt-observe-demo.gif"
COLS="${COLS:-110}"
ROWS="${ROWS:-32}"

if ! command -v asciinema >/dev/null 2>&1; then
	echo "MISS asciinema — install with:  brew install asciinema"
	exit 1
fi

# shellcheck disable=SC1091
source "$ROOT/scripts/resolve-kprompt.sh"
export KPROMPT CLUSTER NS DEMO_SECONDS
mkdir -p "$OUT_DIR"

if [[ "$SKIP_UP" != "1" ]]; then
	echo "==> preparing cluster (kind + break-all + verify)"
	make doctor CLUSTER="$CLUSTER" NS="$NS" KPROMPT="$KPROMPT"
	make up CLUSTER="$CLUSTER" NS="$NS"
	make break-all NS="$NS"
	make verify NS="$NS"
	make status NS="$NS"
else
	echo "==> SKIP_UP=1 — recording against the current cluster"
fi

echo
echo "==> recording ${DEMO_SECONDS}s agent run → $CAST"
echo "    cols=${COLS} rows=${ROWS}"
echo

# Record only the agent portion so the GIF stays short and readable.
# Prefer --overwrite so re-runs do not fail on an existing cast.
rec_cmd=(asciinema rec --overwrite --cols "$COLS" --rows "$ROWS"
	--title "kprompt Observe agent — kind walkthrough (heuristic, no API key)"
	--command "env KPROMPT='$KPROMPT' NS='$NS' DEMO_SECONDS='$DEMO_SECONDS' bash -lc '
		set -euo pipefail
		echo \"\$ kprompt agent run -n $NS --analyze --fetch-logs --health --heuristic --memory --patterns --autopilot-propose\"
		echo
		\"$KPROMPT\" agent run -n \"$NS\" \\
			--watch pods,events,deployments,replicasets,jobs,cronjobs,pvc \\
			--analyze --fetch-logs --health --heuristic \\
			--memory --patterns --autopilot-propose &
		pid=\$!
		sleep \"$DEMO_SECONDS\"
		kill \"\$pid\" 2>/dev/null || true
		wait \"\$pid\" 2>/dev/null || true
		echo
		echo \"# done — zero LLM spend, propose-only Autopilot\"
		echo \"# try: git clone https://github.com/kprompt/kprompt-examples && make walkthrough\"
	'"
	"$CAST")

"${rec_cmd[@]}"

echo
echo "==> cast ready: $CAST"
echo "    play:  asciinema play $CAST"
echo "    upload (optional): asciinema upload $CAST"

if command -v agg >/dev/null 2>&1; then
	echo "==> rendering GIF with agg → $GIF"
	agg --cols "$COLS" --rows "$ROWS" --font-size 16 --speed 1.2 "$CAST" "$GIF"
	echo "    gif:   $GIF ($(du -h "$GIF" | awk '{print $1}'))"
else
	echo "==> skip GIF (install agg: cargo install --git https://github.com/asciinema/agg)"
	echo "    or:    brew install agg   # if available on your tap"
fi

echo
echo "Share tips:"
echo "  - Drop the GIF on X / LinkedIn / Reddit with the Show HN draft."
echo "  - Embed the .cast on the site or README via asciinema.org after upload."
echo "  - Tear down when done:  make down CLUSTER=$CLUSTER"
