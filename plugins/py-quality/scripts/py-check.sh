#!/usr/bin/env bash
# PostToolUse hook: fast per-file quality gate after Claude edits a .py file.
# Exit 2 + stderr => findings are fed back to Claude immediately.
set -uo pipefail

input=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<<"$input")

[[ -z "$file" || "$file" != *.py || ! -f "$file" ]] && exit 0

scripts=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Check the file against the project that owns it, which needn't be the
# session's (e.g. another worktree). An inherited VIRTUAL_ENV would make ty
# resolve imports in the session's venv instead of that project's .venv.
unset VIRTUAL_ENV
proj=$(dirname "$file")
until [[ -f "$proj/pyproject.toml" || "$proj" == / ]]; do proj=$(dirname "$proj"); done
[[ "$proj" == / ]] && proj="${CLAUDE_PROJECT_DIR:-$(dirname "$file")}"
[[ -f "$proj/.claude/no-py-gate" ]] && exit 0   # per-project opt-out
cd "$proj" || exit 0

# Use globally installed tool if present, else fall back to uvx.
run() { if command -v "$1" >/dev/null 2>&1; then "$@"; else uvx "$@"; fi; }

# Findings on code this change didn't touch aren't Claude's to fix here, so
# only those on lines changed since HEAD count. A tool that fails to run at
# all (exit 2 and up) is reported as it is.
changed_findings() {
  local out rc
  out=$("$@" 2>&1)
  rc=$?
  if (( rc >= 2 )); then
    printf '%s\n' "$out"
  elif (( rc == 1 )); then
    "$scripts/changed_findings.py" <<<"$out"
  fi
}

MAX_COMPLEXITY="${PY_GATE_MAX_COMPLEXITY:-10}"

# Lint + complexity. Respects the project's ruff config and adds these rules on top:
#   C901 McCabe complexity, PLR09xx too many branches/args/statements/returns,
#   PGH003/PGH004 blanket "type: ignore" / "noqa" (anti metric-gaming).
ruff_findings=$(changed_findings run ruff check --quiet --output-format concise \
  --extend-select C901,PLR0911,PLR0912,PLR0913,PLR0915,PGH003,PGH004 \
  --config "lint.mccabe.max-complexity = $MAX_COMPLEXITY" \
  "$file")

# Type check this file. ty discovers the project's .venv from the cwd.
ty_findings=""
if [[ "${PY_GATE_TYPECHECK:-1}" == "1" ]]; then
  ty_findings=$(changed_findings run ty check --output-format concise "$file")
fi

# An import and its first use usually take two edits, so whichever comes first
# leaves an unused import or an undefined name behind. Those don't block an
# edit; the Stop gate fails if they remain.
unfinished=': (F401|F821|error\[unresolved-reference\]) '
pending=$(grep -hE "$unfinished" <<<"$ruff_findings"$'\n'"$ty_findings")
ruff_findings=$(grep -vE "$unfinished" <<<"$ruff_findings")
ty_findings=$(grep -vE "$unfinished" <<<"$ty_findings")

problems=""
[[ -n "$ruff_findings" ]] && problems+=$'\n## ruff (lint/complexity)\n'"$ruff_findings"
[[ -n "$ty_findings" ]] && problems+=$'\n## ty (types)\n'"$ty_findings"

if [[ -n "$problems" ]]; then
  [[ -n "$pending" ]] && problems+=$'\n## Unused imports or undefined names (fine mid-edit)\n'"$pending"
  echo "Quality gate findings on lines changed in $file. Fix these, don't suppress them:$problems" >&2
  exit 2
fi
if [[ -n "$pending" ]]; then
  jq -n --arg context "Unused imports or undefined names in $file, fine mid-edit; the Stop gate fails if they remain:"$'\n'"$pending" \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $context}}'
fi
exit 0
