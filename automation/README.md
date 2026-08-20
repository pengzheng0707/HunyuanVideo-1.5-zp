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