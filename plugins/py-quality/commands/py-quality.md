---
description: Deep Python quality report — complexity, hotspots, dead code, security, test strength
argument-hint: [path or module to focus on, optional]
---

Produce a prioritized quality report for this Python project (focus: $ARGUMENTS, else the whole repo).
Use `uvx` for tools so nothing is added to the project. Use JSON output where available and
summarize; don't paste raw tool output.

1. **Complexity**: `uvx radon cc -s -j <src>` and `uvx radon mi -j <src>`. List functions rated C or worse.
   Optionally `uvx complexipy <src>` for cognitive complexity.
2. **Hotspots**: count commits per .py file over the last 12 months
   (`git log --since=12.months --format= --name-only -- '*.py'`) and combine with the radon
   scores. Rank files by churn × complexity; these are the highest-risk areas.
3. **Dead code**: `uvx vulture <src> --min-confidence 80`.
4. **Security**: `uvx bandit -r <src> -q -f json` (ignore asserts in tests).
5. **Types**: `uvx ty check` (or the project's configured checker); report error counts per file.
6. **Test strength**: report branch coverage per file. Then, only for the top 1–2 hotspot
   modules and only after asking me, run mutation testing with mutmut
   (`uv run --with mutmut mutmut run`, restricting paths to that module) and list
   surviving mutants as concrete missing test cases.

End with a short table: file, risk (high/med/low), why, and the single most valuable next action.
Do not change any code during this command.
