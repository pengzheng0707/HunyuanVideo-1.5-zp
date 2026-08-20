#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

TASK_ID="$(python "$REPO_ROOT/automation/submit_task.py" \
  --script "$REPO_ROOT/automation/examples/smoke.sh" \
  --commit smoke-test \
  --output-dir "$TMP_ROOT/tasks/pending")"
python "$REPO_ROOT/automation/offline_worker.py" --root "$TMP_ROOT" --once

RESULT="$TMP_ROOT/tasks/done/$TASK_ID/result.json"
python - "$RESULT" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as result_file:
    result = json.load(result_file)
assert result["status"] == "done", result
assert result["exit_code"] == 0, result
print(f"smoke test passed: {result['task_id']}")
PY