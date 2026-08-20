#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${REMOTE_GPU_REPO_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp}"
cd "$PROJECT_ROOT"

printf '%s\n' '=== timestamp ==='
date -Is 2>/dev/null || date
printf '%s\n' '=== filesystem ==='
df -h . 2>&1
printf '%s\n' '=== project top-level usage ==='
du -xhd1 "$PROJECT_ROOT" 2>&1 | sort -h
printf '%s\n' '=== largest files under project (top 50) ==='
find "$PROJECT_ROOT" -xdev -type f -printf '%s\t%p\n' 2>/dev/null | sort -nr | head -50 | awk -F '\t' '{ printf "%.2f GiB\t%s\n", $1 / 1073741824, $2 }'
printf '%s\n' '=== shared filesystem top-level usage ==='
du -xhd1 /inspire/hdd/global_user/zhengpeng-240108120124 2>&1 | sort -h | tail -50