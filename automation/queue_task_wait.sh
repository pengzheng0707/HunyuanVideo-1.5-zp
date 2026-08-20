#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 4 ]]; then
  printf 'Usage: %s path/to/task.sh-or-task.py [online|offline] [name] [description]\n' "$0" >&2
  exit 2
fi

REPO_ROOT="${REMOTE_GPU_REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
INTERVAL="${REMOTE_GPU_WAIT_INTERVAL:-1}"
cd "$REPO_ROOT"

ZONE="${2:-offline}"
NAME="${3:-}"
DESCRIPTION="${4:-}"
git fetch origin main
git rebase --autostash origin/main
TASK_ARGS=(--script "$1" --commit "$(git rev-parse HEAD)" --zone "$ZONE")
[[ -n "$NAME" ]] && TASK_ARGS+=(--name "$NAME")
[[ -n "$DESCRIPTION" ]] && TASK_ARGS+=(--description "$DESCRIPTION")
TASK_ID="$(python automation/submit_task.py "${TASK_ARGS[@]}")"
git add "automation/tasks/pending/$TASK_ID"
git commit -m "chore: queue remote GPU task $TASK_ID"
git push
printf 'Queued task: %s\nWaiting for remote execution...\n' "$TASK_ID"

while true; do
  if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
    printf 'Local changes detected; automatic pull paused.\n' >&2
  else
    git pull --ff-only >/dev/null
  fi
  if [[ -f "automation/tasks/done/$TASK_ID/result.json" ]]; then
    printf 'Task completed successfully: %s\n' "$TASK_ID"
    cat "automation/tasks/done/$TASK_ID/result.json"
    printf '\nOutput:\n'
    cat "automation/tasks/done/$TASK_ID/stdout.log" 2>/dev/null || true
    exit 0
  fi
  if [[ -f "automation/tasks/failed/$TASK_ID/result.json" ]]; then
    printf 'Task failed: %s\n' "$TASK_ID" >&2
    cat "automation/tasks/failed/$TASK_ID/result.json" >&2
    printf '\nError output:\n' >&2
    cat "automation/tasks/failed/$TASK_ID/stderr.log" 2>/dev/null >&2 || true
    exit 1
  fi
  sleep "$INTERVAL"
done