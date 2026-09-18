extends Node

# SessionState — shared autoload singleton.
#
# The GM control window mutates state via these setters. The projector
# window listens to the signals and reflects state changes. Neither
# window has a direct reference to the other; everything flows through
# this object.
#
# Registered as an autoload via project.godot:
#   [autoload]
#   SessionState="*res://scripts/session_state.gd"
# The leading `*` enables it globally — referenced anywhere as `SessionState`.

# --- Maps (v0.1 / v0.2) ---------------------------------------------------

signal current_map_changed(path: String)
signal hex_grid_visibility_changed(is_visible: bool)
signal map_library_changed(paths: Array)

var current_map_path: String = ""
var hex_grid_visible: bool = false
var map_library: Array = []

# GM-only briefing map (v0.16 UI): a parchment/reference image for the current
# scene, shown on the GM control window (NEVER projected to players). Resolved
# from an explicit scene.briefing, else the "<map>_briefing.png" convention if
# that asset is in the map library. "" = none available for this scene.
signal current_briefing_changed(path: String)
var current_briefing_path: String = ""


func set_current_briefing(path: String) -> void:
	if path == current_briefing_path:
		return
	current_briefing_path = path
	current_briefing_changed.emit(path)


# --- Per-map ambience bed -------------------------------------------------
#
# A looping atmosphere track (underwater rumble, desert wind, cave drone, crowd
# + rain) tied to the map — SEPARATE from the music suite, so externally
# authored music can be dropped in later without touching ambience. Resolved
# from scene.ambience or the sidecar's "ambience"; bare names resolve under
# assets/audio/ambience/. "" = silence.
signal ambience_changed(path: String)
var current_ambience_path: String = ""


func set_current_ambience(path: String) -> void:
	var resolved := path
	if resolved != "" and not (resolved.begins_with("res://") or resolved.begins_with("user://")):
		resolved = "res://assets/audio/ambience/" + resolved
	if resolved == current_ambience_path:
		return
	current_ambience_path = resolved
	ambience_changed.emit(resolved)


# Derive "<map_base>_briefing.png" and use it only if it's a known asset (the map
# library is scanned by main.gd, so this stays filesystem-free here).
func _resolve_briefing_for_map(map_path: String) -> void:
	var dot := map_path.rfind(".")
	var candidate := (map_path + "_briefing.png") if dot == -1 else (map_path.substr(0, dot) + "_briefing.png")
	set_current_briefing(candidate if candidate in map_library else "")

# Projector viewport size — published by the projector on launch and on
# resize. The GM-side MapPreview reads this to compute a world-space
# coordinate from a mouse drag in preview-space.
signal projector_viewport_size_changed(size: Vector2)
var projector_viewport_size: Vector2 = Vector2(1920, 1080)


func set_projector_viewport_size(s: Vector2) -> void:
	if s == projector_viewport_size:
		return
	projector_viewport_size = s
	projector_viewport_size_changed.emit(s)


# --- Physical-table calibration (v0.14) ---------------------------------
#
# A one-time-ish alignment so the DOWN-projected map + hex grid line up with a
# physical grid mat / terrain on the table: pan (offset), scale (zoom), and
# rotate the whole projected image. Applied via the projector's Camera2D.
# Persists with the session (it's a property of the physical rig, not content).
signal projector_calibration_changed(offset: Vector2, zoom: float, rotation_deg: float)

var calibration_offset: Vector2 = Vector2.ZERO   # projector-pixel pan
var calibration_zoom: float = 1.0                # 1.0 = no scale
var calibration_rotation_deg: float = 0.0        # degrees


func _emit_calibration() -> void:
	projector_calibration_changed.emit(calibration_offset, calibration_zoom, calibration_rotation_deg)


func nudge_calibration(delta: Vector2) -> void:
	calibration_offset += delta
	_emit_calibration()


func adjust_calibration_zoom(delta: float) -> void:
	calibration_zoom = clampf(calibration_zoom + delta, 0.25, 4.0)
	_emit_calibration()


func adjust_calibration_rotation(delta_deg: float) -> void:
	calibration_rotation_deg = wrapf(calibration_rotation_deg + delta_deg, -180.0, 180.0)
	_emit_calibration()


func reset_calibration() -> void:
	calibration_offset = Vector2.ZERO
	calibration_zoom = 1.0
	calibration_rotation_deg = 0.0
	_emit_calibration()


# --- Tokens (v0.3) --------------------------------------------------------

signal token_added(id: int, data: Dictionary)
signal token_removed(id: int)
signal token_moved(id: int, world_position: Vector2)
signal token_data_changed(id: int, data: Dictionary)
# The token shown in the inspector / highlighted on the preview (-1 = none).
# Shared so list-selection and preview-click drive the same selection.
signal token_selection_changed(id: int)
var selected_token_id: int = -1


func select_token(id: int) -> void:
	if id == selected_token_id:
		return
	selected_token_id = id
	token_selection_changed.emit(id)

# Token dict shape:
#   { name, color, position, label, size,
#     is_combatant, hp_max, hp_current, fp_max, fp_current, basic_speed,
#     statuses }
#
# Combat fields are GURPS-flavored:
#   - hp / fp are integers; bars colour-band by ratio (yellow ≤ 1/3, red ≤ 0)
#   - basic_speed is a float (5.00 is the GURPS human baseline); initiative
#     order is the combatants sorted descending by basic_speed
#   - statuses is an Array of TOKEN_STATUSES keys, treated as a set
const TOKEN_SIZES: Array[String] = ["small", "medium", "large", "huge"]
const TOKEN_SIZE_MULTIPLIERS := {
	"small": 0.6,
	"medium": 1.0,
	"large": 1.5,
	"huge": 2.0,
}

# GURPS combat status palette. Each status renders as a small coloured disk
# with a one-letter code under the token label. Order here is the order
# they appear in the GM panel checkboxes.
const TOKEN_STATUSES: Array[String] = [
	"stunned", "unconscious", "prone", "bleeding",
	"grappled", "aiming", "all_out_attack", "all_out_defense",
]
const STATUS_DATA := {
	"stunned":         {"display": "Stunned",         "letter": "S", "color": Color(0.95, 0.85, 0.25)},
	"unconscious":     {"display": "Unconscious",     "letter": "U", "color": Color(0.55, 0.55, 0.60)},
	"prone":           {"display": "Prone",           "letter": "P", "color": Color(0.70, 0.50, 0.30)},
	"bleeding":        {"display": "Bleeding",        "letter": "B", "color": Color(0.85, 0.20, 0.20)},
	"grappled":        {"display": "Grappled",        "letter": "G", "color": Color(0.65, 0.35, 0.85)},
	"aiming":          {"display": "Aiming",          "letter": "A", "color": Color(0.30, 0.80, 0.85)},
	"all_out_attack":  {"display": "All-Out Attack",  "letter": "O", "color": Color(0.95, 0.55, 0.20)},
	"all_out_defense": {"display": "All-Out Defense", "letter": "D", "color": Color(0.35, 0.65, 0.95)},
}

const DEFAULT_HP := 10
const DEFAULT_FP := 10
const DEFAULT_BASIC_SPEED := 5.0

# Tokens are MAP-RELATIVE (v0.13): each map keeps its own set, so switching
# maps loads that map's tokens and returns yours when you come back. `tokens`
# is a live reference to the active map's slice; all token setters mutate it,
# so they transparently target the current map. `_next_token_id` stays global
# so ids never collide across maps. Emitted `tokens_reloaded` tells the UI /
# projector to clear and rebuild all token visuals on a map switch.
signal tokens_reloaded
var map_tokens: Dictionary = {"": {}}      # map_key (image path) -> { id -> data }
var tokens: Dictionary = map_tokens[""]    # active map's slice (a reference)
var _active_token_map_key: String = ""
var _next_token_id: int = 1


# Re-point `tokens` to a map's slice on map switch. Called from set_current_map.
func _switch_token_map(key: String) -> void:
	if key == _active_token_map_key:
		return
	_active_token_map_key = key
	if not map_tokens.has(key):
		map_tokens[key] = {}
	tokens = map_tokens[key]
	select_token(-1)
	if is_combat_active:
		_reconcile_combat_order()
	tokens_reloaded.emit()


