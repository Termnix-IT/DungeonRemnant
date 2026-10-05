"""Run the headless test suites (tests/test_*.gd) and report each one.

Each suite runs in its own Godot process, several at a time, with its log in
.godot/test-logs/<name>.log. A suite passes when Godot exits with 0; one
that never calls quit() (a script error, an awaited signal that never comes)
is stopped at the timeout and counted as failed. Suites that start a run from
the hub set Main.run_seed, so a rerun lays out the same floors.

The Godot executable comes from --godot, then the GODOT environment variable,
then `godot` on PATH. Run from the Godot project root:

	python tools/run_tests.py                     # every suite
	python tools/run_tests.py hub shop ui_theme   # test_hub.gd, test_shop.gd, ...
	python tools/run_tests.py --skip playthrough  # all but the slow 1F-10F loop

Visual checks (tests/capture_*.gd) need a renderer and are run by hand; see
AGENTS.md.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOGS = ROOT / ".godot" / "test-logs"


def find_godot(given: str | None) -> str:
	for candidate in (given, os.environ.get("GODOT"), shutil.which("godot")):
		if candidate and (Path(candidate).is_file() or shutil.which(candidate)):
			return candidate
	sys.exit("Godot not found: pass --godot, set GODOT, or put `godot` on PATH.")


def suite_names(wanted: list[str], skipped: list[str]) -> list[str]:
	every = sorted(path.stem for path in (ROOT / "tests").glob("test_*.gd"))
	def full(name: str) -> str:
		return name if name.startswith("test_") else "test_" + name
	chosen = [full(name) for name in wanted] or every
	unknown = [name for name in chosen if name not in every]
	if unknown:
		sys.exit("No such suite: " + ", ".join(unknown))
	leave = {full(name) for name in skipped}
	return [name for name in chosen if name not in leave]


def run_suite(godot: str, name: str, timeout: float) -> tuple[str, bool, float, str]:
	log = LOGS / f"{name}.log"
	started = time.monotonic()
	command = [godot, "--headless", "--path", str(ROOT), "--log-file", str(log), "--script", f"res://tests/{name}.gd"]
	try:
		done = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
		passed = done.returncode == 0
		output = done.stdout + done.stderr
	except subprocess.TimeoutExpired as expired:
		passed = False
		output = (expired.stdout or b"").decode("utf-8", "replace") if isinstance(expired.stdout, bytes) else (expired.stdout or "")
		output += f"\nStopped after {timeout:.0f}s without finishing."
	return name, passed, time.monotonic() - started, output


def summary(output: str) -> str:
	# The suites end with one line of counts ("Hub tests: 302 checks, 0 failures").
	lines = [line for line in output.splitlines() if "checks" in line or "passed" in line or "FAILED" in line or "Stopped after" in line]
	return lines[-1].strip() if lines else ""


def failures(output: str, limit: int = 8) -> list[str]:
	# Failed checks are push_error() lines; the "at:" lines after them only
	# point at the engine's push_error.
	found = []
	for line in output.splitlines():
		line = line.strip()
		if (line.startswith("ERROR:") or line.startswith("SCRIPT ERROR:")) and line not in found:
			found.append(line)
	return found[:limit]


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
	parser.add_argument("suites", nargs="*", help="suite names, with or without the test_ prefix (default: all)")
	parser.add_argument("--skip", nargs="*", default=[], help="suites to leave out")
	parser.add_argument("--godot", help="path to the Godot executable")
	parser.add_argument("--jobs", type=int, default=max(1, min(4, (os.cpu_count() or 2) // 2)), help="suites run at once")
	parser.add_argument("--timeout", type=float, default=180.0, help="seconds before a suite is stopped")
	args = parser.parse_args()
	godot = find_godot(args.godot)
	names = suite_names(args.suites, args.skip)
	LOGS.mkdir(parents=True, exist_ok=True)
	print(f"Running {len(names)} suites, {args.jobs} at a time. Logs: {LOGS.relative_to(ROOT)}")
	results = []
	started = time.monotonic()
	with ThreadPoolExecutor(max_workers=args.jobs) as pool:
		for name, passed, seconds, output in pool.map(lambda name: run_suite(godot, name, args.timeout), names):
			results.append((name, passed))
			print(f"{'PASS' if passed else 'FAIL'}  {name:<32} {seconds:6.1f}s  {summary(output)}", flush=True)
			if not passed:
				for line in failures(output):
					print("        " + line)
	failed = [name for name, passed in results if not passed]
	print(f"\n{len(results) - len(failed)} passed, {len(failed)} failed in {time.monotonic() - started:.0f}s" + (": " + ", ".join(failed) if failed else ""))
	return 1 if failed else 0


if __name__ == "__main__":
	sys.exit(main())
