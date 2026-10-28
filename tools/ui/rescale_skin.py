"""Stores the UI skin at 2 UI units per art pixel (docs/design/interface.md "One skin", Pixels).

python3 tools/ui/rescale_skin.py [--check]

The Kenney skin (assets/ui/rpg/) and the wood widgets of Ninja Adventure's example project
(assets/ui/wood/) came as 16-pixel art enlarged x3 with nearest neighbour: 3 UI units per art
pixel, 4.5 screen pixels on a phone's x1.5 canvas (uneven, decision 0007). This takes every such
texture back to its art (one pixel of each 3x3 block, after checking each block is one colour)
and enlarges it x2: 2 units per art pixel, the grid of the font and of the world's art, whole at
every canvas scale (x1 2 screen pixels, x1.5 3, x2 4). Nothing else changes: same colours, same
pixels, same transparency. A texture already at x2 is left alone; one that is neither fails.
--check: only says whether every texture is at x2 (exit 1 if not).
"""
import argparse
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FOLDERS = ["assets/ui/rpg", "assets/ui/wood"]


def blocks_of(image, k):
	"""Whether `image` is made of k x k blocks of one colour (transparent pixels all alike)."""
	width, height = image.size
	if width % k or height % k:
		return False
	pixels = image.load()
	for top in range(0, height, k):
		for left in range(0, width, k):
			first = pixels[left, top]
			for y in range(top, top + k):
				for x in range(left, left + k):
					here = pixels[x, y]
					if here != first and not (here[3] == 0 and first[3] == 0):
						return False
	return True


def is_x2(image):
	return blocks_of(image, 2) and not blocks_of(image, 3)


def main():
	parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
	parser.add_argument("--check", action="store_true")
	args = parser.parse_args()
	wrong = []
	for folder in FOLDERS:
		for path in sorted((ROOT / folder).glob("*.png")):
			image = Image.open(path).convert("RGBA")
			if is_x2(image):
				continue
			if args.check or not blocks_of(image, 3):
				wrong.append(path.relative_to(ROOT).as_posix())
				continue
			art = image.resize((image.width // 3, image.height // 3), Image.NEAREST)
			art.resize((art.width * 2, art.height * 2), Image.NEAREST).save(path)
			print("x2: %s (%dx%d -> %dx%d)" % (path.relative_to(ROOT).as_posix(), image.width, image.height, art.width * 2, art.height * 2))
	if wrong:
		print("not at 2 units per art pixel%s:\n  %s" % ("" if args.check else " (and not an exact x3 either)", "\n  ".join(wrong)))
		sys.exit(1)


if __name__ == "__main__":
	main()
