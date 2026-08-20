#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REMOTE_GPU_REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
QUEUE_ROOT="${REMOTE_GPU_QUEUE_ROOT:-$REPO_ROOT/.remote-gpu-runtime}"
INTERVAL="${REMOTE_GPU_MAC_INTERVAL:-1}"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"

write_status() {
  python "$REPO_ROOT/automation/status.py" write \
    --root "$QUEUE_ROOT" --name mac_sync --run-id "$RUN_ID" \
    --state "$1" --interval "$INTERVAL" --message "${2:-}"
}

trap 'write_status stopped interrupted' EXIT
write_status running

cd "$REPO_ROOT"
while true; do
  if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
    printf '%s mac-sync: local changes exist; skipping pull\n' "$(date -Is)"
  elif git pull --ff-only; then
    printf '%s mac-sync: pull completed\n' "$(date -Is)"
  else
    printf '%s mac-sync: pull failed\n' "$(date -Is)"
  fi
  write_status running
  sleep "$INTERVAL"
done