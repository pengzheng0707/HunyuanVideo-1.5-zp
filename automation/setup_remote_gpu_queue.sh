#!/usr/bin/env bash
set -euo pipefail

QUEUE_ROOT="${REMOTE_GPU_QUEUE_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/remote-gpu-queue}"

mkdir -p "$QUEUE_ROOT/tasks"/{pending,running,done,failed}
printf 'Remote GPU queue is ready: %s\n' "$QUEUE_ROOT"