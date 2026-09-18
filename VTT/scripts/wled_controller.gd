extends Node

# WLEDController — drives physical ambient LEDs from the scene lighting model.
#
# The projector rig has a WLED controller (ESP32 + addressable strips) forming
# a square above the play area. This autoload mirrors the app's *virtual*
# lighting onto those *physical* LEDs, so the room's ambient light matches the
# map on the table — daylight, dungeon gloom, a torch's warm pool, the flash of
# a "miracle". It is the physical extension of the same lighting model that
# tints the projector (SessionState.compute_scene_tint), keeping ONE source of
# truth: the app owns lighting, the LEDs are just another output.
#
# Registered as an autoload AFTER SessionState (see project.godot) so the
# signal hub exists when we connect in _ready:
#   [autoload]
#   SessionState="*res://scripts/session_state.gd"
#   WLEDController="*res://scripts/wled_controller.gd"
#
# --- Two control tiers ----------------------------------------------------
#
# Tier 1 — presets / solid state over HTTP (kno.wled.ge/interfaces/json-api).
#   A single POST to http://<host>/json/state sets power, master brightness,
#   and a solid segment colour (or a named preset). Cheap, robust, and enough
#   for "make the room match the map's overall light". Bursts (slider drags)
#   are coalesced by a throttle timer so we never flood the ESP32.
#
# Tier 2 — realtime per-pixel over UDP (DDP / WLED-native DNRGB).
#   The app renders a colour PER LED and streams it each frame, so the app —
#   not WLED's built-in effect engine — drives caustics shimmer, a day/night
#   sweep, or DIRECTIONAL glow (light only the west edge because the on-screen
#   sun/torch is to the west). While a realtime stream is active WLED yields
#   pixel authority to us, which is exactly the "app owns lighting" principle.
#   WLED reverts to its normal state `realtime_timeout` seconds after the last
#   packet, so a steady frame cadence must be kept while an effect is live.
#
# --- Safety / current status ----------------------------------------------
#
# SHIPS DISABLED. With no `enabled` config (assets/wled.json absent or
# enabled=false) this node is fully inert: no timers, no _process, and every
# handler early-returns before touching the network. That keeps it harmless on
# the dev box (no hardware) and in the headless test harnesses. Point it at a
# real controller by writing assets/wled.json (see configure()).
#
# This is a v0.16 FOUNDATION: the wiring, config, packet formats, and public
# API are in place; the realtime protocols still need validating against real
# hardware (marked HARDWARE-TODO below). See DESIGN.md §8 (v0.16).

# --- Config ---------------------------------------------------------------

var _enabled: bool = false
var _host: String = ""            # IP or hostname of the WLED controller
var _resolved_ip: String = ""     # host resolved to an IP (for UDP)
var _http_port: int = 80

# Realtime (Tier 2) config.
var _rt_enabled: bool = false
var _rt_protocol: String = "ddp"  # "ddp" | "dnrgb"
var _rt_port: int = 4048          # DDP default 4048; DNRGB uses 21324
var _rt_fps: float = 30.0
var _rt_timeout_s: int = 2        # WLED reverts to normal this long after last packet

# Physical layout: total LED count and the per-edge counts of the square,
# walked clockwise from the top-left. Lets directional effects address one
# edge (e.g. "glow from the west") without the caller knowing the wiring.
var _led_count: int = 0
var _edges: Dictionary = {"top": 0, "right": 0, "bottom": 0, "left": 0}

# --- Tier 1 throttle state ------------------------------------------------

const HTTP_MIN_INTERVAL_MS := 100  # ≤10 state POSTs/sec, coalesced
var _http: HTTPRequest
var _http_busy: bool = false
var _pending_state: Dictionary = {}   # latest state waiting to be flushed
var _pending_dirty: bool = false
var _flush_timer: Timer

# --- Tier 2 realtime state ------------------------------------------------

var _udp: PacketPeerUDP
var _pixels: PackedColorArray = PackedColorArray()  # current frame, one per LED
var _rt_dirty: bool = false
var _rt_accum: float = 0.0
var _rt_seq: int = 0

