#!/usr/bin/env python3
"""Notify the Mac once for each newly completed or failed task."""

import argparse
import json
import os
import subprocess
from pathlib import Path


def notify(title: str, message: str) -> None:
    script = f'display notification {json.dumps(message)} with title {json.dumps(title)}'
    try:
        subprocess.run(["osascript", "-e", script], check=False, capture_output=True)
    except OSError:
        pass
    print(f"\a{title}: {message}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--state-dir", type=Path, required=True)
    args = parser.parse_args()
    marker_dir = args.state_dir / "notified-tasks"
    marker_dir.mkdir(parents=True, exist_ok=True)
    for status in ("done", "failed"):
        directory = args.repo / "automation" / "tasks" / status
        if not directory.exists():
            continue
        for task_dir in sorted(directory.iterdir()):
            result_file = task_dir / "result.json"
            marker = marker_dir / f"{task_dir.name}.{status}"
            if not task_dir.is_dir() or not result_file.is_file() or marker.exists():
                continue
            try:
                result = json.loads(result_file.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            name = result.get("name", task_dir.name)
            description = result.get("description", "")
            message = f"{name}: {status}"
            if description:
                message += f" - {description}"
            notify("Remote GPU task", message)
            marker.write_text(result_file.read_text(encoding="utf-8"), encoding="utf-8")


if __name__ == "__main__":
    main()