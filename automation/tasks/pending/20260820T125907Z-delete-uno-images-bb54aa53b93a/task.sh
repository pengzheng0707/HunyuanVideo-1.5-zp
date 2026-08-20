#!/usr/bin/env bash
set -euo pipefail

TARGET="/inspire/hdd/global_user/zhengpeng-240108120124/uno_zp/UNO/uno-1m/images"
EXPECTED="/inspire/hdd/global_user/zhengpeng-240108120124/uno_zp/UNO/uno-1m/images"

if [[ "$TARGET" != "$EXPECTED" || "$TARGET" != */images ]]; then
  printf 'refusing unsafe delete target: %s\n' "$TARGET" >&2
  exit 2
fi
if [[ ! -d "$TARGET" ]]; then
  printf 'target directory does not exist: %s\n' "$TARGET" >&2
  exit 3
fi

printf '%s\n' '=== before ==='
date -Is 2>/dev/null || date
printf 'target exists: %s\n' "$TARGET"
df -h "$TARGET"

printf 'deleting: %s\n' "$TARGET"
rm -rf -- "$TARGET"

if [[ -e "$TARGET" ]]; then
  printf 'target still exists after delete: %s\n' "$TARGET" >&2
  exit 4
fi

printf '%s\n' '=== after ==='
date -Is 2>/dev/null || date
df -h /inspire/hdd/global_user/zhengpeng-240108120124
printf 'delete completed: %s\n' "$TARGET"