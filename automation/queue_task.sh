#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  printf 'Usage: %s path/to/task.sh-or-task.py [online|offline]\n' "$0" >&2
  exit 2
fi

REPO_ROOT="${REMOTE_GPU_REPO_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp}"
cd "$REPO_ROOT"
COMMIT="$(git rev-parse HEAD)"
ZONE="${2:-offline}"
TASK_ID="$(python automation/submit_task.py --script "$1" --commit "$COMMIT" --zone "$ZONE")"

git add "automation/tasks/pending/$TASK_ID"
git commit -m "chore: queue remote GPU task $TASK_ID"
git push
printf 'Queued and pushed task: %s\n' "$TASK_ID"