#!/usr/bin/env bash
# SessionStart hook: give Claude the quality rules, but only in Python projects.
set -uo pipefail
cat >/dev/null  # consume stdin
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[[ -f .claude/no-py-gate ]] && exit 0
if [[ -f pyproject.toml || -f setup.py || -f setup.cfg || -f requirements.txt ]] \
   || [[ -n "$(find . -maxdepth 3 -name '*.py' -not -path './.venv/*' -print -quit 2>/dev/null)" ]]; then
  rules="$(sed -n '/^## Python code quality/,$p' "${CLAUDE_PLUGIN_ROOT}/RULES.md")"
  jq -n --arg ctx "$rules" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
fi
exit 0
