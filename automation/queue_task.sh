#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s path/to/task.sh-or-task.py\n' "$0" >&2
  exit 2
fi

REPO_ROOT="${REMOTE_GPU_REPO_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp}"
cd "$REPO_ROOT"
COMMIT="$(git rev-parse HEAD)"
TASK_ID="$(python automation/submit_task.py --script "$1" --commit "$COMMIT")"

git add "automation/tasks/pending/$TASK_ID"
git commit -m "chore: queue remote GPU task $TASK_ID"
git push
printf 'Queued and pushed task: %s\n' "$TASK_ID"