#!/usr/bin/env python3
"""Keeps locale/strings.csv (the game's translations) up to date with the project.

Collects every player-facing text and writes it to the CSV as a key, its English text being the
key itself (anything without a translation falls back to English). Existing translations are
kept; new keys get an empty French cell; keys nothing uses any more are dropped (listed).

Where texts come from:
  - Scripts (*.gd outside tests/, _tool/, .godot/): every string literal in tr("...")
    (TranslationServer.tr("...") too), and every literal on a line marked with an "# i18n"
    comment (constants and lists that are translated where they are shown);
  - the @export defaults of the player-facing fields below, in the definitions (src/definitions);
  - scenes (*.tscn): the text, tooltip_text and placeholder_text of their nodes;
  - data (data/**/*.tres, except data/balance/): the player-facing fields below;
  - grammar keys (src/core/grammar.gd): the gender of the equipment's and monsters' names, the
    feminine form of the item and elite affixes (French agreement: "Hache Affûtée").

Usage (from anywhere, python3, standard library only):
  python3 tools/i18n/extract.py           # update locale/strings.csv
  python3 tools/i18n/extract.py --check   # exit 1 if the CSV is out of date or a translation is missing
"""

import csv
import io
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
CSV_PATH = os.path.join(ROOT, "locale", "strings.csv")
LANGUAGES = ["en", "fr"]

# Folders never scanned (relative to the project root).
SKIP_DIRS = {".godot", ".git", ".claude", "_tool", "tests", "android", "build"}
# Data folders that are not part of the game (balance tools).
SKIP_DATA = {os.path.join("data", "balance")}
# Data whose names and descriptions the player never reads (only their other texts count:
# an arena's or a hazard's messages): scenes, props, materials, arenas, chests, hazards.
UNSEEN_NAMES = {os.path.join("data", *parts) for parts in [
    ("biomes", "scenes"), ("biomes", "shapes"), ("props",), ("materials",), ("arenas",), ("chests",), ("hazards",)]}

# Resource fields the player reads (data/*.tres and @export defaults).
TEXT_FIELDS = {
    "display_name", "description", "lore", "title", "subtitle", "text", "label", "leave_label",
    "used_text", "message", "goal_text", "short_label", "tagline", "shrine_text", "victory_text",
    "camp_warning", "invasion_message", "verb", "door_name", "choice", "choice_title", "choice_lore",
    "immune_text", "full_text", "revealed_text",
    # The story (data/story/): chapters, waking lines, fragments, deeds, the narrative's messages.
    "line", "author", "place", "hint", "rule", "fragment_message", "deed_message",
    # The controls (data/ui/input_prompts.tres, DeviceText, HintDef): what to do on each device.
    "touch_text", "button_text", "brand",
    # The credits (data/credits/): what changed in a pack (CreditEntryDef.changes).
    "changes",
    # The world counters (data/online/world_stats.tres): the title screen's line.
    "title_line",
    # The Nameless Keeper (NamelessKeeperDef, EndingDef, FinaleDef): after his fall, his records.
    "keeper_hint", "keeper_text", "keeper_choice_lore", "records_title", "record_line",
    # The room trials (TrialDef): the objective's line, the floor's call, the end.
    "objective", "call_line", "done_line", "evidence_name", "evidence_text",
    "accept_label", "hand_in_label", "pending_text", "return_text",
    "locked_text", "offer_text", "reward_text", "restored_text",
    "accepted_text", "found_text", "prompt", "reply",
    # Weapon evolutions (WeaponDef): what the smith says of a weapon that could evolve.
    "evolution_hint",
    # Starting kits (OathDef): their rule and their price, one line each on the card.
    "twist", "price",
}
LIST_FIELDS = {"intro_pages", "death_lines", "greetings", "branches", "branch_texts", "rank_names", "tips", "lines", "ambient_before", "ambient_after",
               "key_words", "mouse_glyphs"}
