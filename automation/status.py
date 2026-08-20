#!/usr/bin/env python3
"""Write and inspect remote GPU service status files."""

import argparse
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path


def timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def atomic_write(path: Path, content: str) -> None:
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(content, encoding="utf-8")
    os.replace(temporary, path)


def write_status(root: Path, name: str, run_id: str, state: str, interval: int, message: str = "") -> None:
    directory = root / "status" / name
    directory.mkdir(parents=True, exist_ok=True)
    payload = {
        "service": name,
        "run_id": run_id,
        "state": state,
        "message": message,
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "updated_unix": time.time(),
        "interval_seconds": interval,
        "pid": os.getpid(),
    }
    content = json.dumps(payload, indent=2) + "\n"
    atomic_write(directory / f"{run_id}.json", content)
    atomic_write(directory / "latest.json", content)


def show_status(root: Path) -> None:
    for name in ("mac_sync", "online_bridge", "offline_worker"):
        path = root / "status" / name / "latest.json"
        if not path.exists():
            print(f"{name}: NOT RUNNING (no status file)")
            continue
        payload = json.loads(path.read_text(encoding="utf-8"))
        age = time.time() - payload.get("updated_unix", 0)
        threshold = max(10, payload.get("interval_seconds", 1) * 3)
        active = payload.get("state") == "running" and age <= threshold
        state = "RUNNING" if active else "NOT RUNNING"
        print(f"{name}: {state}")
        print(f"  state: {payload.get('state')}")
        print(f"  run_id: {payload.get('run_id')}")
        print(f"  updated_at: {payload.get('updated_at')}")
        print(f"  heartbeat_age_seconds: {age:.1f}")
        if payload.get("message"):
            print(f"  message: {payload['message']}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    write_parser = subparsers.add_parser("write")
    write_parser.add_argument("--root", type=Path, required=True)
    write_parser.add_argument("--name", required=True)
    write_parser.add_argument("--run-id", required=True)
    write_parser.add_argument("--state", required=True)
    write_parser.add_argument("--interval", type=int, required=True)
    write_parser.add_argument("--message", default="")
    show_parser = subparsers.add_parser("show")
    show_parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "write":
        write_status(args.root, args.name, args.run_id, args.state, args.interval, args.message)
    else:
        show_status(args.root)


if __name__ == "__main__":
    main()