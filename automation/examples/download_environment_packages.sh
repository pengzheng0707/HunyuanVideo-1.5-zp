#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${REMOTE_GPU_REPO_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp}"
QUEUE_ROOT="${REMOTE_GPU_QUEUE_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/remote-gpu-queue}"
WHEELHOUSE="$QUEUE_ROOT/artifacts/wheelhouse"
mkdir -p "$WHEELHOUSE"
cd "$PROJECT_ROOT"

python -m pip download -r requirements.txt --dest "$WHEELHOUSE"
printf 'Downloaded packages to %s\n' "$WHEELHOUSE"