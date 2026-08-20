#!/usr/bin/env bash
set -euo pipefail

QUEUE_ROOT="${REMOTE_GPU_QUEUE_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/remote-gpu-queue}"
exec python automation/status.py show --root "$QUEUE_ROOT"