func token_size_multiplier(size: String) -> float:
	return float(TOKEN_SIZE_MULTIPLIERS.get(size, 1.0))


func status_display(status_id: String) -> Dictionary:
	return STATUS_DATA.get(status_id, {})


# --- Combat (v0.7, reorder + delay v0.12) --------------------------------
#
# Initiative is seeded from combatant tokens sorted by basic_speed desc, then
# becomes an AUTHORITATIVE `combat_order` the GM can hand-tweak (DX tiebreaks
# via move up/down, Delay to drop to the end). The active combatant is tracked
# by id so it survives reorders/HP changes. Outside combat the order is the
# live computed one (get_active_order).

signal combat_state_changed(active: bool)
signal combat_round_changed(round_no: int)
signal active_combatant_changed(token_id: int)
signal combat_order_changed(order: Array)

var is_combat_active: bool = false
var combat_round: int = 0
var active_combatant_id: int = -1
var combat_order: Array = []  # authoritative turn order while combat is active


# Music tier stashed at combat start so end_combat can restore it (v0.10).
var _pre_combat_tier: String = ""


# The music tier combat should switch to: the staged map's on_combat override,
# else the suite's "combat" tier.
func _combat_music_tier() -> String:
	var mp := get_map_in(current_campaign_id, current_staged_mission_id,
		current_staged_area_id, current_staged_map_id)
	var on_combat: Dictionary = mp.get("scene", {}).get("on_combat", {})
	return on_combat.get("music_tier", "combat")


func start_combat() -> void:
	var order := get_combat_order()
	if order.is_empty():
		return
	is_combat_active = true
	combat_round = 1
	combat_order = order.duplicate()  # seed authoritative order from speed
	active_combatant_id = combat_order[0]
	combat_state_changed.emit(true)
	combat_round_changed.emit(combat_round)
	combat_order_changed.emit(combat_order)
	active_combatant_changed.emit(active_combatant_id)
	# Auto-swell the music into combat, remembering the pre-combat tier so we
	# can drop back to it when the fight ends.
	_pre_combat_tier = current_music_tier
	var ct := _combat_music_tier()
	if current_music_suite_id != "" and music_suites.get(current_music_suite_id, {}).has(ct):
		set_current_music_tier(ct)


func end_combat() -> void:
	if not is_combat_active:
		return
	is_combat_active = false
	combat_round = 0
	active_combatant_id = -1
	combat_state_changed.emit(false)
	combat_round_changed.emit(0)
	active_combatant_changed.emit(-1)
	# Restore the pre-combat music tier.
	if _pre_combat_tier != "":
		if current_music_suite_id != "" and music_suites.get(current_music_suite_id, {}).has(_pre_combat_tier):
			set_current_music_tier(_pre_combat_tier)
		_pre_combat_tier = ""


func advance_turn() -> void:
	if not is_combat_active:
		return
	_reconcile_combat_order()
	if combat_order.is_empty():
		end_combat()
		return
	var idx := combat_order.find(active_combatant_id)
	# If the active combatant was removed mid-round, fall back to the first.
	if idx == -1:
		active_combatant_id = combat_order[0]
		active_combatant_changed.emit(active_combatant_id)
		return
	idx += 1
	if idx >= combat_order.size():
		idx = 0
		combat_round += 1
		combat_round_changed.emit(combat_round)
	active_combatant_id = combat_order[idx]
	active_combatant_changed.emit(active_combatant_id)


# Delay: the active combatant drops to the end of the round order, and play
# passes to whoever was next. (GURPS Wait/Delay — act later this round.)
func delay_combatant(id: int) -> void:
	if not is_combat_active or not (id in combat_order):
		return
	var was_active := (id == active_combatant_id)
	var idx := combat_order.find(id)
	var next_id = combat_order[(idx + 1) % combat_order.size()]
	combat_order.erase(id)
	combat_order.append(id)
	combat_order_changed.emit(combat_order)
	if was_active:
		active_combatant_id = next_id if next_id != id else combat_order[0]
		active_combatant_changed.emit(active_combatant_id)


# Manual reorder (DX tiebreaks): shift a combatant up (-1) or down (+1).
func move_combatant(id: int, delta: int) -> void:
	if not is_combat_active:
		return
	var idx := combat_order.find(id)
	var target := idx + delta
	if idx == -1 or target < 0 or target >= combat_order.size():
		return
	combat_order[idx] = combat_order[target]
	combat_order[target] = id
	combat_order_changed.emit(combat_order)


# Keep combat_order in sync with the live combatant set: drop tokens that are
# gone / no longer combatants, append newly-flagged ones (at the end).
func _reconcile_combat_order() -> void:
	if not is_combat_active:
		return
	var live := get_combat_order()
	var changed := false
	var filtered: Array = []
	for id in combat_order:
		if id in live:
			filtered.append(id)
		else:
			changed = true
	for id in live:
		if not (id in filtered):
			filtered.append(id)
			changed = true
	combat_order = filtered
	if changed:
		combat_order_changed.emit(combat_order)


# The order to display/iterate: authoritative order in combat, else live sort.
func get_active_order() -> Array:
	if is_combat_active:
		_reconcile_combat_order()
		return combat_order
	return get_combat_order()


# Token ids in initiative order: combatants sorted by basic_speed desc.
# Stable for equal speeds (preserves insertion order).
func get_combat_order() -> Array:
	var entries: Array = []
	for id in tokens:
		var t: Dictionary = tokens[id]
		if not t.get("is_combatant", false):
			continue
		entries.append({"id": id, "speed": float(t.get("basic_speed", DEFAULT_BASIC_SPEED))})
	entries.sort_custom(func(a, b): return a["speed"] > b["speed"])
	var ids: Array = []
	for e in entries:
		ids.append(e["id"])
	return ids


func toggle_token_status(id: int, status_id: String, on: bool) -> void:
	if not tokens.has(id):
		return
	var statuses: Array = tokens[id].get("statuses", []).duplicate()
	if on and not statuses.has(status_id):
		statuses.append(status_id)
	elif not on and statuses.has(status_id):
		statuses.erase(status_id)
	tokens[id]["statuses"] = statuses
	token_data_changed.emit(id, tokens[id])


# --- Audio (v0.4) ---------------------------------------------------------

signal background_music_changed(path: String)
signal background_music_stopped
signal ambient_sfx_triggered(path: String)

var current_background_music: String = ""

signal music_library_changed(paths: Array)
signal sfx_library_changed(paths: Array)
var music_library: Array = []
var sfx_library: Array = []


func set_music_library(paths: Array) -> void:
	music_library = paths
	music_library_changed.emit(paths)


func set_sfx_library(paths: Array) -> void:
	sfx_library = paths
	sfx_library_changed.emit(paths)


# --- Music suites (v0.5) -------------------------------------------------
#
# The campaign uses a four-tier music doctrine (exploration / civilization
# / combat / boss). A "suite" is a folder of audio files representing one
# location's four tiers. The GM picks a suite, then switches tiers via
# buttons; the AudioController resolves (suite, tier) -> path and
# crossfades. Either variable may be empty, in which case nothing plays
# automatically (matches the existing Singles-only behavior).

const MUSIC_TIERS: Array[String] = ["exploration", "civilization", "combat", "boss"]

signal music_suites_changed(suites: Dictionary)
signal current_music_suite_changed(suite_id: String)
signal current_music_tier_changed(tier: String)

var music_suites: Dictionary = {}  # suite_id -> { tier -> path }
var current_music_suite_id: String = ""
var current_music_tier: String = ""


func set_music_suites(suites: Dictionary) -> void:
	music_suites = suites
	music_suites_changed.emit(suites)
	if current_music_suite_id != "" and not suites.has(current_music_suite_id):
		current_music_suite_id = ""
		current_music_suite_changed.emit("")


func set_current_music_suite(suite_id: String) -> void:
	if suite_id == current_music_suite_id:
		return
	current_music_suite_id = suite_id
	current_music_suite_changed.emit(suite_id)
	var path := _resolve_current_tier_path()
	if path != "":
		set_background_music(path)


func set_current_music_tier(tier: String) -> void:
	current_music_tier = tier
	current_music_tier_changed.emit(tier)
	var path := _resolve_current_tier_path()
	if path != "":
		set_background_music(path)


