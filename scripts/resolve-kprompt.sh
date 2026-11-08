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

# Durable proposal store (RT-007) — required for make magic-moment (IC-001).
# Match parent `agent --help` Short text; `proposals --help` only shows Long.
_kprompt_has_magic_moment() {
  local bin="$1" help
  [ -x "$bin" ] || return 1
  help="$("$bin" agent --help 2>&1)" || return 1
  printf '%s' "$help" | grep -q 'Durable AutopilotProposal store'
}

_kprompt_candidates() {
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
  printf '%s\n' "${candidates[@]}"
}

_resolve_kprompt() {
  local cand
  while IFS= read -r cand; do
    [ -n "$cand" ] || continue
    if _kprompt_has_agent "$cand"; then
      KPROMPT="$cand"
      return 0
    fi
  done < <(_kprompt_candidates)

  echo "MISS kprompt with Observe \`agent\` (need v0.5+)" >&2
  echo "  Install: curl -fsSL https://kprompt.ai/install | bash" >&2
  echo "  Or brew: brew upgrade kprompt/tap/kprompt" >&2
  echo "  Tip: ~/.local/bin may already have a newer build while Homebrew shadows PATH." >&2
  return 1
}

# Prefer a binary that can store/apply proposals; skip older agent-only installs on PATH.
_resolve_kprompt_magic() {
  local cand
  while IFS= read -r cand; do
    [ -n "$cand" ] || continue
    if _kprompt_has_magic_moment "$cand"; then
      KPROMPT="$cand"
      return 0
    fi
  done < <(_kprompt_candidates)
  return 1
}

_resolve_kprompt
