#!/usr/bin/env bash
set -euo pipefail

# Minimal HunyuanVideo-1.5 480p text-to-video setup and smoke inference.
#
# Usage:
#   bash automation/examples/minimal_t2v.sh download  # networked zone
#   bash automation/examples/minimal_t2v.sh infer     # offline GPU zone
#   bash automation/examples/minimal_t2v.sh all       # networked GPU machine
#   bash automation/examples/minimal_t2v.sh auto      # download without CUDA, infer with CUDA

PROJECT_ROOT="${REMOTE_GPU_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
MODEL_PATH="${REMOTE_GPU_MODEL_PATH:-$PROJECT_ROOT/ckpts}"
OUTPUT_PATH="${REMOTE_GPU_OUTPUT_PATH:-$PROJECT_ROOT/outputs/minimal_t2v.mp4}"
PROMPT="${REMOTE_GPU_PROMPT:-A cinematic sunrise over snow-covered mountains, soft golden light, slow camera movement.}"
SEED="${REMOTE_GPU_SEED:-1}"
STEPS="${REMOTE_GPU_INFERENCE_STEPS:-20}"
VIDEO_LENGTH="${REMOTE_GPU_VIDEO_LENGTH:-49}"
DOWNLOAD_WORKERS="${REMOTE_GPU_DOWNLOAD_WORKERS:-2}"
MODE="${1:-auto}"

log() {
  printf '\n[%s] %s\n' "$(date -Is 2>/dev/null || date)" "$*"
}

has_cuda() {
  command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1
}

install_environment() {
  log "Installing/verifying Python dependencies"
  cd "$PROJECT_ROOT"
  python -m pip install -r requirements.txt
  python -m pip check
}

install_download_tools() {
  log "Installing/verifying checkpoint download tools"
  python -m pip install "huggingface_hub[cli,hf_xet]==0.34.0" modelscope
}

download_checkpoints() {
  # Xet range concurrency accelerates a single large checkpoint file, while
  # --max-workers controls concurrency between separate files. Keep both
  # conservative by default because some online-zone containers have tight
  # cgroup memory limits. Callers can override either value.
  export HF_HUB_DISABLE_XET=0
  export HF_HUB_DOWNLOAD_TIMEOUT="${HF_HUB_DOWNLOAD_TIMEOUT:-3600}"
  export HF_XET_NUM_CONCURRENT_RANGE_GETS="${HF_XET_NUM_CONCURRENT_RANGE_GETS:-8}"

  log "Download settings: workers=$DOWNLOAD_WORKERS, Xet ranges=$HF_XET_NUM_CONCURRENT_RANGE_GETS"
  log "Downloading only the base config, VAE, and 480p T2V transformer"
  mkdir -p "$MODEL_PATH/text_encoder"
  python -m huggingface_hub.commands.huggingface_cli download \
    tencent/HunyuanVideo-1.5 \
    --include '*.json' 'vae/*' 'transformer/480p_t2v/*' \
    --local-dir "$MODEL_PATH" \
    --max-workers "$DOWNLOAD_WORKERS"

  log "Downloading Qwen text encoder"
  python -m huggingface_hub.commands.huggingface_cli download \
    Qwen/Qwen2.5-VL-7B-Instruct \
    --local-dir "$MODEL_PATH/text_encoder/llm" \
    --max-workers "$DOWNLOAD_WORKERS"

  log "Downloading ByT5 tokenizer/base model"
  python -m huggingface_hub.commands.huggingface_cli download \
    google/byt5-small \
    --local-dir "$MODEL_PATH/text_encoder/byt5-small" \
    --max-workers "$DOWNLOAD_WORKERS"

  log "Downloading Glyph-SDXL-v2 ByT5 weights"
  modelscope download --model AI-ModelScope/Glyph-SDXL-v2 \
    --local_dir "$MODEL_PATH/text_encoder/Glyph-SDXL-v2"

  log "Checkpoint download complete: $MODEL_PATH"
  du -sh "$MODEL_PATH"
}

check_runtime() {
  log "Checking CUDA, imports, and checkpoints"
  cd "$PROJECT_ROOT"
  python - "$MODEL_PATH" <<'PY'
import sys
from pathlib import Path

import diffusers
import einops
import peft
import torch
import transformers

root = Path(sys.argv[1])
required = [
    root / "transformer" / "480p_t2v",
    root / "vae",
    root / "text_encoder" / "llm",
    root / "text_encoder" / "byt5-small",
    root / "text_encoder" / "Glyph-SDXL-v2",
]
missing = [str(path) for path in required if not path.exists()]
print("torch:", torch.__version__)
print("cuda:", torch.version.cuda)
print("gpu_count:", torch.cuda.device_count())
if not torch.cuda.is_available():
    raise SystemExit("CUDA is unavailable; run the infer stage in the GPU zone")
if missing:
    raise SystemExit("Missing checkpoint paths:\n  " + "\n  ".join(missing))
print("gpu:", torch.cuda.get_device_name(0))
print("runtime_check: OK")
PY
}

run_inference() {
  check_runtime
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True,max_split_size_mb:128}"
  export TOKENIZERS_PARALLELISM="${TOKENIZERS_PARALLELISM:-false}"

  log "Running minimal 480p T2V inference"
  cd "$PROJECT_ROOT"
  torchrun --standalone --nproc_per_node=1 generate.py \
    --prompt "$PROMPT" \
    --image_path none \
    --resolution 480p \
    --aspect_ratio 16:9 \
    --seed "$SEED" \
    --num_inference_steps "$STEPS" \
    --video_length "$VIDEO_LENGTH" \
    --rewrite false \
    --cfg_distilled false \
    --enable_step_distill false \
    --sparse_attn false \
    --use_sageattn false \
    --enable_cache false \
    --sr false \
    --model_path "$MODEL_PATH" \
    --output_path "$OUTPUT_PATH"
  log "Video written to $OUTPUT_PATH"
}

case "$MODE" in
  download)
    install_download_tools
    download_checkpoints
    ;;
  infer)
    install_environment
    run_inference
    ;;
  all)
    install_environment
    download_checkpoints
    run_inference
    ;;
  auto)
    if has_cuda; then
      install_environment
      run_inference
    else
      install_download_tools
      download_checkpoints
      log "No CUDA GPU detected. Run this same script with 'infer' in the offline GPU zone."
    fi
    ;;
  *)
    printf 'Usage: %s [auto|download|infer|all]\n' "$0" >&2
    exit 2
    ;;
esac
