#!/usr/bin/env python3
"""The floors' rhythm and layout, measured on the JSON lines of tools/levels/floor_probe.tscn
(docs/design/dungeon.md "Pacing"; the design audit of 2026-10-28 measured the same way).

    python3 tools/levels/floor_report.py after.jsonl [before.jsonl]

Normal floors only (boss floors are an arena). With two files, each line shows the second (the
reference) after the first. The walk is the shortest way over open ground (no rock, chasm, pool
or pillar) from the start to each stairs; a room is crossed when the walk enters its rectangle.
"""
import collections
import json
import statistics
import sys

STEPS = ((1, 0), (-1, 0), (0, 1), (0, -1))
DIFFICULTIES = {0: "Pilgrim", 1: "Keeper", 2: "Martyr", 3: "Nightmare"}
TOUGH_RADIUS = 14  # DungeonConfig.tough_radius
PILLAR_CLEARANCE = 2  # FloorPopulator.PILLAR_CLEARANCE


def quantile(values, share):
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(share * (len(ordered) - 1) + 0.5))] if ordered else 0


def pearson(xs, ys):
    mx, my = statistics.mean(xs), statistics.mean(ys)
    cov = sum((a - mx) * (b - my) for a, b in zip(xs, ys)) / len(xs)
    return cov / (statistics.pstdev(xs) * statistics.pstdev(ys))