func _resolve_current_tier_path() -> String:
	if current_music_suite_id == "" or current_music_tier == "":
		return ""
	var suite: Dictionary = music_suites.get(current_music_suite_id, {})
	return suite.get(current_music_tier, "")


# --- Map metadata (per-map hex scale, etc.) -----------------------------
#
# Each map may have a JSON sidecar at `<map>.json` carrying per-map config.
# Recognized keys today:
#   "hex_radius_px": float — overrides DEFAULT_HEX_RADIUS_PX for this map.
# Future: grid origin offset, named regions, ambient tint, etc.

const DEFAULT_HEX_RADIUS_PX := 40.0

signal current_map_metadata_changed(metadata: Dictionary)

# Full-frame backdrop behind the map (e.g. the Atlantis seabed/crater filling the
# 16:9 around the circular city). "" = none (black). map_fit shrinks the map
# below full-viewport fit so it can sit inside the backdrop; 1.0 = normal fit.
signal current_backdrop_changed(path: String)
var current_backdrop_path: String = ""
var current_map_fit: float = 1.0

var map_metadata_library: Dictionary = {}  # map_path -> Dictionary
var current_map_metadata: Dictionary = {}


func set_map_metadata_library(meta: Dictionary) -> void:
	map_metadata_library = meta
	_resolve_current_map_metadata()


func get_current_hex_radius_px() -> float:
	return float(current_map_metadata.get("hex_radius_px", DEFAULT_HEX_RADIUS_PX))


func _resolve_current_map_metadata() -> void:
	var meta: Dictionary = map_metadata_library.get(current_map_path, {})
	# Derived state FIRST, signals after. Godot signals fire synchronously, and
	# the projector's current_map_metadata_changed handler re-fits the map
	# sprites off current_map_fit — so anything it reads must already be the new
	# map's value. Emitting first left every map staged after the home base
	# (assets/maps/atlantis.json, map_fit 0.68) boxed at 68% of the viewport.
	var backdrop: String = str(meta.get("backdrop", ""))
	var backdrop_changed := backdrop != current_backdrop_path
	current_map_fit = float(meta.get("map_fit", 1.0))
	current_backdrop_path = backdrop
	if meta != current_map_metadata:
		current_map_metadata = meta
		current_map_metadata_changed.emit(meta)
	# Per-map ambience bed (sidecar default; a scene's ambience overrides later).
	set_current_ambience(str(meta.get("ambience", "")))
	if backdrop_changed:
		current_backdrop_changed.emit(backdrop)
	# Overlays: sector geometry (already parsed at scan time and stashed in
	# the metadata dict under a private key) and ambient effect list.
	var sectors: Dictionary = meta.get("__sectors_parsed", {})
	set_current_sector_overlay(sectors)
	var overlays: Dictionary = meta.get("overlays", {})
	var ambient: Array = overlays.get("ambient", [])
	# Per-effect config lives at top-level of the sidecar (e.g. "meteor_glow":
	# { position_px, radius_px, color }). Empty dict if absent — effects fall
	# back to defaults.
	var config: Dictionary = {}
	for effect_name in ambient:
		if meta.has(effect_name):
			config[effect_name] = meta[effect_name]
	set_current_ambient_effects(ambient, config)
	# Clear any sector selection — the previous map's sector ids may not
	# exist on the new map.
	select_sector("")


# --- Scene mood (atmosphere: tint + particles) --------------------------
#
# A scene mood bundles a multiplicative color tint over the map with a
# particle preset (snow, embers, etc.). Picked from the GM panel; the
# projector applies both layers.

const SCENE_MOODS := {
	"none": {
		"display": "None",
		"tint": Color(1.0, 1.0, 1.0, 1.0),
		"particles": "none",
	},
	"winter": {
		"display": "Winter (snow + cold blue)",
		"tint": Color(0.78, 0.86, 1.00, 1.0),
		"particles": "snow",
	},
	"forest_dusk": {
		"display": "Forest at Dusk (leaves + amber)",
		"tint": Color(0.95, 0.78, 0.60, 1.0),
		"particles": "leaves",
	},
	"cave": {
		"display": "Cave (dim warm, no particles)",
		"tint": Color(0.60, 0.55, 0.50, 1.0),
		"particles": "none",
	},
	"underwater": {
		"display": "Underwater (cyan-blue)",
		"tint": Color(0.45, 0.75, 0.90, 1.0),
		"particles": "none",
	},
	"volcanic": {
		"display": "Volcanic (embers + red glow)",
		"tint": Color(1.00, 0.65, 0.50, 1.0),
		"particles": "embers",
	},
	"sandstorm": {
		"display": "Sandstorm (dust + sodium)",
		"tint": Color(1.00, 0.82, 0.55, 1.0),
		"particles": "dust",
	},
	"rain": {
		"display": "Rain (rain + grey-blue)",
		"tint": Color(0.72, 0.78, 0.85, 1.0),
		"particles": "rain",
	},
}

signal current_scene_mood_changed(mood_id: String)

var current_scene_mood: String = "none"


func set_current_scene_mood(mood_id: String) -> void:
	if not SCENE_MOODS.has(mood_id):
		mood_id = "none"
	if mood_id == current_scene_mood:
		return
	current_scene_mood = mood_id
	current_scene_mood_changed.emit(mood_id)


func get_current_scene_mood_data() -> Dictionary:
	return SCENE_MOODS.get(current_scene_mood, SCENE_MOODS["none"])


# --- Lighting: time-of-day × season (v0.9) ------------------------------
#
# Two independent knobs, each a continuous phase in [0,1) with four named
# stops. The projector tint = interpolated time-of-day tint (brightness
# folded into RGB) × interpolated season bias. Defaults (noon, spring)
# resolve to ~white, so the scene looks unchanged until the GM moves a
# slider or a staged scene sets a value. See DESIGN.md §3.5.

const TOD_STOPS: Array[String] = ["dawn", "noon", "dusk", "midnight"]
const SEASON_STOPS: Array[String] = ["spring", "summer", "autumn", "winter"]

const TOD_ANCHORS := {
	"dawn":     {"tint": Color(1.00, 0.82, 0.70), "brightness": 0.80},
	"noon":     {"tint": Color(1.00, 1.00, 1.00), "brightness": 1.00},
	"dusk":     {"tint": Color(1.00, 0.78, 0.60), "brightness": 0.82},
	"midnight": {"tint": Color(0.52, 0.60, 0.85), "brightness": 0.50},
}
const SEASON_BIAS := {
	"spring": Color(0.98, 1.02, 0.98),
	"summer": Color(1.03, 1.00, 0.95),
	"autumn": Color(1.05, 0.95, 0.85),
	"winter": Color(0.92, 0.96, 1.06),
}

signal scene_lighting_changed(tint: Color)

var current_time_of_day: float = 0.25  # phase 0..1 — 0.25 = noon
var current_season: float = 0.0        # phase 0..1 — 0.0 = spring

# Cinematic lighting grade (v0.15/v0.16). An extra multiplicative colour +
# energy on top of the tod×season model, plus an additive "bloom" (0..1) for
# bright flashes a multiply can't reach — a "miracle", a lightning strike, a
# door opening onto daylight. All default to neutral (no effect). These are the
# knobs `transition_lighting` tweens; the projector's TintLayer folds grade +
# energy into its tint, a BloomLayer renders the additive wash, and
# WLEDController mirrors both onto the physical LEDs. One model, every surface.
signal scene_bloom_changed(bloom: float)
var current_light_grade: Color = Color(1, 1, 1)
var current_light_energy: float = 1.0
var current_light_bloom: float = 0.0
var _light_tween: Tween

# Physical slow-device lighting target (Hue spots / any ZigBee bulb). The
# projector and WLED take per-frame updates; ZigBee bulbs can't be streamed, so
# they're driven with ONE target colour + a native fade duration. Fired once at
# transition kickoff with the FINAL tint/bloom + duration; instant setters fire
# it with a short default fade. Controllers map tint→bulb colour (+bloom→white).
signal physical_lighting_target(tint: Color, bloom: float, duration: float)
const PHYSICAL_INSTANT_FADE := 0.4  # seconds — gentle bulb fade for one-off changes

