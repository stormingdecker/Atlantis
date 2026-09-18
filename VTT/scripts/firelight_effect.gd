class_name FirelightEffect
extends Node2D
# Flickering additive radial glows — torches, candles, braziers, fireplaces.
# Positions/colours come from the staged scene's `lights` list (wired through
# SessionState.apply_scene -> the "firelight" ambient config). Each light
# flickers independently via layered sine noise, so the warm pool breathes like
# a real flame. Driven by _process delta, hence deterministic under --fixed-fps
# (movie capture). Modelled on projector.gd's MeteorGlowEffect, but multi-point
# and flickering rather than a single slow pulse.

const DEFAULT_RADIUS_PX := 160.0
const DEFAULT_COLOR := Color(1.0, 0.60, 0.26, 1.0)

var _lights: Array = []            # Array[Dictionary]: sprite, position_px, radius_px, color, seed
var _flicker: float = 0.4          # 0 = steady, 1 = wild
var _speed: float = 9.0
var _tex: Texture2D
var _tex_size: Vector2 = Vector2.ZERO
var _scale: float = 1.0
var _time: float = 0.0

func _ready() -> void:
	if _tex == null:
		_tex = _build_radial_texture()
	set_process(true)

func apply_config(cfg: Dictionary) -> void:
	if _tex == null:
		_tex = _build_radial_texture()
	if cfg.has("flicker"):
		_flicker = clampf(float(cfg["flicker"]), 0.0, 1.0)
	if cfg.has("speed"):
		_speed = float(cfg["speed"])
	# Rebuild the light sprites to match the config.
	for l in _lights:
		if l["sprite"] != null:
			l["sprite"].queue_free()
	_lights.clear()
	var defs: Array = cfg.get("lights", [])
	var i := 0
	for d in defs:
		if not (d is Dictionary):
			continue
		var color := DEFAULT_COLOR
		var col = d.get("color", [])
		if col is Array and col.size() >= 3:
			var a := 1.0 if col.size() < 4 else float(col[3])
			color = Color(float(col[0]), float(col[1]), float(col[2]), a)
		var pos := Vector2.ZERO
		var p = d.get("position_px", [])
		if p is Array and p.size() >= 2:
			pos = Vector2(float(p[0]), float(p[1]))
		var spr := Sprite2D.new()
		spr.centered = true
		spr.texture = _tex
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		spr.material = mat
		spr.modulate = color
		add_child(spr)
		_lights.append({
			"sprite": spr,
			"position_px": pos,
			"radius_px": float(d.get("radius_px", DEFAULT_RADIUS_PX)),
			"color": color,
			"seed": float(i) * 7.531,
		})
		i += 1
	_relayout()

func apply_map_transform(tex_size: Vector2, scale_factor: float) -> void:
	_tex_size = tex_size
	_scale = scale_factor
	_relayout()

func _process(delta: float) -> void:
	_time += delta
	for l in _lights:
		var spr: Sprite2D = l["sprite"]
		if spr == null:
			continue
		var t: float = _time * _speed + float(l["seed"])
		# Layered sines → organic, non-obviously-repeating flame flicker.
		var n: float = 0.6 * sin(t) + 0.3 * sin(t * 2.37 + 1.3) + 0.1 * sin(t * 5.11 + 4.2)
		var amp: float = _flicker * 0.5
		var a: float = clampf(1.0 - amp + amp * (0.5 + 0.5 * n), 0.05, 1.0)
		var base: float = _base_scale(float(l["radius_px"]))
		var s: float = base * (1.0 + 0.10 * _flicker * n)
		var c: Color = l["color"]
		spr.modulate = Color(c.r, c.g, c.b, c.a * a)
		spr.scale = Vector2(s, s)

func _relayout() -> void:
	for l in _lights:
		var spr: Sprite2D = l["sprite"]
		if spr == null:
			continue
		if _tex_size.x > 0.0 and _tex_size.y > 0.0:
			spr.position = (Vector2(l["position_px"]) - _tex_size * 0.5) * _scale
		else:
			spr.position = Vector2.ZERO
		var base: float = _base_scale(float(l["radius_px"]))
		spr.scale = Vector2(base, base)

func _base_scale(radius_px: float) -> float:
	# The radial texture is 256 px in diameter; scale so its rendered radius
	# matches the configured world radius (radius_px * world scale).
	return (radius_px * _scale) / 128.0

func _build_radial_texture() -> Texture2D:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size * 0.5, size * 0.5)
	var max_r := float(size) * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x, y).distance_to(c)
			var tt: float = clampf(1.0 - d / max_r, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(tt, 2.2)))
	return ImageTexture.create_from_image(img)
