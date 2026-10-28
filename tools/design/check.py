"""Design rules that bind every agent and every contributor (docs/art-bible.md, AGENTS.md).

tools/run_tests.py runs this before the suites; alone: python3 tools/design/check.py
Each failure says what to do instead. A failure is a rule to follow, never a check to weaken.

- Provenance: every file under assets/ is covered by a REUSE.toml annotation whose licence is
  approved (a new source or licence is the owner's decision).
- Palette: every opaque pixel of the world art (tiles, props, characters, items, weapons,
  projectiles) is a colour of assets/palette/world.hex (Ninja Adventure's colours and the
  project's approved recolours). Another pack's art fails here.
- Alpha: every pixel of the world art and the effects (assets/fx) is fully opaque or fully
  transparent; fades are dithered (docs/art-bible.md "Palette", docs/vfx.md section 1).
- UI skin: no new StyleBoxFlat/StyleBoxTexture built outside src/ui/common/ (OrnateBoard,
  RpgWindow, RpgDialog, UiParts, UiSkin draw every frame, docs/design/interface.md).
- UI grid: separations, margins and literal minimum sizes set in the interface's code are even
  (steps of 2 units).
- Media stays in assets/: no image, sound or font referenced from anywhere else.
- AGENTS.md stays short (agents follow fewer rules the longer it gets).

The palette snapshot is updated only with the owner's approval:
python3 tools/design/check.py --snapshot-palette [the extracted "Ninja Adventure - Asset Pack" folder]
"""
import argparse
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
APPROVED_LICENSES = {"CC0-1.0"}
PALETTE = ROOT / "assets/palette/world.hex"
WORLD_ART = ["assets/tiles", "assets/props", "assets/characters", "assets/items", "assets/weapons", "assets/projectiles"]
MEDIA = re.compile(r'res://[^"\s)]+\.(?:png|jpg|jpeg|webp|svg|ogg|wav|mp3|ttf|otf)')
MEDIA_OUTSIDE_OK = {"res://icon.svg"}
CODE_DIRS = ["src", "data", "tests", "tools"]
STYLEBOX = re.compile(r"StyleBox(?:Flat|Texture)\.new\(")
## Files that built their own boxes before this rule (path -> how many). All fourteen moved onto
## src/ui/common/ on 28 Oct 2026 (UiSkin.band(), slot_frame(), note_box(), draw_edge(),
## bar_frame()...): it stays empty. Never add a file here.
STYLEBOX_GRANDFATHERED = {}
AGENTS_MAX_LINES = 200


def _glob_regex(pattern):
	"""REUSE globs: * stays inside a folder, ** crosses folders."""
	out = ""
	i = 0
	while i < len(pattern):
		if pattern.startswith("**", i):
			out += ".*"
			i += 2
		elif pattern[i] == "*":
			out += "[^/]*"
			i += 1
		else:
			out += re.escape(pattern[i])
			i += 1
	return re.compile("^" + out + "$")


def _annotations():
	text = (ROOT / "REUSE.toml").read_text(encoding="utf-8")
	try:
		import tomllib
		return [(a["path"] if isinstance(a["path"], list) else [a["path"]], a.get("SPDX-License-Identifier", "")) for a in tomllib.loads(text).get("annotations", [])]
	except ImportError:  # Python before 3.11: the two keys this check reads
		found = []
		for block in text.split("[[annotations]]")[1:]:
			paths = re.findall(r'"([^"]+)"', re.search(r"^path\s*=\s*(.*)$", block, re.M).group(1))
			licence = re.search(r'^SPDX-License-Identifier\s*=\s*"([^"]*)"', block, re.M)
			found.append((paths, licence.group(1) if licence else ""))
		return found


def check_provenance():
	failures = []
	rules = [([_glob_regex(p) for p in paths], licence) for paths, licence in _annotations()]
	for path in sorted((ROOT / "assets").rglob("*")):
		if not path.is_file():
			continue
		relative = path.relative_to(ROOT).as_posix()
		licences = [licence for patterns, licence in rules if any(p.match(relative) for p in patterns)]
		if not licences:
			failures.append("%s: no source in REUSE.toml. World art comes from Ninja Adventure only and UI from the Kenney skin; a new source is the owner's decision (docs/art-bible.md \"Sources\"). Do not import another pack." % relative)
		elif licences[-1] not in APPROVED_LICENSES:
			failures.append("%s: licence %s is not approved (only %s). Ask the owner before using it." % (relative, licences[-1], ", ".join(sorted(APPROVED_LICENSES))))
	return failures


def _colours(path):
	from PIL import Image
	image = Image.open(path).convert("RGBA")
	pixels = image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()
	return {"%02x%02x%02x" % pixel[:3] for pixel in pixels if pixel[3] > 0}


def _world_pngs():
	for folder in WORLD_ART:
		yield from sorted((ROOT / folder).rglob("*.png"))


def check_palette():
	try:
		import PIL  # noqa: F401
	except ImportError:
		print("design: palette check skipped (pip install pillow)", file=sys.stderr)
		return []
	if not PALETTE.is_file():
		return ["assets/palette/world.hex is missing: the owner snapshots it (tools/design/check.py --snapshot-palette)."]
	allowed = {line.strip().lower() for line in PALETTE.read_text(encoding="utf-8").splitlines() if line.strip()}
	failures = []
	for path in _world_pngs():
		stray = _colours(path) - allowed
		if stray:
			failures.append("%s: %d colour(s) outside the world palette (e.g. #%s). Use Ninja Adventure art, or recolour onto assets/palette/world.hex (tools/vfx/recolor.py); another pack's art is not allowed (docs/art-bible.md \"Palette\")." % (path.relative_to(ROOT).as_posix(), len(stray), sorted(stray)[0]))
	return failures