# Scene VFX layers (particles + shader effects) declared by the staged scene's
# `effects` list, independent of the legacy mood. Empty = fall back to the
# mood's particle (back-compat). See DESIGN.md §3.5.
signal scene_effects_changed(effects: Array)
var current_scene_effects: Array = []


func set_scene_effects(effects: Array) -> void:
	current_scene_effects = effects
	scene_effects_changed.emit(effects)


# --- Projector events: blackout (v0.10) ---------------------------------
#
# Blackout fades the PROJECTOR to black while the GM tablet keeps showing the
# live scene — so the GM can stage the next beat unseen, then resume to reveal
# it. Purely an overlay; the scene underneath is untouched, so "resume" needs
# no state to restore.
signal blackout_changed(on: bool)
var is_blackout: bool = false


func set_blackout(on: bool) -> void:
	if on == is_blackout:
		return
	is_blackout = on
	blackout_changed.emit(on)


func toggle_blackout() -> void:
	set_blackout(not is_blackout)


# --- Projector events: handout reveals (v0.10) --------------------------
#
# A handout is a full-screen image (a projected character sheet, portrait,
# letter, symbol) shown over the map and faded back to the map on hide. Used
# at discussion beats, not during live exploration (players have paper sheets).
signal handout_library_changed(paths: Array)
signal current_handout_changed(path: String)  # "" = hidden

var handout_library: Array = []
var current_handout: String = ""


func set_handout_library(paths: Array) -> void:
	handout_library = paths
	handout_library_changed.emit(paths)


func reveal_handout(path: String) -> void:
	current_handout = path
	current_handout_changed.emit(path)


func hide_handout() -> void:
	if current_handout == "":
		return
	current_handout = ""
	current_handout_changed.emit("")


# --- Projector events: ping (v0.10) -------------------------------------
#
# A ping is a one-shot pulse at a map location — the projector equivalent of
# pointing. The GM arms ping mode (button / P), then clicks the preview; the
# click emits a ping at that world position instead of dragging a token.
signal ping_emitted(world_pos: Vector2)
signal ping_armed_changed(armed: bool)

var ping_armed: bool = false


func set_ping_armed(armed: bool) -> void:
	if armed == ping_armed:
		return
	ping_armed = armed
	ping_armed_changed.emit(armed)


func emit_ping(world_pos: Vector2) -> void:
	ping_emitted.emit(world_pos)


# --- Event sequences: on_enter runner (v0.10) ---------------------------
#
# A scene's `on_enter` is an ordered list of event steps played automatically
# when the map is staged (DESIGN §5). Each step is one or more primitive
# actions (blackout, reveal_handout, music, ping, lighting, sfx, ...) plus an
# optional `wait_for: "gm_continue"` (hold until the GM taps Continue) and an
# optional trailing `delay_ms`. Always interruptible: staging another map or
# hitting Skip cancels it. A generation counter invalidates the running
# coroutine so a cancelled/superseded run stops at its next checkpoint.
signal sequence_running_changed(running: bool)
signal sequence_waiting_changed(waiting: bool)
signal _sequence_continue  # internal — advances or unblocks a wait_for

var is_sequence_running: bool = false
var is_sequence_waiting: bool = false
var _sequence_gen: int = 0


func run_sequence(steps: Array) -> void:
	cancel_sequence()
	if steps.is_empty():
		return
	_sequence_gen += 1
	var gen := _sequence_gen
	is_sequence_running = true
	sequence_running_changed.emit(true)
	for step in steps:
		if gen != _sequence_gen:
			break
		if not (step is Dictionary):
			continue
		_apply_sequence_step(step)
		if step.get("wait_for", "") == "gm_continue":
			_set_sequence_waiting(true)
			await _sequence_continue
			_set_sequence_waiting(false)
			if gen != _sequence_gen:
				break
		var delay_ms := int(step.get("delay_ms", 0))
		if delay_ms > 0:
			await get_tree().create_timer(delay_ms / 1000.0).timeout
			if gen != _sequence_gen:
				break
	# Only the still-current run clears the flags (a cancel already did).
	if gen == _sequence_gen:
		is_sequence_running = false
		sequence_running_changed.emit(false)
		_set_sequence_waiting(false)


func advance_sequence() -> void:
	if is_sequence_waiting:
		_sequence_continue.emit()


func cancel_sequence() -> void:
	if not is_sequence_running:
		return
	_sequence_gen += 1  # invalidate the running coroutine
	is_sequence_running = false
	sequence_running_changed.emit(false)
	_set_sequence_waiting(false)
	_sequence_continue.emit()  # unblock a pending wait_for


func _set_sequence_waiting(w: bool) -> void:
	if w == is_sequence_waiting:
		return
	is_sequence_waiting = w
	sequence_waiting_changed.emit(w)


func _apply_sequence_step(step: Dictionary) -> void:
	if step.has("blackout"):
		set_blackout(bool(step["blackout"]))
	if step.get("resume", false):
		set_blackout(false)
	if step.has("reveal_handout"):
		reveal_handout(_resolve_handout(str(step["reveal_handout"])))
	if step.get("hide_handout", false):
		hide_handout()
	if step.has("music") and step["music"] is Dictionary:
		var m: Dictionary = step["music"]
		var s: String = m.get("suite", "")
		if s != "" and music_suites.has(s):
			set_current_music_suite(s)
		var t: String = m.get("tier", "")
		if t != "":
			set_current_music_tier(t)
	if step.has("sfx"):
		trigger_ambient_sfx(str(step["sfx"]))
	if step.has("ping") and step["ping"] is Array and step["ping"].size() >= 2:
		emit_ping(Vector2(float(step["ping"][0]), float(step["ping"][1])))
	if step.has("time_of_day"):
		set_time_of_day(phase_for(TOD_STOPS, step["time_of_day"]))
	if step.has("season"):
		set_season(phase_for(SEASON_STOPS, step["season"]))
	# A `lighting` block tweens the cinematic grade/energy/bloom (and optionally
	# tod/season) over duration_ms — the overcast→miracle style transition. The
	# step's own delay_ms should cover the transition if the next beat must wait.
	if step.has("lighting") and step["lighting"] is Dictionary:
		var lt: Dictionary = step["lighting"]
		transition_lighting(lt, float(lt.get("duration_ms", 1500)) / 1000.0)
	if step.has("mood"):
		set_current_scene_mood(str(step["mood"]))
	if step.has("effects") and step["effects"] is Array:
		set_scene_effects(step["effects"])


