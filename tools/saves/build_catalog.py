"""Build stable save references; preserve historical paths when content is moved.

Run from anywhere. --check is read-only and fails when regeneration is needed.
Files are read and written as UTF-8 with LF line ends whatever the system's locale (a Windows
console would otherwise decode the French texts with its code page and fail).
Runtime uses only the generated Resource, never a filesystem scan.
"""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data/save/content_catalog.tres"
KINDS = {"ItemDef": "item", "SkillDef": "skill", "PerkDef": "perk",
         "MonsterDef": "monster", "ItemAffixDef": "affix", "OathDef": "oath",
         "ChestDef": "chest", "MonsterRankDef": "rank", "EliteAffixDef": "elite"}


def collect(root):
    bases = {}
    for path in sorted((root / "src").rglob("*.gd")):
        text = path.read_text(encoding="utf-8")
        name = re.search(r"^class_name (\w+)", text, re.M)
        base = re.search(r"^extends (\w+)", text, re.M)
        if name and base:
            bases[name[1]] = base[1]
    entries = {}
    for path in sorted((root / "data").rglob("*.tres")):
        text = path.read_text(encoding="utf-8")
        kind = re.search(r'script_class="([^"]+)"', text)
        # Subresources may have their own ids; only the root resource names this entry.
        resource = text.partition('\n[resource]\n')[2]
        identifier = re.search(r'^save_id = &?"([^"]+)"', resource, re.M)
        if identifier is None:
            identifier = re.search(r'^id = &?"([^"]+)"', resource, re.M)
        if kind is None or identifier is None:
            continue
        name = kind[1]
        visited = set()
        while name not in KINDS and name in bases and name not in visited:
            visited.add(name)
            name = bases[name]
        if name not in KINDS:
            continue
        key = KINDS[name] + ":" + identifier[1]
        resource = "res://" + path.relative_to(root).as_posix()
        if key in entries:
            raise ValueError(f"Duplicate save id {key}: {entries[key]} and {resource}")
        entries[key] = resource
    return entries


def render(entries, previous=""):
    # Keep old aliases even after a target has moved; removed ids resolve to nothing.
    aliases = dict(re.findall(r'"(res://[^"\n]+)": "([^"\n]+)"', previous))
    for key, path in entries.items():
        if path in aliases and aliases[path] != key:
            raise ValueError(f"Historical path {path} already belongs to {aliases[path]}")
        aliases[path] = key
    lines = [f'[gd_resource type="Resource" script_class="ContentCatalog" load_steps={len(entries) + 2} format=3]',
             '', '[ext_resource type="Script" path="res://src/game/content_catalog.gd" id="1"]']
    keys = sorted(entries)
    for index, key in enumerate(keys, 2):
        lines.append(f'[ext_resource type="Resource" path={json.dumps(entries[key])} id="{index}"]')
    lines += ['', '[resource]', 'script = ExtResource("1")', 'entries = Dictionary[String, Resource]({']
    lines += [f'{json.dumps(key)}: ExtResource("{index}")' + (',' if index < len(keys) + 1 else '')
              for index, key in enumerate(keys, 2)]
    lines += ['})', 'legacy_paths = Dictionary[String, String]({']
    paths = sorted(aliases)
    lines += [json.dumps(path) + ': ' + json.dumps(aliases[path]) + (',' if index < len(paths) - 1 else '')
              for index, path in enumerate(paths)]
    return '\n'.join(lines + ['})', ''])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    old = OUTPUT.read_text(encoding='utf-8') if OUTPUT.exists() else ''
    entries = collect(ROOT)
    result = render(entries, old)
    print(f'{len(entries)} stable content references')
    if args.check:
        if result != old:
            print('data/save/content_catalog.tres is out of date: run python3 tools/saves/build_catalog.py')
        return int(result != old)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(result, encoding='utf-8', newline='\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
