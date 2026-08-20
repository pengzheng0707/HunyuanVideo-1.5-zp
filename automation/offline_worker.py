#!/usr/bin/env python3
"""Execute approved tasks from a shared offline queue."""

import argparse
import json
import os
import re
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

TASK_ID = re.compile(r"^[A-Za-z0-9_.-]+$")


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def execute(task_dir: Path, timeout: int) -> None:
    metadata = {}
    task_id = task_dir.name
    result = {"task_id": task_id, "started_at": now()}
    try:
        metadata = json.loads((task_dir / "task.json").read_text(encoding="utf-8"))
        task_id = metadata.get("task_id", task_dir.name)
        if task_id != task_dir.name or not TASK_ID.fullmatch(task_id):
            raise ValueError("invalid task id")
        script = metadata.get("script")
        commands = {"task.sh": ["bash", "task.sh"], "task.py": ["python3", "task.py"]}
        if script not in commands:
            raise ValueError("script is not approved")
        if not (task_dir / script).is_file():
            raise ValueError("task script is missing")
        result.update({"task_id": task_id, "commit": metadata.get("commit")})
        with (task_dir / "stdout.log").open("w", encoding="utf-8") as stdout, (task_dir / "stderr.log").open("w", encoding="utf-8") as stderr:
            completed = subprocess.run(
                commands[script], cwd=task_dir, stdout=stdout, stderr=stderr,
                timeout=timeout, check=False,
            )
        result.update({"status": "done" if completed.returncode == 0 else "failed", "exit_code": completed.returncode})
    except subprocess.TimeoutExpired:
        result.update({"status": "failed", "exit_code": None, "error": f"timeout after {timeout}s"})
    except Exception as error:
        result.update({"status": "failed", "exit_code": None, "error": str(error)})
    result["finished_at"] = now()
    (task_dir / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


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
            continue
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
                execute(running, args.timeout)
                result = json.loads((running / "result.json").read_text(encoding="utf-8"))
                os.replace(running, args.root / "tasks" / result["status"] / running.name)
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