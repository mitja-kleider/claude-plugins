#!/usr/bin/env bash
# Stop hook: before Claude finishes, run tests, check coverage of changed lines,
# and flag newly added suppression comments. Only runs if .py files changed.
set -uo pipefail

input=$(cat)
# Avoid infinite loops: if we already blocked once this turn, let Claude stop.
[[ "$(jq -r '.stop_hook_active // false' <<<"$input")" == "true" ]] && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[[ -f .claude/no-py-gate ]] && exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[[ -z "$(git status --porcelain -- '*.py')" ]] && exit 0

MIN_DIFF_COV="${PY_GATE_MIN_DIFF_COVERAGE:-80}"
problems=""

# 1) Suppressions / test gaming added in the working tree vs HEAD
added=$(git diff -U0 HEAD -- '*.py' | grep -E '^\+[^+].*(# *type: *ignore|# *noqa|pragma: *no cover|pytest\.mark\.skip|@skip)' || true)
if [[ -n "$added" ]]; then
  problems+=$'\n## New suppressions/skips (justify or remove)\n'"$added"$'\n'
fi
deleted_tests=$(git diff --name-only --diff-filter=D HEAD -- 'test*/**' '*test_*.py' '*_test.py' || true)
if [[ -n "$deleted_tests" ]]; then
  problems+=$'\n## Deleted test files (needs explicit user approval)\n'"$deleted_tests"$'\n'
fi

# 2) Tests + branch coverage, using the project's own environment
has_tests=0
[[ -d tests || -d test ]] && has_tests=1
grep -qs '\[tool.pytest' pyproject.toml && has_tests=1
[[ -f pytest.ini ]] && has_tests=1

if [[ $has_tests == 1 ]]; then
  if [[ -f uv.lock ]]; then
    pytest_cmd=(uv run --with pytest --with pytest-cov python -m pytest)
  elif [[ -x .venv/bin/python ]]; then
    pytest_cmd=(.venv/bin/python -m pytest)
  else
    pytest_cmd=()
  fi

  if (( ${#pytest_cmd[@]} )); then
    rm -f coverage.xml
    if ! out=$("${pytest_cmd[@]}" -q -x --cov --cov-branch --cov-report=xml 2>&1); then
      problems+=$'\n## Tests failing\n'"$(tail -n 50 <<<"$out")"$'\n'
    elif [[ -f coverage.xml ]]; then
      base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo HEAD)
      if ! out=$(uvx diff-cover coverage.xml --compare-branch="$base" \
                 --include-untracked --fail-under="$MIN_DIFF_COV" 2>&1); then
        problems+=$'\n## Coverage of changed lines below '"$MIN_DIFF_COV"$'%\n'"$(tail -n 30 <<<"$out")"$'\n'
      fi
    fi
  fi
fi

if [[ -n "$problems" ]]; then
  echo "Not done yet — the Python quality gate found issues:$problems" >&2
  exit 2
fi
exit 0