def check_alpha():
	try:
		from PIL import Image
	except ImportError:
		print("design: alpha check skipped (pip install pillow)", file=sys.stderr)
		return []
	failures = []
	for path in list(_world_pngs()) + sorted((ROOT / "assets/fx").rglob("*.png")):
		image = Image.open(path).convert("RGBA")
		partial = sum(image.getchannel("A").histogram()[1:255])
		if partial:
			failures.append("%s: %d half-transparent pixel(s). Alpha is 1-bit in the world's art: make each pixel opaque (a colour of the palette) or transparent, and dither a fade (docs/art-bible.md \"Palette\")." % (path.relative_to(ROOT).as_posix(), partial))
	return failures


def check_ui_skin():
	failures = []
	for path in sorted((ROOT / "src").rglob("*.gd")):
		relative = path.relative_to(ROOT).as_posix()
		if relative.startswith("src/ui/common/"):
			continue
		count = len(STYLEBOX.findall(path.read_text(encoding="utf-8")))
		if count > STYLEBOX_GRANDFATHERED.get(relative, 0):
			failures.append("%s: builds its own StyleBox. Every frame, panel and dialogue box comes from src/ui/common/ (OrnateBoard, RpgWindow, RpgDialog, UiParts) with UiSkin colours (docs/design/interface.md \"One skin\")." % relative)
	for path in sorted((ROOT / "src").rglob("*.tscn")):
		relative = path.relative_to(ROOT).as_posix()
		if not relative.startswith("src/ui/common/") and re.search(r'type="StyleBox(?:Flat|Texture)"', path.read_text(encoding="utf-8")):
			failures.append("%s: an inline StyleBox in a scene. Use the skin of src/ui/common/ (docs/design/interface.md \"One skin\")." % relative)
	return failures


## A layout value set in code: a separation or margin override, a content margin, a literal
## minimum size. On the UI's 2-unit grid it is even (docs/design/interface.md "One skin",
## Pixels); the Kenney skin's texture margins (multiples of 3) are its own art grid.
UI_GRID = re.compile(r'(?:add_theme_constant_override\("(?:separation|h_separation|v_separation|margin_(?:left|right|top|bottom))", |content_margin_(?:left|right|top|bottom) = |set_content_margin_all\(|custom_minimum_size(?:\.[xy])? = (?:Vector2\()?)(-?\d+)(?:\.0)?\b')


UI_SIZE = re.compile(r'custom_minimum_size = Vector2\((-?\d+)(?:\.0)?, (-?\d+)(?:\.0)?\)')


def check_ui_grid():
	failures = []
	for folder in ("src/ui", "src/village"):
		for path in sorted((ROOT / folder).rglob("*.gd")):
			for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
				numbers = [match.group(1) for match in UI_GRID.finditer(line)]
				for match in UI_SIZE.finditer(line):
					numbers.append(match.group(2))
				for value in numbers:
					if int(value) % 2:
						failures.append("%s:%d: an odd layout value (%s). Offsets, sizes and margins go by steps of 2 units: whole screen pixels at x1.5 (docs/design/interface.md \"One skin\", Pixels)." % (path.relative_to(ROOT).as_posix(), number, value))
	return failures


def check_media_paths():
	failures = []
	for folder in CODE_DIRS:
		for path in sorted((ROOT / folder).rglob("*")):
			if path.suffix not in (".gd", ".tres", ".tscn") or not path.is_file():
				continue
			for found in set(MEDIA.findall(path.read_text(encoding="utf-8", errors="replace"))):
				if not found.startswith("res://assets/") and found not in MEDIA_OUTSIDE_OK:
					failures.append("%s: uses %s. Images, sounds and fonts live in assets/ with their source in REUSE.toml." % (path.relative_to(ROOT).as_posix(), found))
	return failures


def check_agents_length():
	lines = len((ROOT / "AGENTS.md").read_text(encoding="utf-8").splitlines())
	if lines > AGENTS_MAX_LINES:
		return ["AGENTS.md has %d lines (at most %d): agents follow fewer rules the longer it gets. Move details into docs/ and point to them." % (lines, AGENTS_MAX_LINES)]
	return []


def run():
	return check_provenance() + check_palette() + check_alpha() + check_ui_skin() + check_ui_grid() + check_media_paths() + check_agents_length()


def snapshot_palette(pack):
	colours = set()
	for path in _world_pngs():
		colours |= _colours(path)
	for folder in ("Backgrounds", "Actor", "Items", "FX") if pack else ():  # the pack's world art, not its UI
		for path in (Path(pack) / folder).rglob("*.png"):
			colours |= _colours(path)
	PALETTE.parent.mkdir(parents=True, exist_ok=True)
	PALETTE.write_text("".join(c + "\n" for c in sorted(colours)), encoding="utf-8", newline="\n")
	print("assets/palette/world.hex: %d colours" % len(colours))


def main():
	parser = argparse.ArgumentParser(description="Design rules every change must keep (docs/art-bible.md).")
	parser.add_argument("--snapshot-palette", nargs="?", const="", metavar="PACK", help="owner only: rewrite assets/palette/world.hex from the world art (and an extracted pack)")
	args = parser.parse_args()
	if args.snapshot_palette is not None:
		snapshot_palette(args.snapshot_palette)
		return
	failures = run()
	for failure in failures:
		print("FAIL: design: " + failure)
	print("design: %d rule(s) broken" % len(failures) if failures else "design: all rules kept")
	sys.exit(1 if failures else 0)


if __name__ == "__main__":
	main()
