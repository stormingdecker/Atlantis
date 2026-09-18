extends Node

# Atlantis VTT bootstrap.
#
# The Main scene runs in the main OS window. It:
#   1. Configures the main window as the GM control surface.
#   2. Instantiates the GM control UI as a child of the main window.
#   3. Spawns a secondary OS Window node for the projector display.
#   4. If a second display is detected, moves the projector to it fullscreen.
#   5. Spawns the AudioController (process-global audio).
#   6. Scans the asset directories and seeds the SessionState libraries.
#
# Communication between the GM panel and the projector flows through the
# SessionState autoload — Main does not switchboard signals.
#
# Multi-window requires `display/window/subwindows/embed_subwindows=false`
# in project.godot.

const GM_WINDOW_SCENE := preload("res://scenes/gm_window.tscn")
const PROJECTOR_SCENE := preload("res://scenes/projector.tscn")
const AUDIO_CONTROLLER_SCENE := preload("res://scenes/audio_controller.tscn")

const MAPS_DIR := "res://assets/maps"
const MUSIC_DIR := "res://assets/audio/music"
const MISSIONS_MUSIC_DIR := "res://assets/audio/music/missions"
const SFX_DIR := "res://assets/audio/sfx"
const MISSIONS_DIR := "res://assets/missions"
const CAMPAIGNS_DIR := "res://assets/campaigns"
const HANDOUTS_DIR := "res://assets/handouts"

# Boot directly into the Atlantis facility map with sectors lit up, caustics
# + meteor glow running, and a music suite playing. Lets every iteration
# press F5 and immediately see the whole stack in action. Flip to false to
# return to normal session-restore behaviour.
const DEMO_ON_BOOT := true
const DEMO_MAP_PATH := "res://assets/maps/atlantis.png"
const DEMO_MUSIC_SUITE := "test_mission"
const DEMO_MUSIC_TIER := "exploration"

var gm_window: Control
var projector_window: Window
var projector_root: Node2D
var audio_controller: Node

# Screenshot harness state (see _ready / _process). Time-based (not frame-
# based) so it still fires under slow software rendering (Xvfb/llvmpipe), where
# a single frame can take seconds. Captures after the boot crossfade (1.5s)
# plus a little slack for the effects to animate.
var _shot_prefix: String = ""
var _shot_delay_sec: float = 2.5
var _shot_elapsed: float = 0.0

# Audio content-capture harness (ATLANTIS_AUDIOCAP=<wav path>). Records the
# Master bus to a WAV so the mixed output can be checked for silence / content.
# Needs a real audio driver (--audio-driver ALSA + a null PCM); the default
# Dummy driver outputs silence. Bounded by a short wall time — the ALSA null
# device is unthrottled, so this captures content, not realtime timing.
# Audio resolution check (ATLANTIS_AUDIOCHECK=<report path>). Headless, no
# device: reports the track each (suite, tier) and each mission location
# resolves to, so the wrapper can confirm the right, non-silent file is wired.
# (Capturing the live MIXED output to WAV isn't practical on this box — no
# realtime audio sink — so mix BEHAVIOR is checked via tools/fadetest.sh and
# CONTENT via analyzing these source files directly.)
var _audiocheck_path: String = ""

# Crossfade-envelope harness (ATLANTIS_FADETEST=<csv path>). Runs under the
# Dummy driver (no device): starts the demo suite at exploration, switches to
# combat mid-run, and logs the music volume_db every frame. The volume tween
# runs on the scene clock, so the envelope is REALTIME and measurable.
var _fadetest_path: String = ""
var _fadetest_elapsed: float = 0.0
var _fadetest_switched: bool = false
var _fadetest_lines: PackedStringArray = PackedStringArray()

# Movie-capture harness (ATLANTIS_MOVIE=<png prefix>, ATLANTIS_MOVIE_FRAMES=N,
# ATLANTIS_MOVIE_WARMUP=W). Meant to run under --fixed-fps: writes one
# projector-viewport PNG per frame after a warmup, so the delta-driven flicker
# and particles advance a constant step per captured frame → smooth playback
# when assembled by ffmpeg at the movie fps. Slow under llvmpipe but deterministic.
var _movie_prefix: String = ""
var _movie_frames: int = 60
var _movie_warmup: int = 40
var _movie_count: int = 0
var _movie_warm: int = 0