# Last scene tint + bloom, so either signal can recompute the room colour. The
# "miracle" bloom lerps the whole strip toward white (physical equivalent of the
# projector's additive BloomLayer).
var _last_tint: Color = Color(1, 1, 1)
var _bloom: float = 0.0


func _ready() -> void:
	# Connect to the lighting model unconditionally — cheap, and lets a runtime
	# enable() start working without a reconnect. Handlers guard on _enabled.
	SessionState.scene_lighting_changed.connect(_on_scene_lighting_changed)
	SessionState.scene_bloom_changed.connect(_on_scene_bloom_changed)
	SessionState.blackout_changed.connect(_on_blackout_changed)

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)

	_flush_timer = Timer.new()
	_flush_timer.wait_time = HTTP_MIN_INTERVAL_MS / 1000.0
	_flush_timer.one_shot = false
	_flush_timer.timeout.connect(_flush_pending_state)
	add_child(_flush_timer)

	set_process(false)  # only runs while a realtime stream is active


# Apply a parsed assets/wled.json config. Fail-soft: unknown/partial input
# degrades to disabled. Called by main.gd after the asset scan. Shape:
#   {
#     "enabled": true,
#     "host": "192.168.1.50",        // IP preferred; hostname resolved once
#     "http_port": 80,
#     "led_count": 60,
#     "layout": { "top": 15, "right": 15, "bottom": 15, "left": 15 },
#     "realtime": {
#       "enabled": true,
#       "protocol": "ddp",           // "ddp" | "dnrgb"
#       "port": 4048,
#       "fps": 30,
#       "timeout_s": 2
#     }
#   }
func configure(cfg: Dictionary) -> void:
	_enabled = bool(cfg.get("enabled", false))
	_host = str(cfg.get("host", ""))
	_http_port = int(cfg.get("http_port", 80))
	_led_count = int(cfg.get("led_count", 0))

	var layout: Dictionary = cfg.get("layout", {})
	for edge in _edges:
		_edges[edge] = int(layout.get(edge, 0))
	# If edges are given but led_count isn't, derive it from the perimeter.
	if _led_count == 0:
		_led_count = int(_edges["top"]) + int(_edges["right"]) + int(_edges["bottom"]) + int(_edges["left"])
	_pixels.resize(_led_count)
	_pixels.fill(Color.BLACK)

	var rt: Dictionary = cfg.get("realtime", {})
	_rt_enabled = bool(rt.get("enabled", false))
	_rt_protocol = str(rt.get("protocol", "ddp")).to_lower()
	_rt_port = int(rt.get("port", 4048 if _rt_protocol == "ddp" else 21324))
	_rt_fps = maxf(1.0, float(rt.get("fps", 30.0)))
	_rt_timeout_s = int(rt.get("timeout_s", 2))

	if not _enabled or _host == "":
		_enabled = false
		set_process(false)
		printerr("[wled] disabled (no config or enabled=false)")
		return

	# Resolve a hostname (e.g. "wled.local") to an IP for UDP. HTTP can use the
	# hostname directly, but PacketPeerUDP.set_dest_address needs an IP.
	_resolved_ip = _host
	if not _host.is_valid_ip_address():
		var ip := IP.resolve_hostname(_host, IP.TYPE_ANY)
		if ip != "":
			_resolved_ip = ip
		else:
			push_warning("[wled] could not resolve host '%s'; UDP realtime disabled" % _host)
			_rt_enabled = false

	printerr("[wled] enabled host=", _host, " leds=", _led_count,
		" realtime=", _rt_enabled, "/", _rt_protocol)
	probe_info()          # confirm we can reach the controller
	if _rt_enabled:
		_start_realtime()


# GET /json/info — a non-fatal reachability check that logs the controller's
# name and LED count so the operator can confirm wiring at boot.
func probe_info() -> void:
	if not _enabled:
		return
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(
		func(_r, code, _h, body):
			if code == 200:
				var info = JSON.parse_string(body.get_string_from_utf8())
				if info is Dictionary:
					var leds: Dictionary = info.get("leds", {})
					printerr("[wled] connected: '", info.get("name", "?"),
						"' fw=", info.get("ver", "?"), " leds=", leds.get("count", "?"))
			else:
				printerr("[wled] probe failed, http=", code)
			req.queue_free()
	)
	req.request(_json_url("/json/info"), [], HTTPClient.METHOD_GET)