func _resolve_handout(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
	return "res://assets/handouts/" + path


func set_time_of_day(phase: float) -> void:
	phase = fposmod(phase, 1.0)
	if is_equal_approx(phase, current_time_of_day):
		return
	current_time_of_day = phase
	scene_lighting_changed.emit(compute_scene_tint())
	physical_lighting_target.emit(compute_scene_tint(), current_light_bloom, PHYSICAL_INSTANT_FADE)


func set_season(phase: float) -> void:
	phase = fposmod(phase, 1.0)
	if is_equal_approx(phase, current_season):
		return
	current_season = phase
	scene_lighting_changed.emit(compute_scene_tint())
	physical_lighting_target.emit(compute_scene_tint(), current_light_bloom, PHYSICAL_INSTANT_FADE)


# Accepts a named stop ("dusk") or a raw phase float; returns a phase in [0,1).
func phase_for(stops: Array, name_or_phase) -> float:
	if name_or_phase is String:
		var i := stops.find(name_or_phase)
		return float(i) / stops.size() if i >= 0 else 0.0
	return fposmod(float(name_or_phase), 1.0)


# Nearest named stop for a phase — for labeling the sliders.
func nearest_stop(stops: Array, phase: float) -> String:
	var n := stops.size()
	var idx := int(round(fposmod(phase, 1.0) * n)) % n
	return stops[idx]


func _ring_sample(stops: Array, phase: float) -> Dictionary:
	var n := stops.size()
	var scaled := fposmod(phase, 1.0) * n
	var lo_i := int(floor(scaled)) % n
	var hi_i := (lo_i + 1) % n
	return {"lo": stops[lo_i], "hi": stops[hi_i], "t": scaled - floor(scaled)}


# Optional data-driven override of the anchor tables, loaded from
# assets/lighting.json by main.gd. Empty = use the built-in TOD_ANCHORS /
# SEASON_BIAS constants above.
var _lighting_override: Dictionary = {}


func _arr_to_color(a) -> Color:
	if a is Array and a.size() >= 3:
		var alpha: float = float(a[3]) if a.size() >= 4 else 1.0
		return Color(float(a[0]), float(a[1]), float(a[2]), alpha)
	return Color(1, 1, 1, 1)


# Parse a lighting.json model (tints as [r,g,b] arrays) into an override table.
# Malformed / partial input degrades gracefully to the built-in defaults.
func set_lighting_model(model: Dictionary) -> void:
	var out := {"time_of_day": {}, "season": {}}
	for stop in model.get("time_of_day", {}):
		var e = model["time_of_day"][stop]
		if e is Dictionary:
			out["time_of_day"][stop] = {
				"tint": _arr_to_color(e.get("tint", [1, 1, 1])),
				"brightness": float(e.get("brightness", 1.0)),
			}
	for stop in model.get("season", {}):
		var e = model["season"][stop]
		if e is Dictionary:
			out["season"][stop] = _arr_to_color(e.get("tint_bias", [1, 1, 1]))
	_lighting_override = out
	scene_lighting_changed.emit(compute_scene_tint())


func _tod_anchor(stop: String) -> Dictionary:
	return _lighting_override.get("time_of_day", {}).get(stop, TOD_ANCHORS[stop])


func _season_anchor(stop: String) -> Color:
	return _lighting_override.get("season", {}).get(stop, SEASON_BIAS[stop])


func compute_scene_tint() -> Color:
	return _tint_for(current_time_of_day, current_season, current_light_grade, current_light_energy)


# Pure lighting math for an explicit state. Lets transition_lighting compute the
# FINAL tint up front — so slow physical devices (Hue / any ZigBee bulb, which
# can't be streamed per-frame) get ONE target colour + a native fade duration
# instead of 60 commands a second — without mutating the live state.
func _tint_for(tod_phase: float, season_phase: float, grade: Color, energy: float) -> Color:
	var tod := _ring_sample(TOD_STOPS, tod_phase)
	var a := _tod_anchor(tod["lo"])
	var b := _tod_anchor(tod["hi"])
	var tint: Color = (a["tint"] as Color).lerp(b["tint"], tod["t"])
	var bright: float = lerp(float(a["brightness"]), float(b["brightness"]), tod["t"])
	var s := _ring_sample(SEASON_STOPS, season_phase)
	var bias: Color = _season_anchor(s["lo"]).lerp(_season_anchor(s["hi"]), s["t"])
	return Color(
		tint.r * bright * bias.r * grade.r * energy,
		tint.g * bright * bias.g * grade.g * energy,
		tint.b * bright * bias.b * grade.b * energy,
		1.0)


# --- Cinematic lighting transitions (v0.15) -----------------------------
#
# Smoothly tween the whole lighting model to a target over `duration` seconds,
# re-emitting scene_lighting_changed (+ scene_bloom_changed) every frame so the
# projector tint AND the physical LEDs move together — no hard snap. This is the
# ONE entry point authored scenes and the GM use for "the sun breaks through",
# "night falls", "the miracle". `target` keys (all optional; absent = hold):
#   time_of_day / season : named stop ("noon") or a raw phase float
#   grade                : [r,g,b] extra multiplicative colour
#   energy               : float overall multiplier (1 = neutral)
#   bloom                : 0..1 additive white flash
# tod/season interpolate along the SHORTEST arc of their ring; grade/energy/
# bloom interpolate linearly. duration<=0 applies instantly.
func transition_lighting(target: Dictionary, duration: float = 1.5) -> void:
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()

	var from_tod := current_time_of_day
	var to_tod := phase_for(TOD_STOPS, target["time_of_day"]) if target.has("time_of_day") else from_tod
	var from_season := current_season
	var to_season := phase_for(SEASON_STOPS, target["season"]) if target.has("season") else from_season
	var from_grade := current_light_grade
	var to_grade := _arr_to_color(target["grade"]) if target.has("grade") else from_grade
	var from_energy := current_light_energy
	var to_energy := float(target.get("energy", from_energy))
	var from_bloom := current_light_bloom
	var to_bloom := float(target.get("bloom", from_bloom))

	# Hand slow physical devices the FINAL state + fade duration up front, so a
	# Hue spot fades itself natively instead of being streamed per frame.
	physical_lighting_target.emit(_tint_for(to_tod, to_season, to_grade, to_energy), to_bloom, maxf(duration, 0.0))

	if duration <= 0.0:
		_apply_lighting_state(to_tod, to_season, to_grade, to_energy, to_bloom)
		return

	_light_tween = create_tween()
	_light_tween.tween_method(
		func(t: float) -> void:
			_apply_lighting_state(
				_ring_lerp(from_tod, to_tod, t),
				_ring_lerp(from_season, to_season, t),
				from_grade.lerp(to_grade, t),
				lerp(from_energy, to_energy, t),
				lerp(from_bloom, to_bloom, t)),
		0.0, 1.0, duration)


# Instantly set the cinematic grade (no tween) — e.g. to establish an "overcast"
# base before transitioning into a "miracle".
func set_light_grade(grade: Color, energy: float = 1.0, bloom: float = 0.0) -> void:
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
	_apply_lighting_state(current_time_of_day, current_season, grade, energy, bloom)
	physical_lighting_target.emit(compute_scene_tint(), current_light_bloom, PHYSICAL_INSTANT_FADE)


func _apply_lighting_state(tod: float, season: float, grade: Color, energy: float, bloom: float) -> void:
	current_time_of_day = fposmod(tod, 1.0)
	current_season = fposmod(season, 1.0)
	current_light_grade = grade
	current_light_energy = energy
	scene_lighting_changed.emit(compute_scene_tint())
	if not is_equal_approx(bloom, current_light_bloom):
		current_light_bloom = bloom
		scene_bloom_changed.emit(bloom)


# Shortest-arc interpolation on a [0,1) ring (so dawn→midnight can go either way,
# whichever is nearer). t in [0,1].
func _ring_lerp(from: float, to: float, t: float) -> float:
	var d := to - from
	d -= floor(d + 0.5)  # wrap delta into [-0.5, 0.5) → nearest direction
	return fposmod(from + d * t, 1.0)


# --- Sector overlays + facility progression (v0.8) ----------------------
#
# Sector overlays attach to a map via the sidecar `overlays.sectors`
# field (a path to a sector-definition JSON). The overlay carries
# polygon geometry, names, and per-tier art keyed by sector id.
#
# Facility state (the *campaign* progression — what tier each sector is
# at, TP balance, owned Research Upgrades) is independent of which map
# is loaded. The two join at render time: the overlay says "here are
# the sectors and their art per tier"; facility_state says "sector I-1
# is currently at tier 2." Persisted separately so editing campaign
# state doesn't touch asset files.

const SECTOR_DEFAULT_TIER := 1
const FACILITY_FILE := "user://facility_state.json"      # legacy (pre-v0.9) global file
const CAMPAIGN_FILE := "user://campaign.json"            # v0.9: per-campaign facility

signal current_sector_overlay_changed(overlay: Dictionary)
signal current_ambient_effects_changed(effects: Array)
signal facility_state_changed
signal sector_tier_changed(sector_id: String, tier: int)
signal sector_selection_changed(sector_id: String)  # "" for cleared

var current_sector_overlay: Dictionary = {}  # parsed sector JSON, or {}
var current_ambient_effects: Array = []      # active effect names for current map
var current_ambient_config: Dictionary = {}  # per-effect tunables from sidecar
var current_selected_sector_id: String = ""

# Facility progression is PER-CAMPAIGN (v0.9): each campaign has its own TP /
# RUs / sector tiers, so the Calibration testbed can't clobber Atlantis.
# `campaign_states` holds every campaign's slice keyed by id; `facility_state`
# is a live reference to the ACTIVE campaign's slice (re-pointed by
# set_current_campaign). All the facility getters/setters below operate on
# `facility_state`, so they transparently target whichever campaign is active.
var campaign_states: Dictionary = {}   # campaign_id -> {tp_balance, ru_owned, sectors}
var facility_state: Dictionary = _default_facility()


func _default_facility() -> Dictionary:
	return {"tp_balance": 0, "ru_owned": [], "sectors": {}}


# Fetch (creating if needed) a campaign's facility slice, with defensive
# defaults so a hand-edited or older file missing keys never crashes.
func facility_for_campaign(campaign_id: String) -> Dictionary:
	if not campaign_states.has(campaign_id):
		campaign_states[campaign_id] = _default_facility()
	var slice: Dictionary = campaign_states[campaign_id]
	if not slice.has("sectors"): slice["sectors"] = {}
	if not slice.has("ru_owned"): slice["ru_owned"] = []
	if not slice.has("tp_balance"): slice["tp_balance"] = 0
	return slice


# Switch the active campaign: re-point facility_state at that campaign's slice
# and refresh the facility UI. This is how facility follows the staged campaign.
func set_current_campaign(campaign_id: String) -> void:
	if campaign_id == "":
		return
	if campaign_id == current_campaign_id and campaign_states.has(campaign_id):
		return
	current_campaign_id = campaign_id
	facility_state = facility_for_campaign(campaign_id)
	facility_state_changed.emit()


func set_current_sector_overlay(overlay: Dictionary) -> void:
	if overlay == current_sector_overlay:
		return
	current_sector_overlay = overlay
	current_sector_overlay_changed.emit(overlay)


func set_current_ambient_effects(effects: Array, config: Dictionary = {}) -> void:
	# Always re-publish so per-map config changes (intensity, position, ...)
	# also reach the projector, even when the effect-name set is unchanged.
	current_ambient_effects = effects
	current_ambient_config = config
	current_ambient_effects_changed.emit(effects)


func select_sector(sector_id: String) -> void:
	if sector_id == current_selected_sector_id:
		return
	current_selected_sector_id = sector_id
	sector_selection_changed.emit(sector_id)


func get_sector_tier(sector_id: String) -> int:
	var entry: Dictionary = facility_state.get("sectors", {}).get(sector_id, {})
	return int(entry.get("tier", SECTOR_DEFAULT_TIER))


func is_sector_upgrading(sector_id: String) -> bool:
	var entry: Dictionary = facility_state.get("sectors", {}).get(sector_id, {})
	return bool(entry.get("upgrading", false))


func _sector_entry(sector_id: String) -> Dictionary:
	if not facility_state.has("sectors"):
		facility_state["sectors"] = {}
	var sectors: Dictionary = facility_state["sectors"]
	if not sectors.has(sector_id):
		sectors[sector_id] = {"tier": SECTOR_DEFAULT_TIER, "upgrading": false}
	return sectors[sector_id]


func set_sector_tier(sector_id: String, tier: int) -> void:
	var entry := _sector_entry(sector_id)
	var clamped: int = clamp(tier, 1, 3)
	if entry.get("tier", -1) == clamped:
		return
	entry["tier"] = clamped
	facility_state["sectors"][sector_id] = entry
	sector_tier_changed.emit(sector_id, clamped)
	facility_state_changed.emit()


func set_sector_upgrading(sector_id: String, upgrading: bool) -> void:
	var entry := _sector_entry(sector_id)
	if bool(entry.get("upgrading", false)) == upgrading:
		return
	entry["upgrading"] = upgrading
	facility_state["sectors"][sector_id] = entry
	facility_state_changed.emit()


func adjust_tp(delta: int) -> void:
	facility_state["tp_balance"] = int(facility_state.get("tp_balance", 0)) + delta
	facility_state_changed.emit()


func add_ru(ru_id: String) -> void:
	var owned: Array = facility_state.get("ru_owned", []).duplicate()
	if owned.has(ru_id):
		return
	owned.append(ru_id)
	facility_state["ru_owned"] = owned
	facility_state_changed.emit()


func remove_ru(ru_id: String) -> void:
	var owned: Array = facility_state.get("ru_owned", []).duplicate()
	if not owned.has(ru_id):
		return
	owned.erase(ru_id)
	facility_state["ru_owned"] = owned
	facility_state_changed.emit()


func save_facility_state() -> void:
	# Persist ALL campaigns' facility slices (campaign_states) to campaign.json.
	# facility_state is a live reference into that dict, so it's already current.
	var f := FileAccess.open(CAMPAIGN_FILE, FileAccess.WRITE)
	if f == null:
		push_warning("SessionState: failed to open %s for writing" % CAMPAIGN_FILE)
		return
	f.store_string(JSON.stringify(campaign_states, "  "))
	f.close()


func load_facility_state() -> void:
	# Load per-campaign facility. Migration: if the new file is absent but the
	# legacy global facility_state.json exists, fold it in under "atlantis".
	if FileAccess.file_exists(CAMPAIGN_FILE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CAMPAIGN_FILE))
		if parsed is Dictionary:
			campaign_states = parsed
		else:
			push_warning("SessionState: %s is not a valid campaign state" % CAMPAIGN_FILE)
	elif FileAccess.file_exists(FACILITY_FILE):
		var legacy = JSON.parse_string(FileAccess.get_file_as_string(FACILITY_FILE))
		if legacy is Dictionary:
			campaign_states = {"atlantis": legacy}
			push_warning("SessionState: migrated legacy facility_state.json -> campaign.json[atlantis]")
	# Re-point the active slice at whatever campaign is current (with defaults).
	facility_state = facility_for_campaign(current_campaign_id if current_campaign_id != "" else "atlantis")
	facility_state_changed.emit()


