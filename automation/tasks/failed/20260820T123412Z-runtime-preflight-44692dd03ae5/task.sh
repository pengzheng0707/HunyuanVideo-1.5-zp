#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${REMOTE_GPU_REPO_ROOT:-/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp}"
MODEL_PATH="${REMOTE_GPU_MODEL_PATH:-$PROJECT_ROOT/ckpts}"
cd "$PROJECT_ROOT"

printf '%s\n' '=== python and cuda ==='
python --version
python - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda_available:", torch.cuda.is_available())
print("cuda_version:", torch.version.cuda)
print("gpu_count:", torch.cuda.device_count())
if not torch.cuda.is_available():
    raise SystemExit("CUDA is unavailable")
for index in range(torch.cuda.device_count()):
    print(f"gpu_{index}:", torch.cuda.get_device_name(index))
PY

printf '%s\n' '=== imports ==='
python - <<'PY'
import diffusers
import einops
import peft
import transformers
print("imports_ok")
PY

printf '%s\n' '=== checkpoint ==='
if [[ ! -d "$MODEL_PATH" ]]; then
  printf 'checkpoint directory missing: %s\n' "$MODEL_PATH" >&2
  exit 2
fi
du -sh "$MODEL_PATH"
find "$MODEL_PATH" -maxdepth 2 -type f | awk 'NR <= 20'

printf '%s\n' '=== disk ==='
df -h "$PROJECT_ROOT"