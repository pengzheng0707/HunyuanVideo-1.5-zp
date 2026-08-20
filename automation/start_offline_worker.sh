#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REMOTE_GPU_REPO_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp}"
QUEUE_ROOT="${REMOTE_GPU_QUEUE_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/remote-gpu-queue}"
INTERVAL="${REMOTE_GPU_WORKER_INTERVAL:-1}"
TIMEOUT="${REMOTE_GPU_TASK_TIMEOUT:-3600}"
IDLE_TIMEOUT="${REMOTE_GPU_IDLE_TIMEOUT:-180}"
LOG_DIR="$QUEUE_ROOT/status/logs"
mkdir -p "$LOG_DIR"

nohup python -u "$REPO_ROOT/automation/offline_worker.py" \
  --root "$QUEUE_ROOT" \
  --interval "$INTERVAL" \
  --timeout "$TIMEOUT" \
  --idle-timeout "$IDLE_TIMEOUT" \
  >> "$LOG_DIR/offline_worker.log" 2>&1 < /dev/null &
printf 'offline worker started in background, pid=%s\n' "$!"