#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REMOTE_GPU_REPO_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp}"
QUEUE_ROOT="${REMOTE_GPU_QUEUE_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/remote-gpu-queue}"
INTERVAL="${REMOTE_GPU_BRIDGE_INTERVAL:-15}"

exec python automation/online_bridge.py \
  --repo "$REPO_ROOT" \
  --offline-root "$QUEUE_ROOT" \
  --interval "$INTERVAL"