#!/usr/bin/env bash
set -euo pipefail

QUEUE_ROOT="${REMOTE_GPU_QUEUE_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/remote-gpu-queue}"
INTERVAL="${REMOTE_GPU_WORKER_INTERVAL:-1}"
TIMEOUT="${REMOTE_GPU_TASK_TIMEOUT:-3600}"

exec python automation/offline_worker.py \
  --root "$QUEUE_ROOT" \
  --interval "$INTERVAL" \
  --timeout "$TIMEOUT"