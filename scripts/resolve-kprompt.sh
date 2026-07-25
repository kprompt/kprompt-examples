#!/usr/bin/env bash
# Resolve a kprompt binary that supports Observe `agent` (v0.5+).
# Sets KPROMPT in the caller's environment when sourced.
#
# Order: explicit KPROMPT → PATH hit with agent → common install locations → fail.
#
# Note: older CLIs (e.g. 0.3) still exit 0 for `kprompt agent --help` because
# "agent" is treated as a free-form prompt. We require the Observe Mode blurb.

_kprompt_has_agent() {
  local bin="$1" help
  [ -x "$bin" ] || return 1
  help="$("$bin" agent --help 2>&1)" || return 1
  printf '%s' "$help" | grep -qi 'Observe Mode'
}

_resolve_kprompt() {
  local cand
  local -a candidates=()

  if [ -n "${KPROMPT:-}" ]; then
    candidates+=("$KPROMPT")
  fi
  if command -v kprompt >/dev/null 2>&1; then
    candidates+=("$(command -v kprompt)")
  fi
  candidates+=(
    "$HOME/.local/bin/kprompt"
    /opt/homebrew/bin/kprompt
    /usr/local/bin/kprompt
    /tmp/kprompt-v05
  )

  for cand in "${candidates[@]}"; do
    [ -n "$cand" ] || continue
    if _kprompt_has_agent "$cand"; then
      KPROMPT="$cand"
      return 0
    fi
  done

  echo "MISS kprompt with Observe \`agent\` (need v0.5+)" >&2
  echo "  Install: curl -fsSL https://kprompt.ai/install | bash" >&2
  echo "  Or brew: brew upgrade kprompt/tap/kprompt" >&2
  echo "  Tip: ~/.local/bin may already have 0.5 while Homebrew still shadows it with 0.3." >&2
  return 1
}

_resolve_kprompt
