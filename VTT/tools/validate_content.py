#!/usr/bin/env python3
"""Atlantis VTT — content validator (v0.9).

Walks the authored content (new-format assets/campaigns/ AND legacy
assets/missions/) and checks every referenced asset path, music suite/tier,
lighting stop, mood, and effect against what actually exists on disk / in the
known vocab. Prints a report with "did you mean" hints and exits non-zero if
any ERROR is found, so it can gate authoring at prep time (never at the table).

Run offline, no Godot needed:
    python3 tools/validate_content.py

Design mirrors session_state.gd's apply_scene(): a scene may use new-format
keys (image, time_of_day, season, effects, music) or legacy keys (map, mood).
"""

import difflib
import json
import os
import sys

TOD_STOPS = {"dawn", "noon", "dusk", "midnight"}
SEASON_STOPS = {"spring", "summer", "autumn", "winter"}
MOODS = {"none", "winter", "forest_dusk", "cave", "underwater",
         "volcanic", "sandstorm", "rain"}
EFFECTS = {"snow", "rain", "leaves", "embers", "dust", "dust_motes", "ash",
           "underwater_caustics", "meteor_glow", "heat_haze", "fog"}
MUSIC_TIERS = {"exploration", "civilization", "combat", "boss"}

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

errors = []
warnings = []


def err(where, msg):
    errors.append(f"ERROR  {where}: {msg}")


def warn(where, msg):
    warnings.append(f"warn   {where}: {msg}")


def hint(name, options):
    m = difflib.get_close_matches(str(name), list(options), n=1)
    return f" — did you mean '{m[0]}'?" if m else ""


def res_path(p):
    """res://foo -> absolute path under the project."""
    if p.startswith("res://"):
        p = p[len("res://"):]
    return os.path.join(PROJ, p)


def read_json(path):
    if not os.path.isfile(path):
        return None
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        err(os.path.relpath(path, PROJ), f"unreadable JSON ({e})")
        return None


def scan_suites():
    root = os.path.join(PROJ, "assets/audio/music/missions")
    if not os.path.isdir(root):
        return set()
    return {d for d in os.listdir(root)
            if os.path.isdir(os.path.join(root, d)) and not d.startswith(".")}


SUITES = scan_suites()


def scan_ambience():
    root = os.path.join(PROJ, "assets/audio/ambience")
    if not os.path.isdir(root):
        return set()
    return {f for f in os.listdir(root) if f.endswith(".wav")}


AMBIENCE = scan_ambience()


def check_phase(where, key, value, stops):
    """time_of_day / season: a named stop or a float in [0,1]."""
    if isinstance(value, (int, float)):
        if not (0.0 <= float(value) <= 1.0):
            err(where, f"{key} {value} out of range [0,1]")
    elif isinstance(value, str):
        if value not in stops:
            err(where, f"unknown {key} '{value}'{hint(value, stops)}")
    else:
        err(where, f"{key} must be a stop name or float, got {type(value).__name__}")


def validate_scene(where, scene, default_suite=""):
    if not isinstance(scene, dict):
        err(where, "scene is not an object")
        return
    image = scene.get("image", scene.get("map", ""))
    if not image:
        err(where, "scene has no image/map")
    elif not os.path.isfile(res_path(image)):
        err(where, f"image not found: {image}")

    music = scene.get("music", {})
    if music:
        suite = music.get("suite", default_suite)
        if suite and suite not in SUITES:
            err(where, f"unknown music suite '{suite}'{hint(suite, SUITES)}")
        tier = music.get("tier", "")
        if tier and tier not in MUSIC_TIERS:
            err(where, f"unknown music tier '{tier}'{hint(tier, MUSIC_TIERS)}")

    if "time_of_day" in scene:
        check_phase(where, "time_of_day", scene["time_of_day"], TOD_STOPS)
    if "season" in scene:
        check_phase(where, "season", scene["season"], SEASON_STOPS)
    energy = scene.get("light_energy")
    if energy is not None:
        if not isinstance(energy, (int, float)):
            err(where, f"light_energy must be a number, got {type(energy).__name__}")
        elif not (0.0 <= float(energy) <= 4.0):
            err(where, f"light_energy {energy} out of sane range [0,4]")
    grade = scene.get("light_grade")
    if grade is not None and not (
        isinstance(grade, str)
        or (isinstance(grade, list) and len(grade) >= 3
            and all(isinstance(c, (int, float)) for c in grade[:3]))
    ):
        err(where, "light_grade must be [r,g,b] or a colour string")

    if "mood" in scene and scene["mood"] not in MOODS:
        err(where, f"unknown mood '{scene['mood']}'{hint(scene['mood'], MOODS)}")
    for eff in scene.get("effects", []):
        if eff not in EFFECTS:
            warn(where, f"unknown effect '{eff}'{hint(eff, EFFECTS)}")

    sectors = scene.get("sectors")
    if sectors and not os.path.isfile(res_path(sectors)):
        warn(where, f"sectors overlay not found: {sectors}")

    # Ambience bed: a bare filename under assets/audio/ambience/ (mirrors
    # session_state.gd set_current_ambience).
    amb = scene.get("ambience", "")
    if amb:
        apath = amb if amb.startswith(("res://", "user://")) \
            else "res://assets/audio/ambience/" + amb
        if not os.path.isfile(res_path(apath)):
            err(where, f"ambience bed not found: {amb}{hint(amb, AMBIENCE)}")

    # GM briefing image: bare filenames resolve against the maps dir (mirrors
    # apply_scene). Silently-missing briefings are exactly the authoring slip
    # this validator exists to catch — the GM only finds out at the table.
    brief = scene.get("briefing", "")
    if brief:
        bpath = brief if brief.startswith(("res://", "user://")) \
            else "res://assets/maps/" + brief
        if not os.path.isfile(res_path(bpath)):
            err(where, f"briefing image not found: {brief}")


