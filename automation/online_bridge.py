#!/usr/bin/env python3
"""Pull Git, deliver tasks, collect results, and push Git."""

import argparse
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


def git(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], cwd=repo, text=True, check=False)


def copy_atomically(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        return
    with tempfile.TemporaryDirectory(dir=destination.parent, prefix=f".{destination.name}.") as temporary:
        temporary_path = Path(temporary) / destination.name
        shutil.copytree(source, temporary_path)
        os.replace(temporary_path, destination)


def sync_once(repo: Path, offline_root: Path) -> None:
    if git(repo, "diff", "--quiet").returncode != 0:
        print("bridge: local changes exist; skipping pull/push")
        return
    if git(repo, "pull", "--ff-only").returncode != 0:
        return
    repo_tasks = repo / "automation" / "tasks"
    offline_tasks = offline_root / "tasks"
    for queue in ("pending", "running", "done", "failed"):
        (repo_tasks / queue).mkdir(parents=True, exist_ok=True)
        (offline_tasks / queue).mkdir(parents=True, exist_ok=True)
    for task in (repo_tasks / "pending").iterdir():
        if task.is_dir():
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
    if git(repo, "status", "--short").stdout:
        git(repo, "add", "automation/tasks")
        if git(repo, "diff", "--cached", "--quiet").returncode != 0:
            git(repo, "commit", "-m", "chore: collect remote GPU task results")
            git(repo, "push")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--offline-root", type=Path, required=True)
    parser.add_argument("--interval", type=int, default=15)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    while True:
        sync_once(args.repo.resolve(), args.offline_root.resolve())
        if args.once:
            return
        time.sleep(args.interval)


if __name__ == "__main__":
    main()