SCENE_FIELDS = {"text", "tooltip_text", "placeholder_text"}

# A GDScript or Godot resource string literal: "..." with backslash escapes.
STRING = r'"((?:[^"\\]|\\.)*)"'
TR_CALL = re.compile(r'(?<![A-Za-z0-9_])tr\(\s*' + STRING + r'\s*\)', re.S)
LITERAL = re.compile(r'(?<![&^$%A-Za-z0-9_])' + STRING)
EXPORT_DEFAULT = re.compile(r'@export\w*(?:\([^)]*\))?\s+var\s+(\w+)\s*:\s*String\s*=\s*' + STRING)
EXPORT_LIST_DEFAULT = re.compile(r'@export\w*(?:\([^)]*\))?\s+var\s+(\w+)\s*:\s*PackedStringArray\s*=\s*\[([^\]]*)\]')


def unescape(text):
    """Godot's string escapes (\\n, \\t, \\", \\\\, \\uXXXX) as the engine reads them."""
    out = []
    i = 0
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            n = text[i + 1]
            simple = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\", "'": "'", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}
            if n in simple:
                out.append(simple[n])
                i += 2
                continue
            if n == "u" and i + 5 < len(text) + 1:
                try:
                    out.append(chr(int(text[i + 2:i + 6], 16)))
                    i += 6
                    continue
                except ValueError:
                    pass
        out.append(c)
        i += 1
    return "".join(out)


def is_text(s):
    """Worth translating: a word in it once the format codes are gone (not a path)."""
    if s.startswith("res://") or s.startswith("user://"):
        return False
    return re.search(r"[^\W\d_]", re.sub(r"%[-+ 0#]*\d*(?:\.\d+)?[a-zA-Z%]", "", s)) is not None


def walk(extension):
    for folder, dirs, files in os.walk(ROOT):
        rel = os.path.relpath(folder, ROOT)
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not os.path.exists(os.path.join(folder, d, ".gdignore")))
        for name in sorted(files):
            if name.endswith(extension):
                yield os.path.join(rel, name) if rel != "." else name


def from_scripts(found):
    for path in walk(".gd"):
        source = open(os.path.join(ROOT, path), encoding="utf-8").read()
        for match in TR_CALL.finditer(source):
            add(found, unescape(match.group(1)), path, True)
        for line in source.splitlines():
            if re.search(r"#\s*i18n\b", line) and not line.lstrip().startswith("#"):
                for literal in LITERAL.findall(line[:line.rfind("#")]):
                    add(found, unescape(literal), path)
        if path.startswith(os.path.join("src", "definitions")):
            for field, literal in EXPORT_DEFAULT.findall(source):
                if field in TEXT_FIELDS:
                    add(found, unescape(literal), path)
            for field, items in EXPORT_LIST_DEFAULT.findall(source):
                if field in LIST_FIELDS:
                    for literal in LITERAL.findall(items):
                        add(found, unescape(literal), path)


def parse_string(source, at):
    """The string literal starting at source[at] == '"': (text, index after it)."""
    i = at + 1
    while i < len(source):
        if source[i] == "\\":
            i += 2
            continue
        if source[i] == '"':
            return unescape(source[at + 1:i]), i + 1
        i += 1
    raise ValueError("unterminated string")


def resource_values(source, fields, lists):
    """(field, text) for every wanted property of a .tres/.tscn file, in file order."""
    for match in re.finditer(r'^(\w+) = ', source, re.M):
        field = match.group(1)
        at = match.end()
        if field in fields and source.startswith('"', at):
            text, _ = parse_string(source, at)
            yield field, text
        elif field in lists and re.match(r'(PackedStringArray|Array\[String\])\(', source[at:]):
            i = source.index("(", at) + 1
            if source.startswith("[", i):
                i += 1
            while i < len(source):
                c = source[i]
                if c == '"':
                    text, i = parse_string(source, i)
                    yield field, text
                elif c in ")]":
                    break
                else:
                    i += 1


