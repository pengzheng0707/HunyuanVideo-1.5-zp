#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REMOTE_GPU_REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
QUEUE_ROOT="${REMOTE_GPU_QUEUE_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/remote-gpu-queue}"
LOG_DIR="$QUEUE_ROOT/status/logs"
mkdir -p "$LOG_DIR"

nohup bash "$REPO_ROOT/automation/mac_sync_loop.sh" \
  >> "$LOG_DIR/mac_sync.log" 2>&1 < /dev/null &
printf 'Mac sync started in background, pid=%s\n' "$!"