# --- Missions + locations (v0.9) ----------------------------------------
#
# Missions are authored as a tree of small JSON files under
# assets/missions/ (index -> per-mission manifest -> per-location leaf).
# main.gd scans + parses them at boot and seeds the in-memory `missions`
# array here, so this autoload never touches the filesystem. Each mission:
#   { id, title, blurb, default_music_suite, locations: [
#       { id, title, staging: { map, music{suite,tier}, mood, hex_grid, ... } } ] }
#
# Selecting a location applies its staging — the whole stage (map, music,
# mood, hex) in one call — by composing the individual setters above.

signal missions_changed(missions: Array)
signal location_staged(mission_id: String, location_id: String)

var missions: Array = []
var current_staged_mission_id: String = ""
var current_staged_location_id: String = ""


func set_missions(list: Array) -> void:
	missions = list
	missions_changed.emit(list)


func get_mission(mission_id: String) -> Dictionary:
	for m in missions:
		if m is Dictionary and m.get("id", "") == mission_id:
			return m
	return {}


# Apply a location's staging record: swap map, music (suite+tier), scene
# mood, and hex visibility in one shot. `default_suite` is the mission's
# default music suite, used when the location doesn't name its own.
func apply_location_staging(mission_id: String, location_id: String, staging: Dictionary, default_suite: String) -> void:
	var map_path: String = staging.get("map", "")
	if map_path != "":
		set_current_map(map_path)
	var music: Dictionary = staging.get("music", {})
	var suite: String = music.get("suite", default_suite)
	if suite != "" and music_suites.has(suite):
		set_current_music_suite(suite)
	var tier: String = music.get("tier", "")
	if tier != "":
		set_current_music_tier(tier)
	if staging.has("mood"):
		set_current_scene_mood(staging.get("mood", "none"))
	if staging.has("hex_grid"):
		set_hex_grid_visible(bool(staging.get("hex_grid")))
	current_staged_mission_id = mission_id
	current_staged_location_id = location_id
	location_staged.emit(mission_id, location_id)


# --- Campaign -> Mission -> Area -> Map tree (v0.9) ----------------------
#
# The upgraded content model (DESIGN.md §2-3). main.gd scans the campaigns/
# tree (or shims the legacy missions/ tree into a synthetic "atlantis"
# campaign) and seeds `campaigns` here. An Area holds one or more adjacent
# Maps; each Map carries a `scene` block. Staging a Map applies its scene.
# Shape:
#   [{ id, title, blurb, home_area, missions: [
#       { id, title, blurb, theme, default_music_suite, areas: [
#           { id, title, gm_notes, maps: [
#               { id, title, adjacent: [], scene: {...} } ] } ] } ] }]

signal campaigns_changed(campaigns: Array)
signal map_staged(campaign_id: String, mission_id: String, area_id: String, map_id: String)