def validate_campaigns():
    idx = read_json(os.path.join(PROJ, "assets/campaigns/index.json"))
    if not idx:
        return 0
    n = 0
    for entry in idx.get("campaigns", []):
        cpath = os.path.join(PROJ, "assets/campaigns", entry.get("path", ""))
        campaign = read_json(cpath)
        if not campaign:
            err("campaigns/index.json", f"campaign unreadable: {entry.get('path')}")
            continue
        cdir = os.path.dirname(cpath)
        cid = campaign.get("id", "?")
        for m in campaign.get("missions", []):
            mpath = os.path.join(cdir, m.get("path", ""))
            mission = read_json(mpath)
            if not mission:
                err(f"campaign '{cid}'", f"mission unreadable: {m.get('path')}")
                continue
            mdir = os.path.dirname(mpath)
            dsuite = mission.get("default_music_suite", "")
            mid = mission.get("id", "?")
            for a in mission.get("areas", []):
                area = read_json(os.path.join(mdir, a.get("file", "")))
                if not area:
                    err(f"{cid}/{mid}", f"area unreadable: {a.get('file')}")
                    continue
                aid = area.get("id", "?")
                map_ids = set()
                for mp in area.get("maps", []):
                    mpid = mp.get("id", "?")
                    map_ids.add(mpid)
                    validate_scene(f"{cid}/{mid}/{aid}/{mpid}",
                                   mp.get("scene", {}), dsuite)
                # adjacency must reference sibling maps, and must go both ways.
                # The GM navigates by these buttons at the table: a one-way link
                # is a room the party can walk into and not back out of, and the
                # GM only discovers it with players watching.
                adjacency = {mp.get("id"): list(mp.get("adjacent", []))
                             for mp in area.get("maps", [])}
                for mpid, neighbours in adjacency.items():
                    for adj in neighbours:
                        if adj not in map_ids:
                            warn(f"{cid}/{mid}/{aid}/{mpid}",
                                 f"adjacent '{adj}' is not a map in this area")
                        elif mpid not in adjacency.get(adj, []):
                            warn(f"{cid}/{mid}/{aid}/{mpid}",
                                 f"adjacent '{adj}' is one-way — "
                                 f"'{adj}' does not list '{mpid}' back")
            n += 1
    return n


def validate_legacy():
    idx = read_json(os.path.join(PROJ, "assets/missions/index.json"))
    if not idx:
        return 0
    n = 0
    for entry in idx.get("missions", []):
        mpath = os.path.join(PROJ, "assets/missions", entry.get("path", ""))
        mission = read_json(mpath)
        if not mission:
            continue
        mdir = os.path.dirname(mpath)
        dsuite = mission.get("default_music_suite", "")
        mid = mission.get("id", "?")
        for loc in mission.get("locations", []):
            staging = read_json(os.path.join(mdir, loc.get("file", "")))
            if staging is None:
                continue
            validate_scene(f"legacy/{mid}/{loc.get('id')}", staging, dsuite)
        n += 1
    return n


def main():
    print(f"Atlantis VTT content validator — project: {PROJ}")
    print(f"suites found: {sorted(SUITES) or '(none)'}\n")
    nc = validate_campaigns()
    nl = validate_legacy()
    print(f"scanned {nc} new-format mission(s), {nl} legacy mission(s)\n")
    for w in warnings:
        print(w)
    for e in errors:
        print(e)
    print()
    if errors:
        print(f"FAIL — {len(errors)} error(s), {len(warnings)} warning(s)")
        return 1
    print(f"OK — 0 errors, {len(warnings)} warning(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
