extends Node

# HueController — drives Philips Hue RGB spotlights from the scene lighting model.
#
# The rig has four Hue spots at the cardinal points (N/E/S/W) around the play
# area. Like WLEDController, this mirrors the app's virtual lighting onto them —
# but Hue (ZigBee) is a fundamentally different surface from the LED strips:
#
#   * WLED can be STREAMED per-frame over UDP (60 fps of pixels).
#   * Hue is ZigBee mesh — ~100-300ms latency, and the bridge rate-limits to
#     ~10 commands/sec/light. You must NOT stream it.
#
# So Hue is driven by the "set target + native fade" model: on a lighting
# change we send ONE PUT per light carrying the destination colour + a
# `transitiontime`, and the BULB interpolates itself. That's why SessionState
# has a dedicated `physical_lighting_target(tint, bloom, duration)` signal that
# fires once per transition — not the per-frame `scene_lighting_changed` WLED
# and the projector consume. One lighting model; each surface driven the way it
# wants to be.
#
# Registered as an autoload AFTER SessionState (see project.godot):
#   SessionState="*res://scripts/session_state.gd"
#   WLEDController="*res://scripts/wled_controller.gd"
#   HueController="*res://scripts/hue_controller.gd"
#
# Uses the Hue local REST API v1 (plain HTTP — no TLS, no cert dance):
#   PUT http://<bridge>/api/<app_key>/lights/<id>/state
#   body {"on":true,"bri":1..254,"xy":[x,y],"transitiontime":<deciseconds>}
#
# SHIPS DISABLED. With no assets/hue.json (or enabled=false) it's fully inert:
# no timers, no network, every handler early-returns. Point it at a bridge by
# writing assets/hue.json (see configure()). This is a v0.17 FOUNDATION — wiring,
# config, colour conversion, and the ambient + directional API are in; pairing a
# real bridge (get an app key via the link-button flow) is the remaining step.

# --- Config ---------------------------------------------------------------

var _enabled: bool = false
var _bridge: String = ""     # bridge IP/hostname
var _app_key: String = ""    # whitelisted application key (link-button pairing)
var _default_fade_ms: int = 400
var _max_bri: int = 254

# All lights the ambient wash drives (cardinals + any extra `lights`), and the
# direction→id map for directional effects (set_cardinal). Values are Hue light
# ids (strings, as the v1 API uses).
var _all_ids: Array = []
var _cardinals: Dictionary = {}  # "north"/"east"/"south"/"west" -> id

# Per-light HTTP state: id -> { req: HTTPRequest, busy: bool, pending: Dictionary }
# Dedicated request per light so the four fade in parallel; pending coalesces a
# newer target that arrives while a PUT is in flight.
var _lights: Dictionary = {}

var _last_tint: Color = Color(1, 1, 1)
var _bloom: float = 0.0


func _ready() -> void:
	SessionState.physical_lighting_target.connect(_on_physical_target)
	SessionState.blackout_changed.connect(_on_blackout_changed)


# Apply a parsed assets/hue.json config. Fail-soft. Shape:
#   {
#     "enabled": true,
#     "bridge_host": "192.168.1.20",
#     "app_key": "<40-char application key from the link-button pairing>",
#     "cardinals": { "north": "1", "east": "2", "south": "3", "west": "4" },
#     "lights": [],                 // extra ids beyond the cardinals (optional)
#     "default_transition_ms": 400,
#     "max_bri": 254
#   }
func configure(cfg: Dictionary) -> void:
	# Tear down any previous per-light request nodes (configure may re-run on a
	# library refresh).
	for entry in _lights.values():
		if entry["req"] != null:
			entry["req"].queue_free()
	_lights.clear()

	_enabled = bool(cfg.get("enabled", false))
	_bridge = str(cfg.get("bridge_host", ""))
	_app_key = str(cfg.get("app_key", ""))
	_default_fade_ms = int(cfg.get("default_transition_ms", 400))
	_max_bri = clampi(int(cfg.get("max_bri", 254)), 1, 254)

	_cardinals = {}
	var cards: Dictionary = cfg.get("cardinals", {})
	for dir in ["north", "east", "south", "west"]:
		var id = cards.get(dir, "")
		if str(id) != "":
			_cardinals[dir] = str(id)

	# The full driven set = cardinals + any extra lights, de-duped.
	var id_set: Dictionary = {}
	for id in _cardinals.values():
		id_set[id] = true
	for id in cfg.get("lights", []):
		id_set[str(id)] = true
	_all_ids = id_set.keys()

	if not _enabled or _bridge == "" or _app_key == "" or _all_ids.is_empty():
		_enabled = false
		printerr("[hue] disabled (no config, or missing bridge/app_key/lights)")
		return

	# One HTTPRequest per light.
	for id in _all_ids:
		var req := HTTPRequest.new()
		add_child(req)
		var entry := {"req": req, "busy": false, "pending": {}}
		req.request_completed.connect(_on_light_completed.bind(id))
		_lights[id] = entry

	printerr("[hue] enabled bridge=", _bridge, " lights=", _all_ids.size(),
		" cardinals=", _cardinals.keys())
	probe_config()