# Lighting-transition demo (ATLANTIS_LIGHTING_DEMO=1). Establishes an "overcast"
# grade at boot, then — the frame movie capture BEGINS — tweens into a "miracle"
# (sun breaks through: warm grade + additive bloom). Lets the movie harness film
# the overcast→miracle transition deterministically under --fixed-fps. Inert
# unless the env var is set. See scripts/session_state.gd transition_lighting.
const LIGHTING_DEMO_DURATION := 2.0  # seconds; pair with ~60 frames @ 30fps
var _lighting_demo: bool = false
var _lighting_demo_fired: bool = false


func _ready() -> void:
	_configure_main_window()
	_spawn_gm_panel()
	_spawn_projector_window()
	_spawn_audio_controller()
	_populate_libraries()
	_scan_missions()
	_scan_campaigns()
	SessionState.library_refresh_requested.connect(_populate_libraries)
	# Restore last session AFTER libraries scan so saved paths can be
	# validated against what's currently on disk.
	SessionState.load_session()
	# Facility state (sector tiers, TP, RUs) is independent of session
	# state — it represents campaign progression across sessions.
	SessionState.load_facility_state()
	if DEMO_ON_BOOT:
		_apply_demo_boot()
	# Headless screenshot harness: when ATLANTIS_SCREENSHOT is set to a path
	# prefix, wait for the boot crossfade + a few effect frames, capture both
	# windows to <prefix>_gm.png / <prefix>_projector.png, then quit. Inert
	# during normal runs (env var unset). Used to capture frames on a display-
	# less devserver under Xvfb.
	# Capture harness can stage a map first:
	# ATLANTIS_STAGE="campaign:mission:area:map"
	var stage_req := OS.get_environment("ATLANTIS_STAGE")
	if stage_req != "":
		var parts := stage_req.split(":")
		if parts.size() == 4:
			SessionState.stage_map(parts[0], parts[1], parts[2], parts[3])
	# Briefing-map capture hook: load a map that has a <map>_briefing.png and
	# show the GM briefing overlay, so a screenshot proves the feature. Inert
	# unless ATLANTIS_BRIEFING_DEMO is set (used with ATLANTIS_SCREENSHOT).
	if OS.get_environment("ATLANTIS_BRIEFING_DEMO") != "":
		if ResourceLoader.exists("res://assets/maps/fatima_cova.png"):
			SessionState.set_current_map("res://assets/maps/fatima_cova.png")
		if gm_window != null:
			gm_window.call("_on_briefing_toggled", true)
		printerr("[briefing] demo armed (fatima_cova briefing shown)")
	_shot_prefix = OS.get_environment("ATLANTIS_SCREENSHOT")
	_audiocheck_path = OS.get_environment("ATLANTIS_AUDIOCHECK")
	_fadetest_path = OS.get_environment("ATLANTIS_FADETEST")
	_movie_prefix = OS.get_environment("ATLANTIS_MOVIE")
	if _movie_prefix != "":
		var _mf := OS.get_environment("ATLANTIS_MOVIE_FRAMES")
		if _mf != "":
			_movie_frames = int(_mf)
		var _mw := OS.get_environment("ATLANTIS_MOVIE_WARMUP")
		if _mw != "":
			_movie_warmup = int(_mw)
		printerr("[movie] armed prefix=", _movie_prefix, " frames=", _movie_frames, " warmup=", _movie_warmup)
		if OS.get_environment("ATLANTIS_LIGHTING_DEMO") != "":
			_lighting_demo = true
			# Establish the overcast base now; the transition fires when capture starts.
			SessionState.set_light_grade(Color(0.62, 0.70, 0.82), 0.72, 0.0)
			printerr("[movie] lighting demo armed (overcast -> miracle)")
		set_process(true)
	elif _shot_prefix != "":
		# printerr → stderr (unbuffered), so it survives even if the run is
		# killed before stdout flushes.
		printerr("[screenshot] armed, prefix=", _shot_prefix, " delay=", _shot_delay_sec, "s")
		set_process(true)
	elif _audiocheck_path != "":
		set_process(true)
	elif _fadetest_path != "":
		SessionState.set_current_music_suite(DEMO_MUSIC_SUITE)
		SessionState.set_current_music_tier("exploration")
		_fadetest_lines.append("t_sec,volume_db,playing")
		printerr("[fadetest] armed -> ", _fadetest_path)
		set_process(true)
	else:
		set_process(false)


