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

Each task has a total timeout of 3600 seconds and an output-idle timeout of 180 seconds. If neither
stdout nor stderr changes for 180 seconds, the executor kills the task process group and records a
failed result. Override this with `REMOTE_GPU_IDLE_TIMEOUT` when a task is expected to be silent.

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

After each pull, Mac sync scans new `done` and `failed` results. It sends a macOS notification and
terminal alert once per task, then records a marker under `QUEUE_ROOT/notified-tasks/`. Notification
history is local runtime state and is not committed to Git.

Queue a task from the Mac after placing a `.sh` or `.py` task script in the repository. The optional
second argument selects the execution zone and defaults to `offline`:

```bash
bash automation/queue_task.sh path/to/task.sh offline
bash automation/queue_task.sh path/to/task.sh online
bash automation/queue_task.sh path/to/task.sh offline inference "Run Hunyuan inference on the GPU"
```

The optional third and fourth arguments are a short task name and a human-readable description.
Task directories use the name, for example `20260820T121136Z-inference-<hash>`. The metadata is
stored in `task.json`, `result.json`, and `task_history.jsonl`.

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

Before creating a task, the submit helpers rebase onto `origin/main`; the bridge also rebases and
retries when a result push is rejected. This keeps Mac task commits and online-zone result commits
on one line without force-pushing.

Task commits cannot be automatically deleted from a shared `main` branch: removing already pushed
commits requires history rewriting and force-pushing, which can delete another zone's tasks or
results. Keep the JSONL task history as the durable task index, and perform any Git history squash
only as a deliberate maintenance operation after stopping Mac sync and both zone services.

The online bridge maintains `automation/tasks/task_history.jsonl`. Each line records the task ID,
start time, finish time, execution platform (`online` or `offline`), current status, and source
commit. Pending and running tasks have a blank finish time; the same line is refreshed when status
changes. This file is available on the compute platform and is also returned to the Mac through Git.

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