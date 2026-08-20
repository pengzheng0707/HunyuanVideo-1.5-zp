#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REMOTE_GPU_REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DEFAULT_QUEUE="/inspire/hdd/global_user/zhengpeng-240108120124/remote-gpu-queue"
if [[ -n "${REMOTE_GPU_QUEUE_ROOT:-}" ]]; then
	QUEUE_ROOT="$REMOTE_GPU_QUEUE_ROOT"
elif [[ -d "$DEFAULT_QUEUE" ]]; then
	QUEUE_ROOT="$DEFAULT_QUEUE"
else
	QUEUE_ROOT="$REPO_ROOT/.remote-gpu-runtime"
fi
exec python automation/status.py show --root "$QUEUE_ROOT"