# === Tier 1 — HTTP state / presets ========================================

# Set the whole strip to one colour at the given brightness (0..1). The scene
# tint already folds brightness into RGB, so callers typically pass bri=1.0 and
# let the colour carry it.
func apply_solid_color(color: Color, bri: float = 1.0) -> void:
	if not _enabled:
		return
	var b := int(clampf(bri, 0.0, 1.0) * 255.0)
	_queue_state({
		"on": b > 0,
		"bri": maxi(b, 1),
		"seg": [{"col": [[_u8(color.r), _u8(color.g), _u8(color.b)]]}],
	})


func set_power(on: bool) -> void:
	if not _enabled:
		return
	_queue_state({"on": on})


# Switch WLED into a saved preset (its own effect/palette). The canned path for
# per-map ambiance — e.g. a "caustics" preset for water maps.
func apply_preset(preset_id: int) -> void:
	if not _enabled:
		return
	_queue_state({"ps": preset_id})


# Coalesce rapid updates: stash the latest state and let the throttle timer
# flush at most one request per HTTP_MIN_INTERVAL_MS. Merges partial states so
# a colour change followed by a power change both survive to the next flush.
func _queue_state(state: Dictionary) -> void:
	_pending_state.merge(state, true)
	_pending_dirty = true
	if _flush_timer.is_stopped():
		_flush_timer.start()
	# Fire the first update immediately for snappy response; the timer handles
	# the tail of a burst.
	if not _http_busy:
		_flush_pending_state()


func _flush_pending_state() -> void:
	if not _pending_dirty or _http_busy or not _enabled:
		if not _pending_dirty:
			_flush_timer.stop()
		return
	var body := JSON.stringify(_pending_state)
	_pending_state = {}
	_pending_dirty = false
	_http_busy = true
	var err := _http.request(
		_json_url("/json/state"),
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body)
	if err != OK:
		_http_busy = false
		push_warning("[wled] state POST failed to start: %s" % err)


