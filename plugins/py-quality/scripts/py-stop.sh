#!/usr/bin/env bash
# Stop hook: before Claude finishes, run tests, check coverage of the
# uncommitted changes, and flag newly added suppression comments. Only runs if
# .py files changed.
set -uo pipefail

input=$(cat)
# Avoid infinite loops: if we already blocked once this turn, let Claude stop.
[[ "$(jq -r '.stop_hook_active // false' <<<"$input")" == "true" ]] && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[[ -f .claude/no-py-gate ]] && exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
[[ -z "$(git status --porcelain -- '*.py')" ]] && exit 0

MIN_DIFF_COV="${PY_GATE_MIN_DIFF_COVERAGE:-80}"
EMPTY_TREE=4b825dc642cb6eb9a060e54bf8d69288fbee4904
git_dir=$(git rev-parse --absolute-git-dir)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Snapshot the working tree below the project dir (tracked, staged and
# untracked files, respecting .gitignore) as a tree object, using a scratch
# copy of the index so the real one is untouched. Every check below compares
# this snapshot against HEAD, or against the empty tree before the first commit.
[[ -f "$git_dir/index" ]] && cp "$git_dir/index" "$work/index"
GIT_INDEX_FILE="$work/index" git add -A -- . 2>/dev/null
snapshot=$(GIT_INDEX_FILE="$work/index" git write-tree) || exit 0
head=$(git rev-parse --verify --quiet HEAD)
base="${head:-$EMPTY_TREE}"
diff=(git diff --no-color --no-ext-diff --no-textconv "$base" "$snapshot")

# Pick the test runner from the project's own environment.
has_tests=0
[[ -d tests || -d test ]] && has_tests=1
grep -qs '\[tool.pytest' pyproject.toml && has_tests=1
[[ -f pytest.ini ]] && has_tests=1
pytest_cmd=()
if [[ $has_tests == 1 ]]; then
  if [[ -f uv.lock ]]; then
    pytest_cmd=(uv run --with pytest --with pytest-cov python -m pytest)
  elif [[ -x .venv/bin/python ]]; then
    pytest_cmd=(.venv/bin/python -m pytest)
  fi
fi

# Skip the gate when nothing that decides its result changed since it last ran
# for this project dir: the snapshot, HEAD, the threshold and the runner. A
# failure is reported once; re-running it unchanged only repeats it.
stamp_dir="$git_dir/py-gate"
stamp="$stamp_dir/$(printf '%s' "$PWD" | git hash-object --stdin)"
fingerprint=$(printf '%s\n' "$snapshot" "$head" "$MIN_DIFF_COV" "${pytest_cmd[*]:-}" | git hash-object --stdin)
[[ -f "$stamp" && "$(<"$stamp")" == "$fingerprint" ]] && exit 0

problems=""

# 1) Suppressions / test gaming added since HEAD
added=$("${diff[@]}" -U0 -- '*.py' | grep -E '^\+[^+].*(# *type: *ignore|# *noqa|pragma: *no cover|pytest\.mark\.skip|@skip)' || true)
if [[ -n "$added" ]]; then
  problems+=$'\n## New suppressions/skips (justify or remove)\n'"$added"$'\n'
fi
deleted_tests=$("${diff[@]}" --name-only --diff-filter=D -- 'test*/**' '*test_*.py' '*_test.py' || true)
if [[ -n "$deleted_tests" ]]; then
  problems+=$'\n## Deleted test files (needs explicit user approval)\n'"$deleted_tests"$'\n'
fi

# Unused imports and undefined names, which the per-edit check lets through
# while an edit is unfinished, on the lines changed since HEAD.
changed_py=()
IFS=$'\n' read -r -d '' -a changed_py < <("${diff[@]}" --relative --name-only --diff-filter=d -- '*.py')
if (( ${#changed_py[@]} )); then
  ruff=(ruff)
  command -v ruff >/dev/null 2>&1 || ruff=(uvx ruff)
  unfinished=$("${ruff[@]}" check --quiet --output-format concise --select F401,F821 -- "${changed_py[@]}" 2>&1 \
    | "$(dirname "${BASH_SOURCE[0]}")/changed_findings.py")
  if [[ -n "$unfinished" ]]; then
    problems+=$'\n## Unused imports or undefined names\n'"$unfinished"$'\n'
  fi
fi

# 2) Tests + branch coverage. Coverage data, bytecode and the pytest cache stay
# out of the project, so its files (including a coverage.xml of its own) are
# untouched and the next snapshot only differs if the project itself changed.
if (( ${#pytest_cmd[@]} )); then
  cov_xml="$work/coverage.xml"
  if ! out=$(COVERAGE_FILE="$work/.coverage" PYTHONDONTWRITEBYTECODE=1 \
             "${pytest_cmd[@]}" -q -x -p no:cacheprovider \
             --cov --cov-branch --cov-report="xml:$cov_xml" 2>&1); then
    problems+=$'\n## Tests failing\n'"$(tail -n 50 <<<"$out")"$'\n'
  elif [[ -f "$cov_xml" && -n "$head" ]]; then
    if ! out=$(uvx diff-cover "$cov_xml" --compare-branch=HEAD \
               --include-untracked --fail-under="$MIN_DIFF_COV" 2>&1); then
      problems+=$'\n## Coverage of changed lines below '"$MIN_DIFF_COV"$'%\n'"$(tail -n 30 <<<"$out")"$'\n'
    fi
  fi
fi

# Only remember a result when the tests ran, or the project has none.
if [[ $has_tests == 0 ]] || (( ${#pytest_cmd[@]} )); then
  mkdir -p "$stamp_dir"
  echo "$fingerprint" >"$stamp"
fi
if [[ -n "$problems" ]]; then
  echo "Not done yet — the Python quality gate found issues:$problems" >&2
  exit 2
fi
exit 0
