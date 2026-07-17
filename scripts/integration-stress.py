#!/usr/bin/env python3
"""Exercise the shipped CLI against an isolated, private state root."""

from __future__ import annotations

import argparse
import concurrent.futures
import fcntl
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import time


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_BINARY = PROJECT_ROOT / ".build" / "debug" / "finish-inbox"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def run(
    binary: Path,
    environment: dict[str, str],
    *arguments: str,
    check: bool = True,
    timeout: float = 30,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [str(binary), *arguments],
        env=environment,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )
    if check and result.returncode != 0:
        raise RuntimeError(
            f"command failed ({result.returncode}): {' '.join(arguments)}\n"
            f"stdout: {result.stdout}\nstderr: {result.stderr}"
        )
    return result


def load_state(state_file: Path) -> dict[str, object]:
    return json.loads(state_file.read_text(encoding="utf-8"))


def file_mode(path: Path) -> int:
    return stat.S_IMODE(path.stat().st_mode)


def lock_is_held(lock_path: Path) -> bool:
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


def ensure_binary(binary: Path, is_default: bool) -> None:
    if binary.is_file() and os.access(binary, os.X_OK):
        return
    if is_default:
        subprocess.run(
            ["swift", "build", "--package-path", str(PROJECT_ROOT), "--product", "finish-inbox"],
            check=True,
        )
    require(binary.is_file() and os.access(binary, os.X_OK), f"executable not found: {binary}")


def exercise(binary: Path, event_count: int, workers: int) -> dict[str, object]:
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix="finish-inbox-integration-") as temporary:
        sandbox = Path(temporary)
        test_home = sandbox / "home"
        project_a = sandbox / "project-a"
        project_b = sandbox / "project-b"
        unmapped = sandbox / "unmapped-private-name"
        for directory in (test_home, project_a, project_b, unmapped):
            directory.mkdir(parents=True)

        environment = os.environ.copy()
        environment.update(
            {
                "FINISH_INBOX_HOME": str(test_home),
                "FINISH_INBOX_NO_LAUNCH": "1",
                "FINISH_INBOX_HEADLESS": "1",
            }
        )

        missing = run(binary, environment, "notify", "--directory", str(unmapped), check=False)
        require(missing.returncode != 0, "an unmapped directory unexpectedly succeeded")
        missing_output = missing.stdout + missing.stderr
        require(unmapped.name not in missing_output, "missing mapping leaked the directory basename")

        run(binary, environment, "map", "Project A", "--directory", str(project_a))
        run(binary, environment, "map", "Project B", "--directory", str(project_b))

        def notify(index: int) -> None:
            directory = project_a if index % 2 == 0 else project_b
            run(
                binary,
                environment,
                "notify",
                "--directory",
                str(directory),
                "--event-id",
                f"stress-{index}",
            )

        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
            futures = [pool.submit(notify, index) for index in range(event_count)]
            for future in futures:
                future.result()

        for _ in range(2):
            run(
                binary,
                environment,
                "notify",
                "--directory",
                str(project_a),
                "--event-id",
                "duplicate-event",
            )

        run(binary, environment, "manager", "--once")
        state_root = test_home / "Library" / "Application Support" / "FinishInbox"
        state_file = state_root / "state.json"
        state = load_state(state_file)
        expected_a = (event_count + 1) // 2 + 1
        expected_b = event_count // 2
        require(state["counts"] == {"Project A": expected_a, "Project B": expected_b}, "concurrent counts differ")
        require(len(state["processedEvents"]) == event_count + 1, "deduplication history differs")

        run(
            binary,
            environment,
            "notify",
            "--directory",
            str(project_a),
            "--event-id",
            "duplicate-event",
        )
        run(binary, environment, "manager", "--once")
        require(load_state(state_file) == state, "processed duplicate changed persisted state")

        run(binary, environment, "clear", "Project A")
        state = load_state(state_file)
        require(state["counts"] == {"Project B": expected_b}, "clear changed the wrong project")

        run(
            binary,
            environment,
            "notify",
            "--directory",
            str(project_a),
            "--event-id",
            "after-clear",
        )
        run(binary, environment, "manager", "--once")
        state = load_state(state_file)
        require(state["counts"] == {"Project A": 1, "Project B": expected_b}, "post-clear event was lost")

        malformed = state_root / "events" / "malformed.json"
        malformed.write_text("not-json", encoding="utf-8")
        malformed.chmod(0o600)
        run(binary, environment, "manager", "--once")
        quarantine_files = list((state_root / "quarantine").glob("*.json"))
        require(len(quarantine_files) == 1, "malformed event was not quarantined")

        run(
            binary,
            environment,
            "notify",
            "--directory",
            str(project_b),
            "--event-id",
            "blocked-by-corrupt-state",
        )
        healthy_state = state_file.read_bytes()
        corrupt_state = b'{"schemaVersion":'
        state_file.write_bytes(corrupt_state)
        state_file.chmod(0o600)
        invalid_status = run(binary, environment, "status", check=False)
        require(invalid_status.returncode != 0, "corrupt state was reported as valid")
        run(binary, environment, "manager", "--once", check=False)
        require(state_file.read_bytes() == corrupt_state, "corrupt state was overwritten")
        blocked_event = state_root / "events" / "blocked-by-corrupt-state.json"
        require(blocked_event.is_file(), "event was deleted while state was corrupt")

        state_file.write_bytes(healthy_state)
        state_file.chmod(0o600)
        run(binary, environment, "manager", "--once")
        recovered = load_state(state_file)
        require(
            recovered["counts"] == {"Project A": 1, "Project B": expected_b + 1},
            "queued event did not recover after state repair",
        )

        manager = subprocess.Popen(
            [str(binary), "manager"],
            env=environment,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            deadline = time.monotonic() + 10
            held = False
            while time.monotonic() < deadline and manager.poll() is None:
                lock_path = state_root / "manager.lock"
                if lock_path.exists() and lock_is_held(lock_path):
                    held = True
                    break
                time.sleep(0.05)
            require(held, "manager did not acquire its lifetime lock")
            run(binary, environment, "manager", "--once")
            require(manager.poll() is None and lock_is_held(lock_path), "second manager displaced the first")
        finally:
            if manager.poll() is None:
                manager.terminate()
                try:
                    manager.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    manager.kill()
                    manager.wait(timeout=5)

        for path in state_root.rglob("*"):
            expected_mode = 0o700 if path.is_dir() else 0o600
            require(file_mode(path) == expected_mode, f"unexpected private mode for {path.name}")
        require(file_mode(state_root) == 0o700, "state root is not mode 0700")

        private_paths = (str(project_a), str(project_b), str(unmapped))
        for path in [state_file, *quarantine_files]:
            content = path.read_text(encoding="utf-8")
            require(not any(value in content for value in private_paths), f"runtime file leaked a project path: {path.name}")

        return {
            "events": event_count,
            "workers": workers,
            "counts": recovered["counts"],
            "processedEvents": len(recovered["processedEvents"]),
            "quarantined": len(quarantine_files),
            "elapsedSeconds": round(time.monotonic() - started, 3),
        }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path, default=DEFAULT_BINARY)
    parser.add_argument("--events", type=int, default=120)
    parser.add_argument("--workers", type=int, default=16)
    arguments = parser.parse_args()
    require(arguments.events > 1, "--events must be greater than one")
    require(arguments.workers > 0, "--workers must be positive")
    binary = arguments.binary.expanduser().resolve()
    ensure_binary(binary, arguments.binary == DEFAULT_BINARY)
    print(json.dumps(exercise(binary, arguments.events, arguments.workers), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
