#!/usr/bin/env python3
"""Create an immutable task directory for the online bridge."""

import argparse
import hashlib
import json
import os
import shutil
import tempfile
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--script", required=True, type=Path)
    parser.add_argument("--commit", default="unknown")
    parser.add_argument("--output-dir", type=Path, default=Path("automation/tasks/pending"))
    args = parser.parse_args()

    script = args.script.resolve()
    if not script.is_file():
        parser.error(f"script does not exist: {script}")
    if script.suffix not in {".sh", ".py"}:
        parser.error("script must have a .sh or .py suffix")

    digest = hashlib.sha256(script.read_bytes()).hexdigest()[:12]
    task_id = f"{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}-{digest}"
    task_dir = args.output_dir.resolve()
    task_dir.mkdir(parents=True, exist_ok=True)
    destination_name = "task.sh" if script.suffix == ".sh" else "task.py"
    final_dir = task_dir / task_id
    if final_dir.exists():
        parser.error(f"task already exists: {task_id}")

    with tempfile.TemporaryDirectory(dir=task_dir, prefix=f".{task_id}.") as temporary:
        temporary_dir = Path(temporary)
        shutil.copy2(script, temporary_dir / destination_name)
        metadata = {
            "task_id": task_id,
            "commit": args.commit,
            "script": destination_name,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        (temporary_dir / "task.json").write_text(
            json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
        )
        os.replace(temporary_dir, final_dir)
    print(task_id)


if __name__ == "__main__":
    main()