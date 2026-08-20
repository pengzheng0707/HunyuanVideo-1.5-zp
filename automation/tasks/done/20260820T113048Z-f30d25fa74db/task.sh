#!/usr/bin/env bash
set -u

printf '%s\n' '=== timestamp ==='
date -Is 2>/dev/null || date

printf '%s\n' '=== host ==='
hostname 2>/dev/null || true
printf 'working_directory: %s\n' "$PWD"

printf '%s\n' '=== gpu ==='
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=index,name,driver_version,memory.total,memory.used,memory.free,utilization.gpu,temperature.gpu,power.draw --format=csv,noheader,nounits 2>&1 || nvidia-smi 2>&1
else
  printf '%s\n' 'nvidia-smi: unavailable'
fi

printf '%s\n' '=== cpu ==='
if command -v lscpu >/dev/null 2>&1; then
  lscpu 2>&1
else
  printf 'logical_cpus: %s\n' "$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 'unknown')"
fi

printf '%s\n' '=== memory ==='
if command -v free >/dev/null 2>&1; then
  free -h 2>&1
else
  vm_stat 2>&1 || printf '%s\n' 'memory command: unavailable'
fi

printf '%s\n' '=== disk ==='
df -h . 2>&1

printf '%s\n' '=== python ==='
python --version 2>&1 || true
python -c 'import sys; print(sys.executable)' 2>&1 || true