"""Captures for any visual change, at the resolutions that matter (docs/art-bible.md).

python3 tools/design/capture.py [outdir] [--shots village,temple] [--godot PATH]
Writes <shot>_<WxH>.png, _zoom.png (x4 crop: the pixel grid) and _grey.png (value readability)
for the phone (2340x1080), 1080p and 720p. Compare them with the previous ones before saying a
visual change is done, and attach them to the roadmap card. Dungeon floors: tools/levels/level_shots.tscn.
Needs a display: on Linux without one it uses xvfb-run.
"""
import argparse
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools"))
RESOLUTIONS = ["2340x1080", "1920x1080", "1280x720"]


def main():
	parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
	parser.add_argument("out", nargs="?", default=os.path.join(ROOT, ".captures"))
	parser.add_argument("--shots", default="", help="village, village_map, temple, talk, village_woken, homes (default: all)")
	parser.add_argument("--godot", help="the Godot 4.7 binary")
	args = parser.parse_args()
	import run_tests
	godot = run_tests.find_godot(args.godot)
	out = os.path.abspath(args.out)
	os.makedirs(out, exist_ok=True)
	for resolution in RESOLUTIONS:
		command = [godot, "--rendering-driver", "opengl3", "--resolution", resolution, "res://tools/design/capture.tscn", "--", out, resolution]
		if args.shots:
			command.append(args.shots)
		if sys.platform.startswith("linux") and not os.environ.get("DISPLAY") and shutil.which("xvfb-run"):
			command = ["xvfb-run", "-a"] + command
		subprocess.run(command, cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=300)
	print("captures in %s" % out)


if __name__ == "__main__":
	main()