func _apply_demo_boot() -> void:
	# Force the app into a known-good "everything visible" state on launch.
	# Overrides whatever was restored from session.json so iteration is
	# reproducible. Safe to no-op if assets are missing.
	if not ResourceLoader.exists(DEMO_MAP_PATH):
		push_warning("Demo boot: map missing at %s" % DEMO_MAP_PATH)
	else:
		SessionState.set_current_map(DEMO_MAP_PATH)
		SessionState.set_hex_grid_visible(true)
	if SessionState.music_suites.has(DEMO_MUSIC_SUITE):
		SessionState.set_current_music_suite(DEMO_MUSIC_SUITE)
		SessionState.set_current_music_tier(DEMO_MUSIC_TIER)
	else:
		push_warning("Demo boot: music suite %s not found" % DEMO_MUSIC_SUITE)
	# Facility belongs to the Atlantis campaign — make it active before seeding
	# so the demo sector tiers land in atlantis's slice, not whichever campaign
	# happens to be first in the registry.
	SessionState.set_current_campaign("atlantis")
	# Seed a couple of sector tiers so the tier coloring is visible without
	# any manual setup. Mix of T1/T2/T3 across both rings.
	SessionState.set_sector_tier("I-1", 3)  # Command — fully upgraded
	SessionState.set_sector_tier("I-2", 2)  # Refinery — mid-tier
	SessionState.set_sector_tier("O-3", 2)  # Factory — mid-tier
	SessionState.set_sector_tier("O-5", 3)  # Commons — fully upgraded
	SessionState.set_sector_upgrading("I-3", true)  # Foundry — in progress
	SessionState.adjust_tp(50 - SessionState.facility_state.get("tp_balance", 0))


func _process(delta: float) -> void:
	# One of the test harnesses (each gated by its own env var, mutually
	# exclusive in practice). Inert during normal runs.
	if _movie_prefix != "":
		_process_movie()
	elif _audiocheck_path != "":
		_process_audiocheck()
	elif _fadetest_path != "":
		_process_fadetest(delta)
	elif _shot_prefix != "":
		_process_screenshot(delta)


func _process_screenshot(delta: float) -> void:
	# Wall-clock timed so it fires regardless of render framerate.
	_shot_elapsed += delta
	if _shot_elapsed < _shot_delay_sec:
		return
	set_process(false)
	var gm_tex := get_window().get_texture()
	if gm_tex != null:
		var gm_img := gm_tex.get_image()
		if gm_img != null:
			var ok := gm_img.save_png("%s_gm.png" % _shot_prefix)
			printerr("[screenshot] gm save rc=", ok)
	if projector_window != null:
		var proj_tex := projector_window.get_texture()
		if proj_tex != null:
			var proj_img := proj_tex.get_image()
			if proj_img != null:
				var ok2 := proj_img.save_png("%s_projector.png" % _shot_prefix)
				printerr("[screenshot] projector save rc=", ok2)
	else:
		printerr("[screenshot] projector_window is null")
	get_tree().quit()


func _process_movie() -> void:
	# One projector-viewport PNG per frame after a warmup, then quit. Run under
	# --fixed-fps so the flicker/particles advance a constant step per frame.
	if _movie_warm < _movie_warmup:
		_movie_warm += 1
		return
	# First captured frame: kick off the overcast→miracle tween so the whole
	# transition lands inside the captured window (not during warmup).
	if _lighting_demo and not _lighting_demo_fired:
		_lighting_demo_fired = true
		SessionState.transition_lighting(
			{"grade": [1.0, 0.96, 0.86], "energy": 1.12, "bloom": 0.55},
			LIGHTING_DEMO_DURATION)
	if projector_window != null:
		var tex := projector_window.get_texture()
		if tex != null:
			var img := tex.get_image()
			if img != null:
				img.save_png("%s_%04d.png" % [_movie_prefix, _movie_count])
	_movie_count += 1
	if _movie_count >= _movie_frames:
		printerr("[movie] wrote ", _movie_count, " frames -> ", _movie_prefix)
		get_tree().quit()


