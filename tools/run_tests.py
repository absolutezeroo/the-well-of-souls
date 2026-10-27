#!/usr/bin/env python3
"""Runs the test suites in parallel: N Godot processes, each on its share of the tests.

    python3 tools/run_tests.py                       # every suite, one process per CPU
    python3 tools/run_tests.py --jobs 4 --only game  # the game suite on 4 processes
    python3 tools/run_tests.py --test game.pacts,game.levels --seed 1234
    python3 tools/run_tests.py --save-timings        # and write tests/timings.json

Each process runs `res://tests/run_tests.tscn -- --shard=i/N` (tests/run_tests.gd shares the
tests out on tests/timings.json, the longest first) with its own user folder: XDG_DATA_HOME
(Linux) and APPDATA (Windows) point at a fresh temporary folder, so no process reads or writes another's files (nor the
player's: the real game and every worktree share one user folder otherwise). Every process gets
the same --seed (printed first), so a failure plays again with the same --seed and --test.

The merged result: every `FAIL:` line with the test it came from, the checks per suite, the
slowest tests (--timings: all of them), `N checks, M failed`. Exit code = failed checks, plus
one for each process that crashed or never printed its total. Each process's whole output is
kept in the log folder (printed at the end) for the engine errors to read (docs/testing.md).
"""

import argparse
import json
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
import time

try:
	import resource  # Unix only: the children's CPU time in the summary
except ImportError:  # Windows
	resource = None

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIMINGS = os.path.join(ROOT, "tests", "timings.json")
TEST_LINE = re.compile(r"^\[test\] (\S+): (\d+) checks, (\d+) failed, ([\d.]+) s$")
SUITE_LINE = re.compile(r"^(\w+): (\d+) checks$")
TOTAL_LINE = re.compile(r"^(\d+) checks, (\d+) failed$")


def unexpected_engine_error(line):
	"""Only the documented shutdown diagnostics are allowed."""
	if line.startswith("SCRIPT ERROR:"):
		return True
	if not line.startswith("ERROR:"):
		return False
	if re.fullmatch(r"ERROR: \d+ resources still in use at exit .*", line):
		return False
	if re.fullmatch(r"ERROR: \d+ RID allocations of type '.+' were leaked at exit\.", line):
		return False
	return True


def find_godot(given):
	"""The Godot binary to run: the option, $GODOT, `godot` on the PATH, or a downloaded one."""
	candidates = [given, os.environ.get("GODOT"), shutil.which("godot")]
	for folder in (ROOT, os.path.join(ROOT, "_tool"), "/tmp"):
		for name in ("Godot_v4.7-stable_linux.x86_64", "Godot_v4.7-stable_win64_console.exe", "Godot_v4.7-stable_win64.exe"):
			candidates.append(os.path.join(folder, name))
	for path in candidates:
		if path and os.path.isfile(path) and os.access(path, os.X_OK):
			return path
	sys.exit("run_tests: no Godot binary found (use --godot or $GODOT; docs/testing.md)")