var campaigns: Array = []
var current_campaign_id: String = ""
var current_staged_area_id: String = ""
var current_staged_map_id: String = ""


func set_campaigns(list: Array) -> void:
	campaigns = list
	if current_campaign_id == "":
		for c in list:
			if c is Dictionary:
				set_current_campaign(c.get("id", ""))
				break
	campaigns_changed.emit(list)


func get_campaign(campaign_id: String) -> Dictionary:
	for c in campaigns:
		if c is Dictionary and c.get("id", "") == campaign_id:
			return c
	return {}


func get_mission_in(campaign_id: String, mission_id: String) -> Dictionary:
	for m in get_campaign(campaign_id).get("missions", []):
		if m is Dictionary and m.get("id", "") == mission_id:
			return m
	return {}


func get_area_in(campaign_id: String, mission_id: String, area_id: String) -> Dictionary:
	for a in get_mission_in(campaign_id, mission_id).get("areas", []):
		if a is Dictionary and a.get("id", "") == area_id:
			return a
	return {}


func get_map_in(campaign_id: String, mission_id: String, area_id: String, map_id: String) -> Dictionary:
	for mp in get_area_in(campaign_id, mission_id, area_id).get("maps", []):
		if mp is Dictionary and mp.get("id", "") == map_id:
			return mp
	return {}


# Apply a scene block: swap map/region, music, hex, and atmosphere in one
# shot. Accepts both new-format (`image`, `time_of_day`, `season`, `effects`)
# and legacy (`map`, `mood`) keys so the shimmed old content works unchanged.
func apply_scene(scene: Dictionary, default_suite: String = "") -> void:
	var image: String = scene.get("image", scene.get("map", ""))
	if image != "":
		set_current_map(image)  # also sets the convention briefing (may be "")
	# An explicit GM briefing map overrides the "<map>_briefing.png" convention.
	# Bare filenames resolve against the maps dir; res://user:// paths pass through.
	if scene.has("briefing"):
		var b: String = str(scene.get("briefing", ""))
		if b != "" and not (b.begins_with("res://") or b.begins_with("user://")):
			b = "res://assets/maps/" + b
		set_current_briefing(b)
	# Scene ambience overrides the sidecar default (set by set_current_map above).
	if scene.has("ambience"):
		set_current_ambience(str(scene.get("ambience", "")))
	var music: Dictionary = scene.get("music", {})
	var suite: String = music.get("suite", default_suite)
	if suite != "" and music_suites.has(suite):
		set_current_music_suite(suite)
	var tier: String = music.get("tier", "")
	if tier != "":
		set_current_music_tier(tier)
	if scene.has("hex_grid"):
		set_hex_grid_visible(bool(scene.get("hex_grid")))
	# Atmosphere: new-format time-of-day/season take precedence; legacy mood
	# still honored for shimmed content (effects wiring lands in a later step).
	if scene.has("time_of_day"):
		set_time_of_day(phase_for(TOD_STOPS, scene.get("time_of_day")))
	if scene.has("season"):
		set_season(phase_for(SEASON_STOPS, scene.get("season")))
	if scene.has("mood"):
		set_current_scene_mood(scene.get("mood", "none"))
	# Author-time access to the cinematic grade (v0.15), which until now only
	# existed at runtime via transition_lighting. Needed because some plates are
	# pre-lit: a relit "after hours" map already carries its own darkness, and
	# multiplying the midnight grade on top of it crushes the frame to black.
	# `light_energy` scales the whole tint (1.0 = as-authored, >1 lifts a plate
	# back out of a night grade); `light_grade` is an optional [r,g,b] multiply.
	# Both reset to neutral when absent, so scenes can't leak grade to each other.
	var grade := Color(1, 1, 1)
	if scene.has("light_grade"):
		var g = scene.get("light_grade")
		if g is Array and (g as Array).size() >= 3:
			grade = Color(float(g[0]), float(g[1]), float(g[2]))
		elif g is String:
			grade = Color(str(g))
	set_light_grade(grade, float(scene.get("light_energy", 1.0)))
	# New-format scenes declare VFX explicitly; legacy scenes (no key) reset to
	# empty so the mood's particle takes over.
	set_scene_effects(scene.get("effects", []))
	# Positioned ambient lights (torches / candles / braziers / fireplaces) —
	# new-format only. Only touch ambient effects when the scene declares a
	# `lights` key, so legacy sidecar-driven effects (meteor_glow) are untouched.
	if scene.has("lights"):
		var amb: Array = []
		var amb_cfg: Dictionary = {}
		var lights = scene.get("lights", [])
		if lights is Array and not lights.is_empty():
			amb.append("firelight")
			amb_cfg["firelight"] = {
				"lights": lights,
				"flicker": scene.get("flicker", 0.4),
				"speed": scene.get("flicker_speed", 9.0),
			}
		set_current_ambient_effects(amb, amb_cfg)


# Stage a specific Map: look it up in the tree, apply its scene, record the
# staged path. No-op if the map isn't found (fail-soft).
func stage_map(campaign_id: String, mission_id: String, area_id: String, map_id: String) -> void:
	var mp := get_map_in(campaign_id, mission_id, area_id, map_id)
	if mp.is_empty():
		push_warning("stage_map: not found %s/%s/%s/%s" % [campaign_id, mission_id, area_id, map_id])
		return
	var mission := get_mission_in(campaign_id, mission_id)
	apply_scene(mp.get("scene", {}), mission.get("default_music_suite", ""))
	set_current_campaign(campaign_id)
	current_staged_mission_id = mission_id
	current_staged_area_id = area_id
	current_staged_map_id = map_id
	map_staged.emit(campaign_id, mission_id, area_id, map_id)
	# Play the scene's authored entrance sequence, if any (DESIGN §5).
	var on_enter = mp.get("scene", {}).get("on_enter", [])
	if on_enter is Array and not on_enter.is_empty():
		run_sequence(on_enter)


# --- Persistence --------------------------------------------------------
#
# Session state is saved to user://session.json on graceful quit and
# restored on launch. Restore happens after the asset libraries are
# scanned so saved paths can be validated against what's on disk; stale
# entries are silently dropped.

const SESSION_FILE := "user://session.json"


func save_session() -> void:
	var data := {
		"current_map_path": current_map_path,
		"hex_grid_visible": hex_grid_visible,
		"current_music_suite_id": current_music_suite_id,
		"current_music_tier": current_music_tier,
		"current_scene_mood": current_scene_mood,
		"current_time_of_day": current_time_of_day,
		"current_season": current_season,
		"calibration_offset_x": calibration_offset.x,
		"calibration_offset_y": calibration_offset.y,
		"calibration_zoom": calibration_zoom,
		"calibration_rotation_deg": calibration_rotation_deg,
		"map_tokens": _serialize_map_tokens(),
		"next_token_id": _next_token_id,
		"is_combat_active": is_combat_active,
		"combat_round": combat_round,
		"active_combatant_id": active_combatant_id,
		"current_campaign_id": current_campaign_id,
		"current_staged_mission_id": current_staged_mission_id,
		"current_staged_area_id": current_staged_area_id,
		"current_staged_map_id": current_staged_map_id,
	}
	var f := FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if f == null:
		push_warning("SessionState: failed to open %s for writing" % SESSION_FILE)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()


