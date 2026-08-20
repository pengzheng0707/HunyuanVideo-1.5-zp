#!/usr/bin/env python3
"""Execute approved tasks from a shared offline queue."""

import argparse
import json
import os
import re
import shutil
import time
from datetime import datetime, timezone
from pathlib import Path

from task_executor import execute_task

TASK_ID = re.compile(r"^[A-Za-z0-9_.-]+$")


def update_status(root: Path, run_id: str, state: str, interval: int, message: str = "") -> None:
    from status import write_status

    write_status(root, "offline_worker", run_id, state, interval, message)


def recover_running_tasks(root: Path) -> None:
    pending = root / "tasks" / "pending"
    running = root / "tasks" / "running"
    for task in sorted(running.iterdir()):
        if not task.is_dir() or task.name.startswith("."):
            continue
        result_file = task / "result.json"
        if result_file.exists():
            result = json.loads(result_file.read_text(encoding="utf-8"))
            destination = root / "tasks" / result.get("status", "failed") / task.name
        else:
            destination = pending / task.name
        if destination.exists():
            shutil.rmtree(task)
            continue
        os.replace(task, destination)


def archive_task(task: Path, root: Path, status: str) -> None:
    destination = root / "tasks" / status / task.name
    if destination.exists():
        shutil.rmtree(task)
        return
    os.replace(task, destination)


def acquire_lock(root: Path) -> Path:
    lock = root / "status" / "offline_worker.lock"
    lock.parent.mkdir(parents=True, exist_ok=True)
    lock_fd = None
    try:
        lock_fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        with os.fdopen(lock_fd, "w", encoding="utf-8") as lock_file:
            lock_file.write(str(os.getpid()) + "\n")
            lock_fd = None
    except FileExistsError:
        try:
            old_pid = int(lock.read_text(encoding="utf-8").strip())
            os.kill(old_pid, 0)
        except (OSError, ValueError):
            lock.unlink(missing_ok=True)
            return acquire_lock(root)
        raise RuntimeError(f"offline worker lock exists: {lock} (pid={old_pid})")
    finally:
        if lock_fd is not None:
            os.close(lock_fd)
    return lock


def release_lock(lock: Path) -> None:
    try:
        lock.unlink()
    except FileNotFoundError:
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--interval", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=3600)
    parser.add_argument("--idle-timeout", type=int, default=180)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    queues = [args.root / "tasks" / name for name in ("pending", "running", "done", "failed")]
    for queue in queues:
        queue.mkdir(parents=True, exist_ok=True)
    lock = acquire_lock(args.root.resolve())
    recover_running_tasks(args.root.resolve())
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    update_status(args.root, run_id, "running", args.interval)
    try:
        while True:
            for source in sorted((args.root / "tasks" / "pending").iterdir()):
                if not source.is_dir() or source.name.startswith("."):
                    continue
                running = args.root / "tasks" / "running" / source.name
                try:
                    os.replace(source, running)
                except FileNotFoundError:
                    continue
                metadata = json.loads((running / "task.json").read_text(encoding="utf-8"))
                if metadata.get("zone", "offline") != "offline":
                    archive_task(running, args.root.resolve(), "failed")
                    continue
                execute_task(running, args.timeout, args.idle_timeout)
                result = json.loads((running / "result.json").read_text(encoding="utf-8"))
                archive_task(running, args.root.resolve(), result["status"])
            update_status(args.root, run_id, "running", args.interval)
            if args.once:
                break
            time.sleep(args.interval)
    except KeyboardInterrupt:
        update_status(args.root, run_id, "stopped", args.interval, "interrupted")
    except Exception as error:
        update_status(args.root, run_id, "failed", args.interval, str(error))
        raise
    else:
        update_status(args.root, run_id, "stopped", args.interval, "completed")
    finally:
        release_lock(lock)


if __name__ == "__main__":
    main()