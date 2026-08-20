#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${REMOTE_GPU_REPO_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp}"
SHARED_ROOT="${REMOTE_GPU_SHARED_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124}"
cd "$PROJECT_ROOT"

printf '%s\n' '=== timestamp ==='
date -Is 2>/dev/null || date
printf '%s\n' '=== filesystem ==='
df -h . 2>&1
printf '%s\n' '=== project top-level usage ==='
du -xhd1 "$PROJECT_ROOT" 2>&1 | sort -h
printf '%s\n' '=== largest files under project (top 50) ==='
du -ah "$PROJECT_ROOT" 2>/dev/null | sort -hr | awk 'NR <= 50'
printf '%s\n' '=== shared filesystem top-level usage ==='
if [[ -d "$SHARED_ROOT" ]]; then
	du -xhd1 "$SHARED_ROOT" 2>&1 | sort -h | tail -50
else
	printf 'shared root unavailable: %s\n' "$SHARED_ROOT"
fi