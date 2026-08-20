#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${REMOTE_GPU_REPO_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp}"
cd "$PROJECT_ROOT"

printf '%s\n' '=== install started ==='
date -Is 2>/dev/null || date
printf 'project_root: %s\n' "$PROJECT_ROOT"
printf 'python: '
python --version 2>&1 || true
printf 'pip: '
python -m pip --version 2>&1 || true

if [[ ! -f requirements.txt ]]; then
  printf '%s\n' 'requirements.txt not found' >&2
  exit 1
fi

python -m pip install -r requirements.txt

printf '%s\n' '=== install completed ==='
date -Is 2>/dev/null || date
python -m pip check
python -m pip freeze | sort