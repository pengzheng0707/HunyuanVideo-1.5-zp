# Remote GPU Automation

This directory implements a small file-based queue for a Mac, an online Git bridge, and an offline GPU worker.

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
bash automation/run_online_bridge.sh
bash automation/run_offline_worker.sh
```

Queue a task from the Mac after placing a `.sh` or `.py` task script in the repository:

```bash
bash automation/queue_task.sh path/to/task.sh
```

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