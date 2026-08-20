#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 4 ]]; then
  printf 'Usage: %s path/to/task.sh-or-task.py [online|offline] [name] [description]\n' "$0" >&2
  exit 2
fi

REPO_ROOT="${REMOTE_GPU_REPO_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp}"
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
printf 'Queued and pushed task: %s\n' "$TASK_ID"