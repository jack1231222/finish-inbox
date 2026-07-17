#!/usr/bin/env python3
"""Verify Launch Services starts independent managers for independent state roots."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_APP = PROJECT_ROOT / ".build" / "release-app" / "FinishInbox.app"
DEFAULT_CLI = PROJECT_ROOT / ".build" / "release-app" / "finish-inbox"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def run(cli: Path, environment: dict[str, str], *arguments: str) -> None:
    result = subprocess.run(
        [str(cli), *arguments],
        env=environment,
        text=True,
        capture_output=True,
        timeout=30,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"command failed ({result.returncode}): {' '.join(arguments)}\n"
            f"stdout: {result.stdout}\nstderr: {result.stderr}"
        )


def finish_inbox_pids() -> set[int]:
    result = subprocess.run(
        ["pgrep", "-x", "FinishInbox"],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode not in (0, 1):
        raise RuntimeError(f"pgrep failed: {result.stderr}")
    return {int(value) for value in result.stdout.split()}


def state_root(home: Path) -> Path:
    return home / "Library" / "Application Support" / "FinishInbox"


def wait_for_count(home: Path, project: str, expected: int, timeout: float = 30) -> None:
    state_file = state_root(home) / "state.json"
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if state_file.is_file():
            try:
                state = json.loads(state_file.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                pass
            else:
                if state.get("counts", {}).get(project) == expected:
                    return
        time.sleep(0.1)
    raise RuntimeError(f"manager did not persist {project}={expected}")


def lock_is_held(home: Path) -> bool:
    lock_path = state_root(home) / "manager.lock"
    if not lock_path.is_file():
        return False
    descriptor = os.open(lock_path, os.O_RDWR)
    try:
        try:
            fcntl.lockf(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
        else:
            fcntl.lockf(descriptor, fcntl.LOCK_UN)
            return False
    finally:
        os.close(descriptor)


def wait_for_lock(home: Path, timeout: float = 30) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if lock_is_held(home):
            return
        time.sleep(0.1)
    raise RuntimeError("app manager did not retain its state-root lock")


def terminate_new_processes(existing: set[int]) -> None:
    new_processes = finish_inbox_pids() - existing
    for pid in new_processes:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline and (finish_inbox_pids() - existing):
        time.sleep(0.1)
    for pid in finish_inbox_pids() - existing:
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path, default=DEFAULT_APP)
    parser.add_argument("--cli", type=Path, default=DEFAULT_CLI)
    arguments = parser.parse_args()
    app = arguments.app.expanduser().resolve()
    cli = arguments.cli.expanduser().resolve()
    require(app.is_dir(), f"app bundle not found: {app}")
    require(cli.is_file() and os.access(cli, os.X_OK), f"CLI not executable: {cli}")

    existing_processes = finish_inbox_pids()
    try:
        with tempfile.TemporaryDirectory(prefix="finish-inbox-app-smoke-") as temporary:
            sandbox = Path(temporary)
            homes = [sandbox / "home-a", sandbox / "home-b"]
            projects = [sandbox / "source-a", sandbox / "source-b"]
            labels = ["Launch A", "Launch B"]
            environments: list[dict[str, str]] = []

            for home, project in zip(homes, projects):
                home.mkdir(parents=True)
                project.mkdir(parents=True)
                environment = os.environ.copy()
                environment.update(
                    {
                        "HOME": str(home),
                        "FINISH_INBOX_HOME": str(home),
                        "FINISH_INBOX_APP_PATH": str(app),
                        "FINISH_INBOX_HEADLESS": "1",
                    }
                )
                environments.append(environment)

            for index, (home, project, label, environment) in enumerate(
                zip(homes, projects, labels, environments)
            ):
                run(cli, environment, "map", label, "--directory", str(project))
                run(
                    cli,
                    environment,
                    "notify",
                    "--directory",
                    str(project),
                    "--event-id",
                    f"launch-{index}",
                )
                wait_for_count(home, label, 1)
                wait_for_lock(home)

            run(
                cli,
                environments[0],
                "notify",
                "--directory",
                str(projects[0]),
                "--event-id",
                "launch-a-second",
            )
            wait_for_count(homes[0], labels[0], 2)
            wait_for_lock(homes[0])
            wait_for_lock(homes[1])
            require(
                len(finish_inbox_pids() - existing_processes) == 2,
                "expected exactly two persistent app managers for two state roots",
            )
            print(
                json.dumps(
                    {
                        "managers": 2,
                        "stateRoots": 2,
                        "counts": {labels[0]: 2, labels[1]: 1},
                    },
                    indent=2,
                    sort_keys=True,
                )
            )
    finally:
        terminate_new_processes(existing_processes)


if __name__ == "__main__":
    main()
