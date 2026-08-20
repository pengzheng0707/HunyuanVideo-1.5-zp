#!/usr/bin/env python3
"""Run an approved task script and write its result files."""

import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

TASK_ID = re.compile(r"^[A-Za-z0-9_.-]+$")
COMMANDS = {"task.sh": ["bash", "task.sh"], "task.py": ["python3", "task.py"]}


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def execute_task(task_dir: Path, timeout: int) -> dict:
    metadata = {}
    task_id = task_dir.name
    result = {"task_id": task_id, "started_at": now()}
    try:
        metadata = json.loads((task_dir / "task.json").read_text(encoding="utf-8"))
        task_id = metadata.get("task_id", task_dir.name)
        if task_id != task_dir.name or not TASK_ID.fullmatch(task_id):
            raise ValueError("invalid task id")
        script = metadata.get("script")
        if script not in COMMANDS:
            raise ValueError("script is not approved")
        if not (task_dir / script).is_file():
            raise ValueError("task script is missing")
        result.update({"task_id": task_id, "commit": metadata.get("commit"), "zone": metadata.get("zone", "offline")})
        with (task_dir / "stdout.log").open("w", encoding="utf-8") as stdout, (task_dir / "stderr.log").open("w", encoding="utf-8") as stderr:
            completed = subprocess.run(
                COMMANDS[script], cwd=task_dir, stdout=stdout, stderr=stderr,
                timeout=timeout, check=False,
            )
        result.update({"status": "done" if completed.returncode == 0 else "failed", "exit_code": completed.returncode})
    except subprocess.TimeoutExpired:
        result.update({"status": "failed", "exit_code": None, "error": f"timeout after {timeout}s"})
    except Exception as error:
        result.update({"status": "failed", "exit_code": None, "error": str(error)})
    result["finished_at"] = now()
    (task_dir / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result