def measure(path):
    out = collections.defaultdict(list)
    per_diff = collections.defaultdict(lambda: collections.defaultdict(list))
    for line in open(path, encoding="utf-8"):
        floor = json.loads(line)
        if floor["boss_room"] and floor["boss_room"][2] > 0:
            continue
        rooms, tiles, width, height = floor["rooms"], floor["tiles"], floor["w"], floor["h"]

        def room_of(cell):
            for i, room in enumerate(rooms):
                x, y, w, h = room["rect"]
                if x <= cell[0] < x + w and y <= cell[1] < y + h:
                    return i
            return -1

        def ground(x, y):
            return 0 <= x < width and 0 <= y < height and tiles[y][x] == "."

        start = tuple(floor["start"])
        dist, prev, queue = {start: 0}, {start: None}, [start]
        for cur in queue:
            for dx, dy in STEPS:
                nxt = (cur[0] + dx, cur[1] + dy)
                if nxt not in dist and ground(*nxt):
                    dist[nxt], prev[nxt] = dist[cur] + 1, cur
                    queue.append(nxt)
        bodies, units, chests, shops = collections.Counter(), collections.Counter(), [], []
        standing = []
        for ent in floor["ents"]:
            room = room_of(ent["at"])
            if ent["cls"] == "Monster":
                bodies[room] += 1
                units[room] += 2 if ent.get("elite") or ent.get("radius", 0) >= TOUGH_RADIUS else 1
            elif ent["cls"] == "Chest":
                chests.append(room)
                standing.append(tuple(ent["at"]))
            elif ent["cls"] in ("Merchant", "Forge"):
                shops.append(room)
            elif ent["cls"] == "Prop" and tiles[ent["at"][1]][ent["at"][0]] != "I":
                standing.append(tuple(ent["at"]))
        forced = set()
        for key in ("ambush", "pact"):
            rect = floor.get(key) or []
            if rect:
                forced.add(room_of((rect[0] + rect[2] // 2, rect[1] + rect[3] // 2)))
        forced.discard(-1)
        # Which rooms open on which: through a stretch of corridor, or wall to wall.
        owner = {(x, y): room_of((x, y)) for y in range(height) for x in range(width) if tiles[y][x] != "#"}
        links = collections.defaultdict(set)
        seen = set()
        for cell, mine in owner.items():
            if mine != -1 or cell in seen:
                continue
            stack, touched = [cell], set()
            seen.add(cell)
            while stack:
                cx, cy = stack.pop()
                for dx, dy in STEPS:
                    nxt = (cx + dx, cy + dy)
                    if nxt not in owner:
                        continue
                    if owner[nxt] == -1:
                        if nxt not in seen:
                            seen.add(nxt)
                            stack.append(nxt)
                    else:
                        touched.add(owner[nxt])
            for a in touched:
                links[a] |= touched - {a}
        for (x, y), mine in owner.items():
            for dx, dy in ((1, 0), (0, 1)):
                other = owner.get((x + dx, y + dy), -1)
                if mine != -1 and other not in (-1, mine):
                    links[mine].add(other)
                    links[other].add(mine)
        # Fights in a row on the walk to each stairs.
        loose = strict = crossed = 0
        for goal in [floor["stairs"], floor["stairs2"]]:
            goal = tuple(goal)
            if goal not in dist:
                continue
            seq, cur = [], goal
            while cur is not None:
                room = room_of(cur)
                if room != -1 and (not seq or seq[-1] != room):
                    seq.append(room)
                cur = prev[cur]
            seq.reverse()
            crossed = max(crossed, len(seq) - 1)
            run_loose = run_strict = 0
            for room in seq[1:]:
                run_loose = run_loose + 1 if bodies[room] > 0 else 0
                run_strict = run_strict + 1 if room != 0 and (bodies[room] > 0 or room in forced) else 0
                loose, strict = max(loose, run_loose), max(strict, run_strict)
        out["run_loose"].append(loose)
        out["run_strict"].append(strict)
        out["crossed"].append(crossed)
        stairs_steps = dist.get(tuple(floor["stairs"]), 1) or 1

        def progress(room):
            return dist.get(tuple(rooms[room]["heart"]), 0) / stairs_steps

        out["peak"] += [progress(r) for r in forced]
        out["release"] += [progress(r) for r in shops if r >= 0]
        calm = [i for i in range(1, len(rooms)) if bodies[i] == 0 and i not in forced]
        out["calm"].append(len(calm) / max(1, len(rooms) - 1))
        out["chests"].append(len(chests))
        out["dead_end_chests"] += [1 if r > 0 and len(links[r]) == 1 else 0 for r in chests]
        for i, room in enumerate(rooms):
            if i == 0 or bodies[i] == 0:
                continue
            x, y, w, h = room["rect"]
            out["area"].append(sum(1 for yy in range(y, y + h) for xx in range(x, x + w) if tiles[yy][xx] == "."))
            out["bodies"].append(bodies[i])
            out["units"].append(units[i])
        if floor.get("seal") is not None:
            out["seal_ok"].append(1 if floor["seal"] <= sum(bodies.values()) else 0)
        # Pillars: rooms with something standing within PILLAR_CLEARANCE cells of a pillar.
        pillars = [(x, y) for y, row in enumerate(tiles) for x, c in enumerate(row) if c == "I"]
        if pillars:
            pillar_rooms = {room_of(p) for p in pillars}
            near = {room_of(s) for s in standing
                    if any(abs(s[0] - p[0]) <= PILLAR_CLEARANCE and abs(s[1] - p[1]) <= PILLAR_CLEARANCE for p in pillars)}
            out["pillar_rooms"].append(len(pillar_rooms))
            out["squeezed_rooms"].append(len(near & pillar_rooms))
        # Open spaces: floor eroded by 2 cells (3-wide corridors vanish), rooms' hearts counted.
        floor_cells = {(x, y) for y in range(height) for x in range(width) if tiles[y][x] != "#"}
        core = {c for c in floor_cells if all((c[0] + dx, c[1] + dy) in floor_cells for dx in range(-2, 3) for dy in range(-2, 3))}
        hearts = {tuple(r["heart"]) for r in rooms}
        seen = set()
        for cell in core:
            if cell in seen:
                continue
            piece, stack = [cell], [cell]
            seen.add(cell)
            while stack:
                cx, cy = stack.pop()
                for dx, dy in STEPS:
                    nxt = (cx + dx, cy + dy)
                    if nxt in core and nxt not in seen:
                        seen.add(nxt)
                        stack.append(nxt)
                        piece.append(nxt)
            xs, ys = [p[0] for p in piece], [p[1] for p in piece]
            out["hall_size"].append(max(max(xs) - min(xs), max(ys) - min(ys)) + 5)
            out["hall_merged"].append(1 if sum(1 for p in piece if p in hearts) >= 2 else 0)
        stats = per_diff[floor["diff"]]
        stats["rooms"].append(len(rooms))
        stats["bodies"].append(sum(bodies.values()))
        stats["units"].append(sum(units.values()))
    return out, per_diff


def lines(path):
    out, per_diff = measure(path)
    floors = len(out["run_loose"])
    pct = lambda values, test: "%.0f%%" % (100.0 * sum(1 for v in values if test(v)) / max(1, len(values)))
    result = [
        ("normal floors", "%d" % floors),
        ("fight rooms in a row on the walk (monsters only, the audit's)", "median %s p90 %s max %s, floors over 3: %s" % (
            statistics.median(out["run_loose"]), quantile(out["run_loose"], 0.9), max(out["run_loose"]), pct(out["run_loose"], lambda v: v > 3))),
        ("... ambushes and pact doors counted as fights", "median %s max %s, floors over 3: %s" % (
            statistics.median(out["run_strict"]), max(out["run_strict"]), pct(out["run_strict"], lambda v: v > 3))),
        ("rooms crossed walking to a stairs", "median %s max %s" % (statistics.median(out["crossed"]), max(out["crossed"]))),
        ("calm rooms (no monsters, no ambush or pact)", "median %.0f%% of the rooms" % (100 * statistics.median(out["calm"]))),
        ("chests a floor", "mean %.2f, floors without one: %s, in a dead end: %s" % (
            statistics.mean(out["chests"]), pct(out["chests"], lambda v: v == 0), pct(out["dead_end_chests"], lambda v: v == 1))),
        ("monsters by the room's open cells", "r = %.2f (tough ones x2: r = %.2f) over %d fight rooms" % (
            pearson(out["area"], out["bodies"]), pearson(out["area"], out["units"]), len(out["area"]))),
        ("ambush and pact rooms, along the way", "median %.2f (p25 %.2f, p75 %.2f)" % (
            statistics.median(out["peak"]), quantile(out["peak"], 0.25), quantile(out["peak"], 0.75)) if out["peak"] else "-"),
        ("merchant and forge, along the way", "median %.2f (p25 %.2f, p75 %.2f)" % (
            statistics.median(out["release"]), quantile(out["release"], 0.25), quantile(out["release"], 0.75)) if out["release"] else "-"),
        ("open spaces holding 2 rooms or more", "%s of %d, p90 %d cells across, max %d" % (
            pct(out["hall_merged"], lambda v: v == 1), len(out["hall_merged"]), quantile(out["hall_size"], 0.9), max(out["hall_size"]))),
        ("pillared rooms with something within 2 cells of a pillar", "%d of %d" % (sum(out["squeezed_rooms"]), sum(out["pillar_rooms"]))),
    ]
    if out["seal_ok"]:
        result.append(("seal within the floor's monsters", pct(out["seal_ok"], lambda v: v == 1)))
    for diff in sorted(per_diff):
        stats = per_diff[diff]
        result.append(("%s: rooms, monsters, units (tough x2) a floor" % DIFFICULTIES.get(diff, diff), "%.1f, %.1f, %.1f" % (
            statistics.mean(stats["rooms"]), statistics.mean(stats["bodies"]), statistics.mean(stats["units"]))))
    return result


def main():
    after = lines(sys.argv[1])
    before = dict(lines(sys.argv[2])) if len(sys.argv) > 2 else {}
    for name, value in after:
        print("%s: %s" % (name, value))
        if name in before:
            print("    before: %s" % before[name])


if __name__ == "__main__":
    main()
