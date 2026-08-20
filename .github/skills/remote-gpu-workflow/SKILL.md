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

Only the online zone accesses Git. The offline GPU zone does not run `git pull` or `git push`; it
reads the repository and queue through the shared filesystem. The online bridge pulls new code and
tasks, then pushes returned results back to Git.

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

For the standard shared environment, the complete reusable entry point is. The optional second
argument selects the execution zone and defaults to `offline`:

```bash
bash automation/queue_task.sh path/to/run.sh offline
bash automation/queue_task.sh path/to/run.sh online
```

`online` tasks run inside the online bridge. `offline` tasks run inside the GPU Worker.

The script must be self-contained or refer only to paths available in the offline checkout. Task execution is intentionally limited to `bash task.sh`, `python task.py`, or `python3 task.py`.

## Run the online bridge

On the networked machine, clone the repository and configure the offline shared path:

```bash
python automation/online_bridge.py \
  --repo /path/to/repository \
  --offline-root /path/to/shared/offline-root \
  --interval 1
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
  --interval 1
```

In the standard environment, initialize once with `bash automation/setup_remote_gpu_queue.sh` and run
`bash automation/start_offline_worker.sh` in the GPU zone. Use `bash automation/start_online_bridge.sh`
in the online zone. Both commands use `nohup`, so closing the terminal does not stop the process.

Do not run `git pull` in the offline zone. After the online bridge has synchronized the repository
and queue, start only the Worker there.

Check status with `bash automation/show_status.sh`. Each service writes a timestamped run file and
`latest.json` under the shared queue's `status/` directory. A stale heartbeat is reported as not running.

On the Mac, run `bash automation/start_mac_sync.sh` to continuously pull results from Git. It skips
pulling while the Mac working tree has local changes, so it does not overwrite active Codex edits.

For a fully automatic one-shot workflow, run `bash automation/queue_task_wait.sh path/to/task.sh`.
It submits the task, polls Git every second, and returns the remote result when execution finishes.

For environment setup, first submit `automation/examples/download_environment_packages.sh online`,
then submit `automation/examples/install_environment_offline.sh offline`. The first task downloads
packages through the online zone into the shared wheelhouse; the second installs without network access.

The worker claims tasks by atomic rename, runs them in an isolated task directory, records stdout/stderr and metadata, and moves the task to `done` or `failed`.

## Operational rules

- Do not edit a task after it is committed. Create a new task for a retry.
- Keep task IDs unique and use the recorded commit SHA to identify the source revision.
- Treat `failed` tasks as durable evidence; inspect logs before retrying.
- Use `--once` for smoke tests and service managers such as `launchd` or `systemd` for continuous operation.
- Do not place credentials, tokens, or unrestricted shell commands in task files.