def main():
	parser = argparse.ArgumentParser(description="Runs the test suites in parallel Godot processes.")
	parser.add_argument("--jobs", "-j", type=int, default=os.cpu_count() or 1, help="processes (default: one per CPU)")
	parser.add_argument("--only", help="these suites only (unit,title,game,tutorial; balance is opt-in)")
	parser.add_argument("--test", help="these tests only (full names, a suite, or patterns with *)")
	parser.add_argument("--seed", type=int, help="the run's seed (default: a random one, printed)")
	parser.add_argument("--timings", action="store_true", help="every test's time, slowest first")
	parser.add_argument("--save-timings", action="store_true", help="write the tests' times to tests/timings.json (what the shares are balanced on)")
	parser.add_argument("--godot", help="the Godot 4.7 binary")
	parser.add_argument("--timeout", type=int, default=1800, help="seconds before a process is stopped (default 1800)")
	parser.add_argument("--logs", help="where each process's output goes (default: a temporary folder)")
	args = parser.parse_args()

	godot = find_godot(args.godot)
	if not os.path.isdir(os.path.join(ROOT, ".godot")):
		sys.exit("run_tests: import the project first: %s --headless --import" % godot)
	seed = args.seed if args.seed is not None else random.randrange(1000000)
	jobs = max(1, args.jobs)
	print("Seed %d (play the same tests again with --seed %d), %d processes" % (seed, seed, jobs), flush=True)
	logs = args.logs or tempfile.mkdtemp(prefix="puits_tests_")
	os.makedirs(logs, exist_ok=True)
	homes = tempfile.mkdtemp(prefix="puits_users_")

	started = time.monotonic()
	processes = []
	for index in range(jobs):
		user_args = ["--shard=%d/%d" % (index, jobs), "--seed=%d" % seed]
		if args.only:
			user_args.append("--only=" + args.only)
		if args.test:
			user_args.append("--test=" + args.test)
		env = dict(os.environ)
		# This process's own user:// folder: Godot puts it under XDG_DATA_HOME on Linux, APPDATA on Windows.
		env["XDG_DATA_HOME"] = env["APPDATA"] = os.path.join(homes, str(index))
		os.makedirs(env["XDG_DATA_HOME"])
		log_path = os.path.join(logs, "shard_%d.log" % index)
		log = open(log_path, "w")
		command = [godot, "--headless", "--fixed-fps", "60", "res://tests/run_tests.tscn", "--"] + user_args
		processes.append((index, subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT), log, log_path))

	failures = 0
	checks = 0
	results = []  # (name, checks, failed, seconds)
	suites = {}
	failed_lines = []
	for index, process, log, log_path in processes:
		try:
			code = process.wait(timeout=max(1, args.timeout - (time.monotonic() - started)))
		except subprocess.TimeoutExpired:
			process.kill()
			code = None
		log.close()
		total = None
		pending = []  # FAIL lines waiting for the test they belong to
		with open(log_path, errors="replace") as handle:
			for line in handle:
				line = line.rstrip("\n")
				if unexpected_engine_error(line):
					failures += 1
					pending.append("FAIL: " + line)
				if line.startswith("FAIL"):
					pending.append(line)
					continue
				match = TEST_LINE.match(line)
				if match:
					name = match.group(1)
					results.append((name, int(match.group(2)), int(match.group(3)), float(match.group(4))))
					failed_lines.extend("%s  [%s]" % (fail, name) for fail in pending)
					pending = []
					continue
				match = SUITE_LINE.match(line)
				if match:
					suites[match.group(1)] = suites.get(match.group(1), 0) + int(match.group(2))
					continue
				match = TOTAL_LINE.match(line)
				if match:
					total = (int(match.group(1)), int(match.group(2)))
		failed_lines.extend("%s  [shard %d]" % (fail, index) for fail in pending)
		if total is None:
			failures += 1
			failed_lines.append("FAIL: shard %d/%d %s without its total (see %s)" % (index, jobs, "timed out" if code is None else "stopped (exit %s)" % code, log_path))
		else:
			checks += total[0]
			failures += total[1]
			if code not in (0, total[1]):
				failures += 1
				failed_lines.append("FAIL: shard %d exited %s despite a reported total (see %s)" % (index, code, log_path))
	elapsed = time.monotonic() - started
	usage = resource.getrusage(resource.RUSAGE_CHILDREN) if resource else None
	cpu = usage.ru_utime + usage.ru_stime if usage else 0.0
	shutil.rmtree(homes, ignore_errors=True)

	for line in failed_lines:
		print(line)
	for name in sorted(suites):
		print("%s: %d checks" % (name, suites[name]))
	slowest = sorted(results, key=lambda r: -r[3])
	shown = slowest if args.timings else slowest[:10]
	print("\n%s (of %d tests, %.0f s of work):" % ("Timings" if args.timings else "Slowest", len(results), sum(r[3] for r in results)))
	for name, count, failed, seconds in shown:
		print("%8.1f s  %s (%d checks%s)" % (seconds, name, count, ", %d failed" % failed if failed else ""))
	if args.save_timings and results:
		kept = {}
		if os.path.isfile(TIMINGS):
			with open(TIMINGS) as handle:
				kept = json.load(handle)
		for name, count, failed, seconds in results:
			kept[name] = round(seconds, 1)
		with open(TIMINGS, "w") as handle:
			json.dump(dict(sorted(kept.items())), handle, indent=2)
			handle.write("\n")
		print("tests/timings.json written (%d tests)" % len(kept))
	print("\nLogs: %s" % logs)
	cpu_text = "%.0f s of CPU; " % cpu if usage else ""
	print("%d checks, %d failed, in %.0f s (%sseed %d)" % (checks, failures, elapsed, cpu_text, seed))
	sys.exit(min(failures, 255))


if __name__ == "__main__":
	main()
