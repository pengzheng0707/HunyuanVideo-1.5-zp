#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REMOTE_GPU_REPO_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp}"
QUEUE_ROOT="${REMOTE_GPU_QUEUE_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/remote-gpu-queue}"
INTERVAL="${REMOTE_GPU_BRIDGE_INTERVAL:-1}"
LOG_DIR="$QUEUE_ROOT/status/logs"
mkdir -p "$LOG_DIR"

nohup python -u "$REPO_ROOT/automation/online_bridge.py" \
  --repo "$REPO_ROOT" \
  --offline-root "$QUEUE_ROOT" \
  --interval "$INTERVAL" \
  >> "$LOG_DIR/online_bridge.log" 2>&1 < /dev/null &
printf 'online bridge started in background, pid=%s\n' "$!"