def from_scenes(found):
    for path in walk(".tscn"):
        source = open(os.path.join(ROOT, path), encoding="utf-8").read()
        for _, text in resource_values(source, SCENE_FIELDS, set()):
            add(found, text, path)


def from_data(found):
    for path in walk(".tres"):
        if not path.startswith("data" + os.sep) or any(path.startswith(skip + os.sep) for skip in SKIP_DATA):
            continue
        source = open(os.path.join(ROOT, path), encoding="utf-8").read()
        unseen = any(path.startswith(folder + os.sep) for folder in UNSEEN_NAMES)
        for field, text in resource_values(source, TEXT_FIELDS, LIST_FIELDS):
            if not (unseen and field in ("display_name", "description")):
                add(found, text, path)


def from_grammar(found):
    """The keys of src/core/grammar.gd: "grammar:gender:<name>" for the equipment and monsters
    (French: "m" or "f"), "grammar:feminine:<adjective>" for the item prefixes and elite affixes
    (French: the feminine form)."""
    for path in walk(".tres"):
        parts = path.split(os.sep)
        source = open(os.path.join(ROOT, path), encoding="utf-8").read()
        names = [text for field, text in resource_values(source, {"display_name"}, set()) if field == "display_name"]
        if not names:
            continue
        noun = parts[:3] in (["data", "items", "weapons"], ["data", "items", "armors"]) and "monster" not in parts
        noun = noun or parts[:2] == ["data", "monsters"]
        adjective = parts[:2] == ["data", "elites"] or (parts[:2] == ["data", "affixes"] and "is_prefix = false" not in source)
        if noun:
            add(found, "grammar:gender:" + names[0], path, True)
        if adjective:
            add(found, "grammar:feminine:" + names[0], path, True)


def add(found, text, path, always=False):
    """`always`: asked for in code with tr(), even without a word ("%d%%")."""
    if text.strip() and (always or is_text(text)) and text not in found:
        found[text] = path


def read_csv():
    """key -> {language: text} from the current CSV (empty if there is none)."""
    if not os.path.exists(CSV_PATH):
        return {}
    rows = list(csv.reader(open(CSV_PATH, encoding="utf-8", newline="")))
    if not rows:
        return {}
    header = rows[0]
    result = {}
    for row in rows[1:]:
        if not row:
            continue
        row = row + [""] * (len(header) - len(row))
        result[row[0]] = {header[i]: row[i] for i in range(1, len(header))}
    return result


def render(found, old):
    out = io.StringIO()
    writer = csv.writer(out, lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
    writer.writerow(["keys"] + LANGUAGES)
    for key in found:
        known = old.get(key, {})
        writer.writerow([key, key] + [known.get(lang, "") for lang in LANGUAGES[1:]])
    return out.getvalue()


def main():
    check = "--check" in sys.argv[1:]
    found = {}
    from_scripts(found)
    from_scenes(found)
    from_data(found)
    from_grammar(found)
    old = read_csv()
    text = render(found, old)
    new_keys = [k for k in found if k not in old]
    gone = [k for k in old if k not in found]
    missing = [k for k in found if not old.get(k, {}).get("fr", "").strip()]
    current = open(CSV_PATH, encoding="utf-8").read() if os.path.exists(CSV_PATH) else ""
    print("%d keys (%d new, %d no longer used), %d without a French text" % (len(found), len(new_keys), len(gone), len(missing)))
    for key in gone:
        print("  dropped: %r" % key[:80])
    if check:
        for key in missing:
            print("  missing fr: %r  (%s)" % (key[:80], found[key]))
        sys.exit(1 if text != current or missing else 0)
    os.makedirs(os.path.dirname(CSV_PATH), exist_ok=True)
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        f.write(text)


if __name__ == "__main__":
    main()
