#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${REMOTE_GPU_REPO_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp}"
QUEUE_ROOT="${REMOTE_GPU_QUEUE_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/remote-gpu-queue}"
cd "$PROJECT_ROOT"

python -m pip install --no-index \
  --find-links "$QUEUE_ROOT/artifacts/wheelhouse" \
  -r requirements.txt
python -m pip check