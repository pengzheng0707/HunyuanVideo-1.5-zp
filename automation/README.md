# Remote GPU Automation

This directory implements a small file-based queue for a Mac, an online Git bridge, and an offline GPU worker.

The online zone is the only zone that accesses Git. The offline zone must not run `git pull` or
`git push`; it uses the same shared filesystem and runs the Worker against files delivered by the
online bridge.

The Mac can run a separate pull loop to retrieve results pushed by the online bridge. It only pulls
when the Mac working tree is clean, so local Codex edits are never overwritten.

## Directory protocol

```text
automation/tasks/{pending,running,done,failed}/<task-id>/
```

Every task contains `task.json` and one executable script named `task.sh` or `task.py`. A task is delivered by Git, copied by the online bridge, claimed by directory rename, and returned with `result.json`, `stdout.log`, and `stderr.log`.

## Quick test

```bash
tmp_root=$(mktemp -d)
python automation/submit_task.py --script automation/examples/smoke.sh --output-dir "$tmp_root/tasks/pending"
python automation/offline_worker.py --root "$tmp_root" --once
find "$tmp_root/tasks" -type f -print
```

The production bridge and worker should use absolute paths and be supervised by `launchd` or `systemd`.

The default polling interval is 1 second. Override it with `REMOTE_GPU_BRIDGE_INTERVAL` or
`REMOTE_GPU_WORKER_INTERVAL` when needed.

## Reusable scripts

The default paths match the shared environment:

```text
REPO_ROOT=/inspire/hdd/global_user/zhengpeng-240108120124/HunyuanVideo-1.5-zp
QUEUE_ROOT=/inspire/hdd/global_user/zhengpeng-240108120124/remote-gpu-queue
```

Initialize the shared queue once:

```bash
bash automation/setup_remote_gpu_queue.sh
```

Run these long-lived processes in their respective zones:

```bash
# Online zone: Git pull/push and task/result synchronization.
bash automation/start_online_bridge.sh

# Offline zone: GPU task execution only; do not run Git commands here.
bash automation/start_offline_worker.sh
```

The `start_*.sh` commands use `nohup`, so closing the page or terminal does not stop them. Logs are
written to `QUEUE_ROOT/status/logs/`. Use the foreground `run_*.sh` commands only for debugging.

View current status from either zone:

```bash
bash automation/show_status.sh
```

Status files are stored in `QUEUE_ROOT/status/`: each service has `latest.json` and one timestamped
JSON file for every run. A stale heartbeat is reported as `NOT RUNNING`.

On the Mac, start the background pull loop from the repository root:

```bash
bash automation/start_mac_sync.sh
```

It checks Git every second by default and writes `QUEUE_ROOT/status/logs/mac_sync.log`. On the Mac,
`QUEUE_ROOT` defaults to `.remote-gpu-runtime/` inside the repository; override it with
`REMOTE_GPU_QUEUE_ROOT` if the shared queue is mounted locally. Override the interval with
`REMOTE_GPU_MAC_INTERVAL`. The status command includes `mac_sync` and reports it as `NOT RUNNING`
when its heartbeat becomes stale.

Queue a task from the Mac after placing a `.sh` or `.py` task script in the repository. The optional
second argument selects the execution zone and defaults to `offline`:

```bash
bash automation/queue_task.sh path/to/task.sh offline
bash automation/queue_task.sh path/to/task.sh online
```

To submit and wait automatically for the remote result, use:

```bash
bash automation/queue_task_wait.sh path/to/task.sh
```

Use the same optional zone argument with `queue_task_wait.sh`. For environment setup across zones:

```bash
# Online zone: download packages into the shared wheelhouse.
bash automation/queue_task_wait.sh automation/examples/download_environment_packages.sh online

# Offline zone: install only from the shared wheelhouse.
bash automation/queue_task_wait.sh automation/examples/install_environment_offline.sh offline
```

This command pushes the task, pulls Git every second, and exits with success or failure when the
Worker result is available. It pauses automatic pulls if you have local edits.

The online bridge maintains `automation/tasks/task_history.jsonl`. Each line records the task ID,
start time, finish time, execution platform (`online` or `offline`), status, and source commit.
This file is available on the compute platform and is also returned to the Mac through Git.

Override paths without editing scripts:

```bash
REMOTE_GPU_REPO_ROOT=/custom/repo \
REMOTE_GPU_QUEUE_ROOT=/custom/queue \
bash automation/run_online_bridge.sh
```

Run the non-persistent validation without creating repository output:

```bash
bash automation/smoke_test.sh
```