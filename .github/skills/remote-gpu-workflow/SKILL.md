---
name: remote-gpu-workflow
description: "Use when coordinating code changes from a networked Mac with an online Git bridge and an offline GPU worker; submit scripts, synchronize tasks and collect execution results."
---

# Remote GPU Workflow

Use the repository automation tools when the current machine can edit and commit code but cannot access the GPU or the Git network directly.

## Architecture

```text
Mac -> git push -> online bridge -> shared filesystem -> offline worker
Mac <- git pull <- online bridge <- shared filesystem <- offline worker
```

Git carries source code, task definitions, and results. The shared filesystem carries task directories between the online bridge and offline worker. Large checkpoints and generated media should stay outside Git.

## Submit a task on the Mac

From the repository root:

```bash
python automation/submit_task.py --script path/to/run.sh --commit HEAD
```

The command creates a task under `automation/tasks/pending/`. Commit and push it:

```bash
git add automation/tasks
git commit -m "chore: queue remote GPU task"
git push
```

For the standard shared environment, the complete reusable entry point is:

```bash
bash automation/queue_task.sh path/to/run.sh
```

The script must be self-contained or refer only to paths available in the offline checkout. Task execution is intentionally limited to `bash task.sh`, `python task.py`, or `python3 task.py`.

## Run the online bridge

On the networked machine, clone the repository and configure the offline shared path:

```bash
python automation/online_bridge.py \
  --repo /path/to/repository \
  --offline-root /path/to/shared/offline-root \
  --interval 15
```

With the shared environment from this repository, run `bash automation/run_online_bridge.sh`. It uses:
`/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp` as the repository and
`/inspire/hdd/global_user/zhengpeng-240108120124/remote-gpu-queue` as the queue.

The bridge uses fast-forward-only pulls, copies pending tasks atomically, imports completed or failed tasks, then commits and pushes results. Keep one bridge process per repository.

## Run the offline worker

On the GPU machine:

```bash
python automation/offline_worker.py \
  --root /path/to/shared/offline-root \
  --interval 5
```

In the standard environment, initialize once with `bash automation/setup_remote_gpu_queue.sh` and run
`bash automation/run_offline_worker.sh` in the GPU zone.

The worker claims tasks by atomic rename, runs them in an isolated task directory, records stdout/stderr and metadata, and moves the task to `done` or `failed`.

## Operational rules

- Do not edit a task after it is committed. Create a new task for a retry.
- Keep task IDs unique and use the recorded commit SHA to identify the source revision.
- Treat `failed` tasks as durable evidence; inspect logs before retrying.
- Use `--once` for smoke tests and service managers such as `launchd` or `systemd` for continuous operation.
- Do not place credentials, tokens, or unrestricted shell commands in task files.