# GET the bridge config — a non-fatal reachability + auth check.
func probe_config() -> void:
	if not _enabled:
		return
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(
		func(_r, code, _h, body):
			if code == 200:
				var info = JSON.parse_string(body.get_string_from_utf8())
				if info is Dictionary and info.has("name"):
					printerr("[hue] connected: bridge '", info.get("name", "?"),
						"' api=", info.get("apiversion", "?"))
				else:
					# A 200 with an error array usually means a bad app key.
					printerr("[hue] reachable but auth may be wrong: ", body.get_string_from_utf8().substr(0, 120))
			else:
				printerr("[hue] probe failed, http=", code)
			req.queue_free()
	)
	req.request("http://%s/api/%s/config" % [_bridge, _app_key], [], HTTPClient.METHOD_GET)


# === Public API ===========================================================

# Set one light to an RGB colour at a fade duration (seconds). bri is derived
# from the colour's value (the scene tint folds brightness into RGB).
func set_light(id: String, color: Color, fade_s: float = -1.0) -> void:
	if not _enabled or not _lights.has(id):
		return
	var ms := _default_fade_ms if fade_s < 0.0 else int(fade_s * 1000.0)
	_queue_light(id, _state_for(color, ms))


# Drive one cardinal direction — the directional-glow primitive shared in spirit
# with WLEDController.set_edge_glow. Not yet wired to a signal; here so directional
# effects (light the side the on-screen sun/torch faces) have an API to build on.
func set_cardinal(direction: String, color: Color, fade_s: float = -1.0) -> void:
	if not _enabled or not _cardinals.has(direction):
		return
	set_light(_cardinals[direction], color, fade_s)


# Set every driven light to one colour — the ambient wash.
func set_all(color: Color, fade_s: float = -1.0) -> void:
	if not _enabled:
		return
	for id in _all_ids:
		set_light(id, color, fade_s)


# === Signal handlers ======================================================

# The lighting model reached a new target. Fade all spots to it over `duration`
# (the bulb interpolates natively — no streaming). Bloom lerps toward white,
# mirroring the projector's additive BloomLayer + WLED.
func _on_physical_target(tint: Color, bloom: float, duration: float) -> void:
	_last_tint = tint
	_bloom = clampf(bloom, 0.0, 1.0)
	if not _enabled:
		return
	set_all(tint.lerp(Color.WHITE, _bloom), duration)


func _on_blackout_changed(on: bool) -> void:
	if not _enabled:
		return
	if on:
		for id in _all_ids:
			_queue_light(id, {"on": false, "transitiontime": _ms_to_deci(_default_fade_ms)})
	else:
		set_all(_last_tint.lerp(Color.WHITE, _bloom), _default_fade_ms / 1000.0)


# === HTTP plumbing ========================================================

# Build a Hue v1 state dict from an RGB colour + fade (ms).
func _state_for(color: Color, fade_ms: int) -> Dictionary:
	var xy := _rgb_to_xy(color)
	var value: float = max(color.r, max(color.g, color.b))
	var bri := clampi(int(round(value * _max_bri)), 1, _max_bri)
	return {
		"on": value > 0.001,
		"bri": bri,
		"xy": xy,
		"transitiontime": _ms_to_deci(fade_ms),
	}


func _queue_light(id: String, state: Dictionary) -> void:
	var entry: Dictionary = _lights.get(id, {})
	if entry.is_empty():
		return
	if entry["busy"]:
		entry["pending"] = state  # keep only the latest; older frames are stale
		return
	_send_light(id, state)


func _send_light(id: String, state: Dictionary) -> void:
	var entry: Dictionary = _lights[id]
	entry["busy"] = true
	entry["pending"] = {}
	var url := "http://%s/api/%s/lights/%s/state" % [_bridge, _app_key, id]
	var req: HTTPRequest = entry["req"]
	var err := req.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PUT, JSON.stringify(state))
	if err != OK:
		entry["busy"] = false
		push_warning("[hue] PUT failed to start for light %s: %s" % [id, err])


func _on_light_completed(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray, id: String) -> void:
	var entry: Dictionary = _lights.get(id, {})
	if entry.is_empty():
		return
	entry["busy"] = false
	# A newer target arrived mid-flight — send it now.
	if not entry["pending"].is_empty():
		_send_light(id, entry["pending"])


# === Colour conversion ====================================================

# RGB (0..1) → CIE xy for the Hue "Wide RGB D65" gamut, with sRGB gamma. This is
# the conversion Philips documents for the v1 API's `xy` field.
func _rgb_to_xy(c: Color) -> Array:
	var r := _gamma(c.r)
	var g := _gamma(c.g)
	var b := _gamma(c.b)
	var x := r * 0.649926 + g * 0.103455 + b * 0.197109
	var y := r * 0.234327 + g * 0.743075 + b * 0.022598
	var z := r * 0.000000 + g * 0.053077 + b * 1.035763
	var sum := x + y + z
	if sum <= 0.0:
		return [0.3127, 0.3290]  # D65 white as a safe fallback
	return [x / sum, y / sum]


func _gamma(v: float) -> float:
	return pow((v + 0.055) / 1.055, 2.4) if v > 0.04045 else v / 12.92


func _ms_to_deci(ms: int) -> int:
	# Hue transitiontime is in deciseconds (100ms units).
	return maxi(0, int(round(ms / 100.0)))