func _process_audiocheck() -> void:
	# Report which track each (suite, tier) and each staged map resolves to —
	# exercising the app's real suite-scan + resolution. One CSV-ish line per
	# entry; the wrapper analyzes the referenced source files.
	set_process(false)
	var lines := PackedStringArray(["kind,key,path"])
	for suite_id in SessionState.music_suites.keys():
		var suite: Dictionary = SessionState.music_suites[suite_id]
		for tier in SessionState.MUSIC_TIERS:
			lines.append("suite,%s/%s,%s" % [suite_id, tier, suite.get(tier, "")])
	for c in SessionState.campaigns:
		if not (c is Dictionary):
			continue
		var cid: String = c.get("id", "")
		for m in c.get("missions", []):
			if not (m is Dictionary):
				continue
			var default_suite: String = m.get("default_music_suite", "")
			for a in m.get("areas", []):
				if not (a is Dictionary):
					continue
				for mp in a.get("maps", []):
					if not (mp is Dictionary):
						continue
					var music: Dictionary = mp.get("scene", {}).get("music", {})
					var suite_id: String = music.get("suite", default_suite)
					var tier: String = music.get("tier", "")
					var path: String = SessionState.music_suites.get(suite_id, {}).get(tier, "")
					lines.append("map,%s/%s/%s/%s (%s/%s),%s" % [cid, m.get("id", ""), a.get("id", ""), mp.get("id", ""), suite_id, tier, path])
	var f := FileAccess.open(_audiocheck_path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		f.close()
	printerr("[audiocheck] wrote ", lines.size() - 1, " entries -> ", _audiocheck_path)
	get_tree().quit()


func _process_fadetest(delta: float) -> void:
	_fadetest_elapsed += delta
	var vol := 0.0
	var playing := false
	if audio_controller != null:
		vol = audio_controller.get_music_volume_db()
		playing = audio_controller.is_music_playing()
	_fadetest_lines.append("%.3f,%.2f,%s" % [_fadetest_elapsed, vol, str(playing)])
	# Once the fade-in (1.5s) has settled, switch tier to trigger a crossfade.
	if not _fadetest_switched and _fadetest_elapsed >= 1.8:
		SessionState.set_current_music_tier("combat")
		_fadetest_switched = true
	if _fadetest_elapsed >= 3.8:
		set_process(false)
		var f := FileAccess.open(_fadetest_path, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(_fadetest_lines))
			f.close()
		printerr("[fadetest] wrote ", _fadetest_lines.size() - 1, " samples")
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SessionState.save_session()
		SessionState.save_facility_state()
		get_tree().quit()


func _configure_main_window() -> void:
	# GM control runs on a 1920x1080 tablet.
	var w := get_window()
	w.title = "Atlantis VTT — GM Control"
	w.size = Vector2i(1920, 1080)


func _spawn_gm_panel() -> void:
	gm_window = GM_WINDOW_SCENE.instantiate()
	add_child(gm_window)


func _spawn_projector_window() -> void:
	projector_window = Window.new()
	projector_window.title = "Atlantis VTT — Projector"
	# Projector is a 1920x1080 (16:9) top-down display.
	projector_window.size = Vector2i(1920, 1080)
	projector_window.transient = false
	projector_window.exclusive = false

	# If a second display is present, send the projector there fullscreen.
	if DisplayServer.get_screen_count() > 1:
		projector_window.current_screen = 1
		projector_window.mode = Window.MODE_FULLSCREEN

	add_child(projector_window)

	projector_root = PROJECTOR_SCENE.instantiate()
	projector_window.add_child(projector_root)

	# Block accidental close on the projector — GM closes app from the
	# main window. Without this, the user could kill the projector mid-
	# session and lose state.
	projector_window.close_requested.connect(func(): pass)


func _spawn_audio_controller() -> void:
	audio_controller = AUDIO_CONTROLLER_SCENE.instantiate()
	add_child(audio_controller)


# === Mission scanning =====================================================
#
# Walk the assets/missions/ tree (index -> mission manifest -> location
# leaves), parse it all, and seed SessionState.missions. Centralizing the
# file I/O here keeps SessionState filesystem-free (same split as the map
# sidecar / sector overlay scan). Eager-loads every leaf — fine for a
# campaign's worth of small files; switch to lazy per-click if it ever grows.

func _scan_missions() -> void:
	var index = _read_json(MISSIONS_DIR + "/index.json")
	if not (index is Dictionary):
		return
	var out: Array = []
	for entry in index.get("missions", []):
		if not (entry is Dictionary):
			continue
		var rel: String = entry.get("path", "")
		if rel == "":
			continue
		var mpath := MISSIONS_DIR + "/" + rel
		var mission = _read_json(mpath)
		if not (mission is Dictionary):
			push_warning("main: mission manifest unreadable: %s" % mpath)
			continue
		var mdir := mpath.get_base_dir()
		var locations: Array = []
		for loc in mission.get("locations", []):
			if not (loc is Dictionary):
				continue
			var lf: String = loc.get("file", "")
			if lf == "":
				continue
			var staging = _read_json(mdir + "/" + lf)
			if not (staging is Dictionary):
				push_warning("main: location leaf unreadable: %s/%s" % [mdir, lf])
				continue
			locations.append({
				"id": loc.get("id", ""),
				"title": loc.get("title", loc.get("id", "")),
				"staging": staging,
			})
		out.append({
			"id": mission.get("id", entry.get("id", "")),
			"title": mission.get("title", entry.get("title", "")),
			"blurb": mission.get("blurb", ""),
			"default_music_suite": mission.get("default_music_suite", ""),
			"locations": locations,
		})
	SessionState.set_missions(out)


# === Campaign scanning (v0.9) =============================================
#
# Walk assets/campaigns/ (index -> campaign.json -> mission.json -> area
# leaf with maps[]) into the Campaign->Mission->Area->Map tree. If no
# new-format content exists, shim the legacy missions/ tree scanned above
# into a single synthetic "atlantis" campaign so nothing breaks during the
# migration.

func _scan_campaigns() -> void:
	var out: Array = []
	var index = _read_json(CAMPAIGNS_DIR + "/index.json")
	if index is Dictionary:
		for entry in index.get("campaigns", []):
			if not (entry is Dictionary):
				continue
			var cpath := CAMPAIGNS_DIR + "/" + str(entry.get("path", ""))
			var campaign = _read_json(cpath)
			if not (campaign is Dictionary):
				push_warning("main: campaign manifest unreadable: %s" % cpath)
				continue
			out.append(_read_campaign(campaign, cpath.get_base_dir()))
	# Back-compat shim: always surface the legacy missions/ tree as the
	# "atlantis" campaign, UNLESS new-format content already defines one — so
	# adding a new campaign (e.g. calibration) doesn't hide arc01.
	var has_atlantis := false
	for c in out:
		if c is Dictionary and c.get("id", "") == "atlantis":
			has_atlantis = true
			break
	if not has_atlantis and SessionState.missions.size() > 0:
		out.append(_legacy_campaign_from_missions())
	SessionState.set_campaigns(out)


func _read_campaign(campaign: Dictionary, cdir: String) -> Dictionary:
	var missions_out: Array = []
	for m in campaign.get("missions", []):
		if not (m is Dictionary):
			continue
		var mpath := cdir + "/" + str(m.get("path", ""))
		var mission = _read_json(mpath)
		if not (mission is Dictionary):
			push_warning("main: mission manifest unreadable: %s" % mpath)
			continue
		missions_out.append(_read_mission_areas(mission, m, mpath.get_base_dir()))
	return {
		"id": campaign.get("id", ""),
		"title": campaign.get("title", campaign.get("id", "")),
		"blurb": campaign.get("blurb", ""),
		"home_area": campaign.get("home_area", ""),
		"missions": missions_out,
	}


func _read_mission_areas(mission: Dictionary, entry: Dictionary, mdir: String) -> Dictionary:
	var areas_out: Array = []
	for a in mission.get("areas", []):
		if not (a is Dictionary):
			continue
		var af: String = a.get("file", "")
		if af == "":
			continue
		var area = _read_json(mdir + "/" + af)
		if not (area is Dictionary):
			push_warning("main: area leaf unreadable: %s/%s" % [mdir, af])
			continue
		var maps_out: Array = []
		for mp in area.get("maps", []):
			if not (mp is Dictionary):
				continue
			maps_out.append({
				"id": mp.get("id", ""),
				"title": mp.get("title", mp.get("id", "")),
				"adjacent": mp.get("adjacent", []),
				"scene": mp.get("scene", {}),
			})
		areas_out.append({
			"id": area.get("id", a.get("id", "")),
			"title": area.get("title", a.get("title", "")),
			"gm_notes": area.get("gm_notes", ""),
			"maps": maps_out,
		})
	return {
		"id": mission.get("id", entry.get("id", "")),
		"title": mission.get("title", entry.get("title", "")),
		"blurb": mission.get("blurb", ""),
		"theme": mission.get("theme", ""),
		"default_music_suite": mission.get("default_music_suite", ""),
		"areas": areas_out,
	}


# Wrap the legacy missions tree (each location = one single-scene "area" with
# a single "default" map whose scene is the location's staging dict).
func _legacy_campaign_from_missions() -> Dictionary:
	var missions_out: Array = []
	for m in SessionState.missions:
		if not (m is Dictionary):
			continue
		var areas_out: Array = []
		for loc in m.get("locations", []):
			if not (loc is Dictionary):
				continue
			var staging: Dictionary = loc.get("staging", {})
			areas_out.append({
				"id": loc.get("id", ""),
				"title": loc.get("title", ""),
				"gm_notes": staging.get("gm_notes", ""),
				"maps": [{
					"id": "default",
					"title": loc.get("title", ""),
					"adjacent": [],
					"scene": staging,
				}],
			})
		missions_out.append({
			"id": m.get("id", ""),
			"title": m.get("title", ""),
			"blurb": m.get("blurb", ""),
			"theme": "",
			"default_music_suite": m.get("default_music_suite", ""),
			"areas": areas_out,
		})
	return {
		"id": "atlantis",
		"title": "Atlantis",
		"blurb": "",
		"home_area": "",
		"missions": missions_out,
	}


# Reads + parses a JSON file. Returns the parsed value, or null on any error.
func _read_json(path: String):
	if not FileAccess.file_exists(path):
		push_warning("main: missing JSON %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return JSON.parse_string(text)


# === Asset directory scanning =============================================

func _populate_libraries() -> void:
	var maps := _scan_directory(MAPS_DIR, _is_image_file)
	SessionState.set_map_library(maps)
	SessionState.set_map_metadata_library(_load_all_map_metadata(maps))
	# Music: recursive so faction signatures, character themes, location
	# signatures, and mission-suite tracks all surface in the Singles list.
	SessionState.set_music_library(_scan_directory(MUSIC_DIR, _is_audio_file, true))
	SessionState.set_sfx_library(_scan_directory(SFX_DIR, _is_audio_file))
	SessionState.set_music_suites(_scan_music_suites(MISSIONS_MUSIC_DIR))
	SessionState.set_handout_library(_scan_directory(HANDOUTS_DIR, _is_image_file))
	# Lighting anchor table (time-of-day + season). Falls back to built-in
	# defaults in SessionState if the file is absent or malformed.
	var lighting = _read_json("res://assets/lighting.json")
	if lighting is Dictionary:
		SessionState.set_lighting_model(lighting)
	# Physical ambient LEDs (WLED). Disabled unless assets/wled.json opts in;
	# the controller mirrors the scene lighting model onto the play-area strips.
	var wled = _read_json("res://assets/wled.json")
	if wled is Dictionary:
		WLEDController.configure(wled)
	# Philips Hue cardinal spotlights (ZigBee via bridge). Disabled unless
	# assets/hue.json opts in; driven by the physical_lighting_target signal.
	var hue = _read_json("res://assets/hue.json")
	if hue is Dictionary:
		HueController.configure(hue)


# Each map may have a JSON sidecar at <map>.json. Returns { map_path -> dict }
# containing only those maps with a parseable sidecar present.
func _load_all_map_metadata(map_paths: Array) -> Dictionary:
	var out: Dictionary = {}
	for path in map_paths:
		var sidecar := _sidecar_path_for(path)
		if not FileAccess.file_exists(sidecar):
			continue
		var text := FileAccess.get_file_as_string(sidecar)
		if text.is_empty():
			continue
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			var meta: Dictionary = parsed
			# If the sidecar references a sector overlay file, load + parse
			# it now and stash the result in the metadata dict under a
			# private key. The projector + preview read from
			# SessionState.current_sector_overlay (set by SessionState
			# when the map activates), so they never need file access.
			_resolve_sector_overlay(meta, sidecar)
			out[path] = meta
		else:
			push_warning("main: sidecar %s is not a JSON object" % sidecar)
	return out


# Loads the sector overlay file referenced by meta["overlays"]["sectors"]
# (relative to the sidecar's directory or an absolute res:// path) and
# stashes the parsed result back into meta under "__sectors_parsed".
# A missing or malformed file degrades gracefully — the map just renders
# without sectors.
func _resolve_sector_overlay(meta: Dictionary, sidecar_path: String) -> void:
	var overlays: Dictionary = meta.get("overlays", {})
	var sectors_ref: String = overlays.get("sectors", "")
	if sectors_ref == "":
		return
	var sectors_path: String = sectors_ref
	if not sectors_path.begins_with("res://") and not sectors_path.begins_with("user://"):
		sectors_path = sidecar_path.get_base_dir() + "/" + sectors_ref
	if not FileAccess.file_exists(sectors_path):
		push_warning("main: sector overlay %s not found" % sectors_path)
		return
	var text := FileAccess.get_file_as_string(sectors_path)
	if text.is_empty():
		return
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("main: sector overlay %s is not a JSON object" % sectors_path)
		return
	meta["__sectors_parsed"] = parsed


func _sidecar_path_for(map_path: String) -> String:
	var dot := map_path.rfind(".")
	if dot == -1:
		return map_path + ".json"
	return map_path.substr(0, dot) + ".json"


# Returns sorted absolute res:// paths of files passing pred. When recursive
# is true, descends into subdirectories.
func _scan_directory(dir_path: String, pred: Callable, recursive: bool = false) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		# Missing directories aren't fatal — they just mean nothing to load.
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		var child := "%s/%s" % [dir_path, fname]
		if dir.current_is_dir():
			if recursive and not fname.begins_with("."):
				out.append_array(_scan_directory(child, pred, true))
		elif pred.call(fname):
			out.append(child)
		fname = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


# Each immediate subfolder of root is a music suite. Files inside are
# matched to a tier by substring (the first tier word found in the
# lowercased filename wins).
func _scan_music_suites(root: String) -> Dictionary:
	var suites: Dictionary = {}
	var dir := DirAccess.open(root)
	if dir == null:
		return suites
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var suite := _scan_suite_folder("%s/%s" % [root, entry])
			if not suite.is_empty():
				suites[entry] = suite
		entry = dir.get_next()
	dir.list_dir_end()
	return suites


func _scan_suite_folder(folder: String) -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and _is_audio_file(entry):
			var lower := entry.to_lower()
			for tier in SessionState.MUSIC_TIERS:
				if tier in lower:
					out[tier] = "%s/%s" % [folder, entry]
					break
		entry = dir.get_next()
	dir.list_dir_end()
	return out


func _is_image_file(fname: String) -> bool:
	var lower := fname.to_lower()
	return (
		lower.ends_with(".png")
		or lower.ends_with(".jpg")
		or lower.ends_with(".jpeg")
		or lower.ends_with(".webp")
	)


func _is_audio_file(fname: String) -> bool:
	var lower := fname.to_lower()
	return (
		lower.ends_with(".ogg")
		or lower.ends_with(".mp3")
		or lower.ends_with(".wav")
	)