func _on_http_completed(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_http_busy = false
	# A newer state may have arrived while this request was in flight.
	if _pending_dirty:
		_flush_pending_state()


# === Tier 2 — realtime UDP streaming ======================================

func _start_realtime() -> void:
	if not _rt_enabled:
		return
	_udp = PacketPeerUDP.new()
	_udp.set_dest_address(_resolved_ip, _rt_port)
	set_process(true)
	printerr("[wled] realtime streaming -> ", _resolved_ip, ":", _rt_port, " @ ", _rt_fps, "fps")


# Set the full frame (one colour per LED). Marks the frame dirty; the next
# _process tick sends it. Extra/missing entries are clamped to _led_count.
func set_pixels(pixels: PackedColorArray) -> void:
	if not _rt_enabled:
		return
	for i in mini(pixels.size(), _led_count):
		_pixels[i] = pixels[i]
	_rt_dirty = true


# Fill the whole square with one colour (realtime path).
func fill(color: Color) -> void:
	if not _rt_enabled:
		return
	_pixels.fill(color)
	_rt_dirty = true


# Light a single edge of the square ("top"/"right"/"bottom"/"left"), leaving
# the rest dark — the primitive behind directional glow. Edges are laid out
# clockwise from the top-left corner. Not yet wired to a signal; it's here so
# directional effects (sun/torch from a direction) have an API to build on.
func set_edge_glow(edge: String, color: Color, clear_rest: bool = true) -> void:
	if not _rt_enabled:
		return
	if clear_rest:
		_pixels.fill(Color.BLACK)
	var start := 0
	for e in ["top", "right", "bottom", "left"]:
		var n := int(_edges[e])
		if e == edge:
			for i in range(start, mini(start + n, _led_count)):
				_pixels[i] = color
			break
		start += n
	_rt_dirty = true


func _process(delta: float) -> void:
	# Stream at the configured cadence. We resend even when not dirty so WLED's
	# realtime timeout never trips mid-scene (it reverts to normal otherwise).
	_rt_accum += delta
	var interval := 1.0 / _rt_fps
	if _rt_accum < interval:
		return
	_rt_accum = 0.0
	_send_frame()


func _send_frame() -> void:
	if _udp == null or _led_count == 0:
		return
	var packet: PackedByteArray
	if _rt_protocol == "dnrgb":
		packet = _build_dnrgb_packet(_pixels)
	else:
		packet = _build_ddp_packet(_pixels)
	_udp.put_packet(packet)
	_rt_dirty = false


# DDP (Distributed Display Protocol) packet: 10-byte header + RGB payload.
# HARDWARE-TODO: validate the data-type byte against the live controller; WLED
# largely ignores it and copies the payload as RGB, but some firmwares are picky.
func _build_ddp_packet(pixels: PackedColorArray) -> PackedByteArray:
	var n := pixels.size()
	var payload_len := n * 3
	var p := PackedByteArray()
	p.resize(10 + payload_len)
	p[0] = 0x41            # flags: version 1 (0x40) | PUSH (0x01)
	p[1] = _rt_seq & 0x0F  # sequence 0..15 (0 = ignored by receivers)
	p[2] = 0x01            # data type: RGB, 8 bits/channel
	p[3] = 0x01            # output/destination id
	# data offset (bytes) — 32-bit big-endian, 0 = start of strip
	p[4] = 0; p[5] = 0; p[6] = 0; p[7] = 0
	# data length — 16-bit big-endian
	p[8] = (payload_len >> 8) & 0xFF
	p[9] = payload_len & 0xFF
	var o := 10
	for c in pixels:
		p[o] = _u8(c.r); p[o + 1] = _u8(c.g); p[o + 2] = _u8(c.b)
		o += 3
	_rt_seq = (_rt_seq + 1) & 0x0F
	return p


# WLED-native DNRGB realtime UDP: [proto=4][timeout_s][start_hi][start_lo] then
# RGB per LED. Handles >255 LEDs (unlike the older WARLS/DRGB). One packet here
# (start index 0); split into multiple if a strip ever exceeds ~490 LEDs/packet.
func _build_dnrgb_packet(pixels: PackedColorArray) -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(4 + pixels.size() * 3)
	p[0] = 4                          # protocol: DNRGB
	p[1] = _rt_timeout_s & 0xFF       # realtime hold time (seconds)
	p[2] = 0; p[3] = 0                # start LED index (16-bit big-endian) = 0
	var o := 4
	for c in pixels:
		p[o] = _u8(c.r); p[o + 1] = _u8(c.g); p[o + 2] = _u8(c.b)
		o += 3
	return p


# === Signal handlers (the "app owns lighting" bridge) =====================

# The scene tint changed (time-of-day / season / lighting model). Mirror it to
# the room: Tier 2 fills every LED with the tint for a smooth per-frame match;
# otherwise Tier 1 pushes a single solid colour.
func _on_scene_lighting_changed(tint: Color) -> void:
	_last_tint = tint
	if not _enabled:
		return
	_push_room_color()


# Bloom (0..1) — a bright flash. Lerp the room toward white by the bloom amount,
# the physical twin of the projector's additive BloomLayer.
func _on_scene_bloom_changed(bloom: float) -> void:
	_bloom = clampf(bloom, 0.0, 1.0)
	if not _enabled:
		return
	_push_room_color()


func _push_room_color() -> void:
	var room := _last_tint.lerp(Color.WHITE, _bloom)
	if _rt_enabled:
		fill(room)
	else:
		apply_solid_color(room)


# Projector blackout — kill the room lights too so a staged reveal stays unseen,
# then restore on resume. (Restore currently re-reads the scene tint; a future
# pass can stash/restore the exact prior frame.)
func _on_blackout_changed(on: bool) -> void:
	if not _enabled:
		return
	if on:
		if _rt_enabled:
			fill(Color.BLACK)
		else:
			set_power(false)
	else:
		_last_tint = SessionState.compute_scene_tint()
		_push_room_color()


# === Helpers ==============================================================

func _json_url(path: String) -> String:
	return "http://%s:%d%s" % [_host, _http_port, path]


func _u8(v: float) -> int:
	return int(clampf(v, 0.0, 1.0) * 255.0)
