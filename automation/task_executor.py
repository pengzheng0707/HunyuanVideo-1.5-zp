#!/usr/bin/env python3
"""Run an approved task script and write its result files."""

import json
import os
import re
import signal
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

TASK_ID = re.compile(r"^[A-Za-z0-9_.-]+$")
COMMANDS = {"task.sh": ["bash", "task.sh"], "task.py": ["python3", "task.py"]}


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def terminate_process(process: subprocess.Popen) -> None:
    try:
        os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=10)
    except (ProcessLookupError, subprocess.TimeoutExpired):
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def execute_task(task_dir: Path, timeout: int, idle_timeout: int = 180) -> dict:
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
        zone = metadata.get("zone", "offline")
        result.update({
            "task_id": task_id,
            "name": metadata.get("name", task_id),
            "description": metadata.get("description", ""),
            "commit": metadata.get("commit"),
            "zone": zone,
            "platform": zone,
        })
        stdout_path = task_dir / "stdout.log"
        stderr_path = task_dir / "stderr.log"
        with stdout_path.open("w", encoding="utf-8") as stdout, stderr_path.open("w", encoding="utf-8") as stderr:
            process = subprocess.Popen(
                COMMANDS[script], cwd=task_dir, stdout=stdout, stderr=stderr,
                start_new_session=True,
            )
            started = time.monotonic()
            last_output = started
            previous_size = (0, 0)
            while process.poll() is None:
                time.sleep(5)
                sizes = (stdout_path.stat().st_size, stderr_path.stat().st_size)
                if sizes != previous_size:
                    last_output = time.monotonic()
                    previous_size = sizes
                if time.monotonic() - started >= timeout:
                    terminate_process(process)
                    result.update({"status": "failed", "exit_code": None, "error": f"timeout after {timeout}s"})
                    break
                if time.monotonic() - last_output >= idle_timeout:
                    terminate_process(process)
                    result.update({"status": "failed", "exit_code": None, "error": f"no output for {idle_timeout}s; process killed"})
                    break
            else:
                result.update({"status": "done" if process.returncode == 0 else "failed", "exit_code": process.returncode})
    except Exception as error:
        result.update({"status": "failed", "exit_code": None, "error": str(error)})
    result["finished_at"] = now()
    (task_dir / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result