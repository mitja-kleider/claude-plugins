#!/usr/bin/env bash
# PostToolUse hook: fast per-file quality gate after Claude edits a .py file.
# Exit 2 + stderr => findings are fed back to Claude immediately.
set -uo pipefail

input=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<<"$input")

[[ -z "$file" || "$file" != *.py || ! -f "$file" ]] && exit 0
proj="${CLAUDE_PROJECT_DIR:-$(dirname "$file")}"
[[ -f "$proj/.claude/no-py-gate" ]] && exit 0   # per-project opt-out
cd "$proj" || exit 0

# Use globally installed tool if present, else fall back to uvx.
run() { if command -v "$1" >/dev/null 2>&1; then "$@"; else uvx "$@"; fi; }

MAX_COMPLEXITY="${PY_GATE_MAX_COMPLEXITY:-10}"
problems=""

# Lint + complexity. Respects the project's ruff config and adds these rules on top:
#   C901 McCabe complexity, PLR09xx too many branches/args/statements/returns,
#   PGH003/PGH004 blanket "type: ignore" / "noqa" (anti metric-gaming).
if ! out=$(run ruff check --quiet --output-format concise \
      --extend-select C901,PLR0911,PLR0912,PLR0913,PLR0915,PGH003,PGH004 \
      --config "lint.mccabe.max-complexity = $MAX_COMPLEXITY" \
      "$file" 2>&1); then
  problems+=$'\n## ruff (lint/complexity)\n'"$out"
fi

# Type check this file. ty discovers the project's .venv for imports.
# Swap for "pyright" or "pyrefly check" if you prefer.
if [[ "${PY_GATE_TYPECHECK:-1}" == "1" ]]; then
  if ! out=$(run ty check "$file" 2>&1); then
    problems+=$'\n## ty (types)\n'"$(tail -n 40 <<<"$out")"
  fi
fi

if [[ -n "$problems" ]]; then
  echo "Quality gate findings for $file — fix these, don't suppress them:$problems" >&2
  exit 2
fi
exit 0