func load_session() -> void:
	if not FileAccess.file_exists(SESSION_FILE):
		return
	var text := FileAccess.get_file_as_string(SESSION_FILE)
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("SessionState: %s is not a valid session" % SESSION_FILE)
		return
	var data: Dictionary = parsed

	_restore_map_tokens(data.get("map_tokens", data.get("tokens", [])), int(data.get("next_token_id", 1)))

	set_hex_grid_visible(bool(data.get("hex_grid_visible", false)))

	var saved_map: String = data.get("current_map_path", "")
	if saved_map != "" and saved_map in map_library:
		set_current_map(saved_map)

	var saved_suite: String = data.get("current_music_suite_id", "")
	if saved_suite != "" and music_suites.has(saved_suite):
		set_current_music_suite(saved_suite)
	var saved_tier: String = data.get("current_music_tier", "")
	if saved_tier != "":
		set_current_music_tier(saved_tier)

	var saved_mood: String = data.get("current_scene_mood", "none")
	set_current_scene_mood(saved_mood)

	set_time_of_day(float(data.get("current_time_of_day", 0.25)))
	set_season(float(data.get("current_season", 0.0)))

	calibration_offset = Vector2(
		float(data.get("calibration_offset_x", 0.0)),
		float(data.get("calibration_offset_y", 0.0)))
	calibration_zoom = float(data.get("calibration_zoom", 1.0))
	calibration_rotation_deg = float(data.get("calibration_rotation_deg", 0.0))
	_emit_calibration()

	# Restore combat state. Validate active_combatant_id against the live
	# token set so stale ids (token removed between sessions) don't strand
	# the rail on a ghost.
	if bool(data.get("is_combat_active", false)):
		var saved_round: int = int(data.get("combat_round", 1))
		var saved_active: int = int(data.get("active_combatant_id", -1))
		var order := get_combat_order()
		if not order.is_empty():
			is_combat_active = true
			combat_round = saved_round if saved_round > 0 else 1
			active_combatant_id = saved_active if order.has(saved_active) else order[0]
			combat_state_changed.emit(true)
			combat_round_changed.emit(combat_round)
			active_combatant_changed.emit(active_combatant_id)

	# Restore the staged Campaign->Mission->Area->Map path if it still resolves
	# against the scanned tree. We only re-mark it (emit map_staged so the panel
	# shows it) — the live map/music/lighting were already restored above, so we
	# don't re-apply the authored scene and clobber any live GM adjustments.
	var s_campaign: String = data.get("current_campaign_id", "")
	var s_mission: String = data.get("current_staged_mission_id", "")
	var s_area: String = data.get("current_staged_area_id", "")
	var s_map: String = data.get("current_staged_map_id", "")
	if s_campaign != "" and not get_map_in(s_campaign, s_mission, s_area, s_map).is_empty():
		set_current_campaign(s_campaign)
		current_staged_mission_id = s_mission
		current_staged_area_id = s_area
		current_staged_map_id = s_map
		map_staged.emit(s_campaign, s_mission, s_area, s_map)


func _serialize_map_tokens() -> Dictionary:
	var out: Dictionary = {}
	for key in map_tokens:
		out[key] = _serialize_token_dict(map_tokens[key])
	return out


func _serialize_token_dict(d: Dictionary) -> Array:
	var out: Array = []
	for id in d:
		var t: Dictionary = d[id]
		var pos: Vector2 = t.get("position", Vector2.ZERO)
		var color: Color = t.get("color", Color.WHITE)
		out.append({
			"id": id,
			"name": t.get("name", ""),
			"label": t.get("label", t.get("name", "")),
			"size": t.get("size", "medium"),
			"color": [color.r, color.g, color.b, color.a],
			"position_x": pos.x,
			"position_y": pos.y,
			"is_combatant": t.get("is_combatant", false),
			"hp_max": t.get("hp_max", DEFAULT_HP),
			"hp_current": t.get("hp_current", DEFAULT_HP),
			"fp_max": t.get("fp_max", DEFAULT_FP),
			"fp_current": t.get("fp_current", DEFAULT_FP),
			"basic_speed": t.get("basic_speed", DEFAULT_BASIC_SPEED),
			"statuses": t.get("statuses", []),
		})
	return out


# Rebuild all maps' token sets from a saved payload. Accepts the new format
# ({ map_key: [tokens] }) and the legacy flat list (put under the "" map).
# Bulk-loads without per-token signals; tokens_reloaded rebuilds the active
# map's visuals.
func _restore_map_tokens(saved, next_id: int) -> void:
	map_tokens = {"": {}}
	if saved is Dictionary:
		for key in saved:
			map_tokens[key] = _token_dict_from_json(saved[key])
	elif saved is Array:
		map_tokens[""] = _token_dict_from_json(saved)
	if not map_tokens.has(""):
		map_tokens[""] = {}
	_active_token_map_key = ""
	tokens = map_tokens[""]
	_next_token_id = max(next_id, _next_token_id)
	tokens_reloaded.emit()


func _token_dict_from_json(arr) -> Dictionary:
	var d: Dictionary = {}
	if not (arr is Array):
		return d
	for raw in arr:
		if not (raw is Dictionary):
			continue
		var t: Dictionary = raw
		var color_arr: Array = t.get("color", [1, 1, 1, 1])
		if color_arr.size() < 4:
			continue
		var color := Color(color_arr[0], color_arr[1], color_arr[2], color_arr[3])
		var pos := Vector2(t.get("position_x", 0.0), t.get("position_y", 0.0))
		var id: int = int(t.get("id", _next_token_id))
		d[id] = {
			"name": t.get("name", ""),
			"label": t.get("label", t.get("name", "")),
			"size": t.get("size", "medium"),
			"color": color,
			"position": pos,
			"is_combatant": bool(t.get("is_combatant", false)),
			"hp_max": int(t.get("hp_max", DEFAULT_HP)),
			"hp_current": int(t.get("hp_current", DEFAULT_HP)),
			"fp_max": int(t.get("fp_max", DEFAULT_FP)),
			"fp_current": int(t.get("fp_current", DEFAULT_FP)),
			"basic_speed": float(t.get("basic_speed", DEFAULT_BASIC_SPEED)),
			"statuses": t.get("statuses", []),
		}
	return d


# Request a re-scan of the asset directories. Main listens and re-runs
# its directory scans.
signal library_refresh_requested

func request_library_refresh() -> void:
	library_refresh_requested.emit()


# === Map state ============================================================

func set_current_map(path: String) -> void:
	if path == current_map_path:
		return
	current_map_path = path
	_switch_token_map(path)  # load this map's own token set
	current_map_changed.emit(path)
	_resolve_current_map_metadata()
	# Default the GM briefing to the <map>_briefing.png convention (if that asset
	# exists). apply_scene overrides this with an explicit scene.briefing.
	_resolve_briefing_for_map(path)


func set_hex_grid_visible(is_vis: bool) -> void:
	if is_vis == hex_grid_visible:
		return
	hex_grid_visible = is_vis
	hex_grid_visibility_changed.emit(is_vis)


func set_map_library(paths: Array) -> void:
	map_library = paths
	map_library_changed.emit(paths)


# === Token state ==========================================================

func add_token(token_name: String, color: Color, position: Vector2 = Vector2.ZERO) -> int:
	var id := _next_token_id
	_next_token_id += 1
	tokens[id] = {
		"name": token_name,
		"color": color,
		"position": position,
		"label": token_name,
		"size": "medium",
		"is_combatant": false,
		"hp_max": DEFAULT_HP,
		"hp_current": DEFAULT_HP,
		"fp_max": DEFAULT_FP,
		"fp_current": DEFAULT_FP,
		"basic_speed": DEFAULT_BASIC_SPEED,
		"statuses": [],
	}
	token_added.emit(id, tokens[id])
	return id


func move_token(id: int, world_position: Vector2) -> void:
	if not tokens.has(id):
		return
	tokens[id]["position"] = world_position
	token_moved.emit(id, world_position)


func update_token(id: int, updates: Dictionary) -> void:
	if not tokens.has(id):
		return
	for key in updates:
		tokens[id][key] = updates[key]
	token_data_changed.emit(id, tokens[id])


func remove_token(id: int) -> void:
	if not tokens.has(id):
		return
	tokens.erase(id)
	if id == selected_token_id:
		select_token(-1)
	combat_order.erase(id)
	token_removed.emit(id)
	# If the active combatant was just removed, advance to the next so the
	# rail doesn't point at a ghost. If they were the last combatant left,
	# end combat cleanly.
	if is_combat_active and id == active_combatant_id:
		if combat_order.is_empty():
			end_combat()
		else:
			active_combatant_id = combat_order[0]
			active_combatant_changed.emit(active_combatant_id)
	if is_combat_active:
		combat_order_changed.emit(combat_order)


# === Audio state ==========================================================

func set_background_music(path: String) -> void:
	current_background_music = path
	background_music_changed.emit(path)


func stop_background_music() -> void:
	current_background_music = ""
	background_music_stopped.emit()


func trigger_ambient_sfx(path: String) -> void:
	ambient_sfx_triggered.emit(path)
