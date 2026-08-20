#!/usr/bin/env python3
"""Pull Git, deliver tasks, collect results, and push Git."""

import argparse
import json
import os
import shutil
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

from task_executor import execute_task


def git(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args], cwd=repo, text=True, capture_output=True, check=False
    )


def has_external_changes(repo: Path) -> bool:
    status = git(repo, "status", "--porcelain", "--untracked-files=all").stdout
    for line in status.splitlines():
        path = line[3:].split(" -> ")[-1]
        if not path.startswith("automation/tasks/"):
            print(f"bridge: repository change outside automation/tasks: {line}")
            return True
    return False


def copy_atomically(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        return
    with tempfile.TemporaryDirectory(dir=destination.parent, prefix=f".{destination.name}.") as temporary:
        temporary_path = Path(temporary) / destination.name
        shutil.copytree(source, temporary_path)
        os.replace(temporary_path, destination)


def archive_online_task(task: Path, repo_tasks: Path, status: str) -> None:
    destination = repo_tasks / status / task.name
    if destination.exists():
        shutil.rmtree(task)
        return
    os.replace(task, destination)


def execute_online_tasks(repo_tasks: Path, timeout: int) -> None:
    for source in sorted((repo_tasks / "pending").iterdir()):
        if not source.is_dir() or source.name.startswith("."):
            continue
        try:
            metadata = json.loads((source / "task.json").read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if metadata.get("zone", "offline") != "online":
            continue
        running = repo_tasks / "running" / source.name
        try:
            os.replace(source, running)
        except FileNotFoundError:
            continue
        result = execute_task(running, timeout)
        archive_online_task(running, repo_tasks, result["status"])


def sync_once(repo: Path, offline_root: Path, online_timeout: int) -> None:
    if has_external_changes(repo):
        return
    queue_has_changes = any(
        line[3:].split(" -> ")[-1].startswith("automation/tasks/")
        for line in git(repo, "status", "--porcelain").stdout.splitlines()
    )
    if not queue_has_changes and git(repo, "pull", "--ff-only").returncode != 0:
        return
    repo_tasks = repo / "automation" / "tasks"
    offline_tasks = offline_root / "tasks"
    for queue in ("pending", "running", "done", "failed"):
        (repo_tasks / queue).mkdir(parents=True, exist_ok=True)
        (offline_tasks / queue).mkdir(parents=True, exist_ok=True)
    execute_online_tasks(repo_tasks, online_timeout)
    for task in (repo_tasks / "pending").iterdir():
        if task.is_dir() and json.loads((task / "task.json").read_text(encoding="utf-8")).get("zone", "offline") == "offline":
            copy_atomically(task, offline_tasks / "pending" / task.name)
    for queue in ("done", "failed"):
        for task in (offline_tasks / queue).iterdir():
            if task.is_dir():
                target = repo_tasks / queue / task.name
                if not target.exists():
                    copy_atomically(task, target)
                pending = repo_tasks / "pending" / task.name
                if pending.exists():
                    shutil.rmtree(pending)
    git(repo, "add", "automation/tasks")
    if git(repo, "diff", "--cached", "--quiet").returncode != 0:
        if git(repo, "commit", "-m", "chore: collect remote GPU task results").returncode != 0:
            return
        git(repo, "push")


def update_status(root: Path, run_id: str, state: str, interval: int, message: str = "") -> None:
    from status import write_status

    write_status(root, "online_bridge", run_id, state, interval, message)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--offline-root", type=Path, required=True)
    parser.add_argument("--interval", type=int, default=1)
    parser.add_argument("--online-timeout", type=int, default=3600)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    offline_root = args.offline_root.resolve()
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    update_status(offline_root, run_id, "running", args.interval)
    try:
        while True:
            sync_once(args.repo.resolve(), offline_root, args.online_timeout)
            update_status(offline_root, run_id, "running", args.interval)
            if args.once:
                break
            time.sleep(args.interval)
    except KeyboardInterrupt:
        update_status(offline_root, run_id, "stopped", args.interval, "interrupted")
    except Exception as error:
        update_status(offline_root, run_id, "failed", args.interval, str(error))
        raise
    else:
        update_status(offline_root, run_id, "stopped", args.interval, "completed")


if __name__ == "__main__":
    main()