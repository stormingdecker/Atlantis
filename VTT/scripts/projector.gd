extends Node2D

# Projector display root.
#
# Lives inside the secondary Window node spawned by Main. Reads state
# from the SessionState autoload and renders:
#   - The current map, fit to viewport, with crossfade transitions.
#   - An optional pointy-top hex grid overlay.
#   - Tokens at their world positions.
#
# Coordinate system: world origin (0,0) is centered on the viewport via a
# Camera2D. The map sprite, hex overlay, and token layer all draw around
# the origin.

const CROSSFADE_DURATION := 1.5  # seconds

var camera: Camera2D
var sprite_a: Sprite2D  # active map
var sprite_b: Sprite2D  # incoming map during crossfade
var ambient_under_layer: AmbientLayer  # caustics — modulates the map
var sector_overlay: SectorOverlay      # sector polygons + labels
var ambient_over_layer: AmbientLayer   # meteor glow — sits above sectors
var tint_layer: TintLayer
var particle_layer: ParticleLayer
var bloom_layer: BloomLayer
var backdrop_layer: BackdropLayer
var hex_overlay: HexOverlay
var token_layer: Node2D
var initiative_rail: InitiativeRail
var ping_layer: PingLayer
var handout_layer: HandoutLayer
var blackout_layer: BlackoutLayer

var token_visuals: Dictionary = {}  # id -> TokenVisual

var _crossfade_tween: Tween


func _ready() -> void:
	# Blank projector starts black so "no map loaded" looks intentional.
	RenderingServer.set_default_clear_color(Color.BLACK)

	# Full-frame backdrop (e.g. the Atlantis seabed/crater) BEHIND the map, so a
	# smaller-than-viewport map (map_fit < 1) reads as nestled in a wider scene.
	backdrop_layer = BackdropLayer.new()
	add_child(backdrop_layer)

	sprite_a = Sprite2D.new()
	sprite_a.centered = true
	add_child(sprite_a)

	sprite_b = Sprite2D.new()
	sprite_b.centered = true
	sprite_b.modulate = Color(1, 1, 1, 0)
	add_child(sprite_b)

	# Layer order (back → front):
	#   sprite_a / sprite_b        the map
	#   ambient_under_layer        caustics — multiplied over the map
	#   sector_overlay             tinted polygons + labels for sectors
	#   ambient_over_layer         meteor glow — additive on top of sectors
	#   tint_layer                 multiplicative scene-mood tint
	#   particle_layer             snow / rain / leaves / ...
	#   hex_overlay                pointy-top grid
	#   token_layer                tokens with HP/FP/statuses
	#   initiative_rail            screen-locked combat rail
	ambient_under_layer = AmbientLayer.new()
	ambient_under_layer.role = AmbientLayer.ROLE_UNDER
	add_child(ambient_under_layer)
	sector_overlay = SectorOverlay.new()
	add_child(sector_overlay)
	ambient_over_layer = AmbientLayer.new()
	ambient_over_layer.role = AmbientLayer.ROLE_OVER
	add_child(ambient_over_layer)
	# Atmosphere layers — multiply tint over the map, then particles in
	# front of that. Hex overlay and tokens sit above so they stay legible
	# regardless of the chosen mood.
	tint_layer = TintLayer.new()
	add_child(tint_layer)
	particle_layer = ParticleLayer.new()
	add_child(particle_layer)
	# Additive bloom for bright cinematic flashes (a "miracle") that a
	# multiplicative tint can't reach. Above the map/atmosphere; z_index keeps
	# it below handouts/blackout.
	bloom_layer = BloomLayer.new()
	add_child(bloom_layer)

	hex_overlay = HexOverlay.new()
	hex_overlay.visible = SessionState.hex_grid_visible
	add_child(hex_overlay)

	token_layer = Node2D.new()
	add_child(token_layer)

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	# Initiative rail draws in screen-space, so it sits on the camera so its
	# transform stays put when the camera moves (it doesn't, currently, but
	# this keeps the layering honest).
	initiative_rail = InitiativeRail.new()
	add_child(initiative_rail)

	# Ping pulse (over the map) and handout reveal (over everything but the
	# blackout), then blackout on top.
	ping_layer = PingLayer.new()
	add_child(ping_layer)
	handout_layer = HandoutLayer.new()
	add_child(handout_layer)
	# Blackout overlay — top-most so it covers the entire projected frame
	# (map, tokens, rail, everything). The GM tablet is unaffected.
	blackout_layer = BlackoutLayer.new()
	add_child(blackout_layer)

	get_viewport().size_changed.connect(_on_viewport_resized)

	# Publish initial viewport size to SessionState. Deferred one frame so
	# the secondary Window has actually been sized by the OS.
	call_deferred("_publish_viewport_size")

	SessionState.current_map_changed.connect(_on_current_map_changed)
	# Metadata carries map_fit; it resolves just AFTER current_map_changed, so
	# re-fit here to apply the new map's fit fraction.
	SessionState.current_map_metadata_changed.connect(_on_map_metadata_changed)
	SessionState.hex_grid_visibility_changed.connect(_on_hex_visibility_changed)
	SessionState.token_added.connect(_on_token_added)
	SessionState.token_removed.connect(_on_token_removed)
	SessionState.token_moved.connect(_on_token_moved)
	SessionState.token_data_changed.connect(_on_token_data_changed)
	SessionState.tokens_reloaded.connect(_on_tokens_reloaded)
	SessionState.projector_calibration_changed.connect(_on_calibration_changed)
	_on_calibration_changed(SessionState.calibration_offset, SessionState.calibration_zoom, SessionState.calibration_rotation_deg)


# Physical-table calibration — pan/scale/rotate the whole projected image via
# the camera so it aligns with a physical grid mat.
func _on_calibration_changed(offset: Vector2, zoom: float, rotation_deg: float) -> void:
	if camera == null:
		return
	camera.offset = -offset             # nudge image the way the GM pushes
	camera.zoom = Vector2(zoom, zoom)    # >1 magnifies the projection
	camera.rotation = deg_to_rad(rotation_deg)


func _publish_viewport_size() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	SessionState.set_projector_viewport_size(vp.get_visible_rect().size)


func _on_viewport_resized() -> void:
	# size_changed can fire during teardown when the viewport is already gone.
	if get_viewport() == null:
		return
	_publish_viewport_size()
	_refit_sprite(sprite_a)
	_refit_sprite(sprite_b)
	hex_overlay.queue_redraw()
	_publish_map_transform()


func _on_current_map_changed(path: String) -> void:
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("Projector: failed to load map at %s" % path)
		return
	_crossfade_to(texture)
	# Publish transform once the incoming sprite has its texture so the
	# sector overlay snaps to the new map at the start of the crossfade
	# (it fades alongside the map via its own modulate).
	_publish_map_transform()


# The sector overlay + ambient effects render geometry expressed in
# map-texture-pixel coordinates. They need to know which texture is
# active and at what world-scale so they can convert. Recomputed on
# every map change and viewport resize.
func _publish_map_transform() -> void:
	# Prefer the incoming sprite during a crossfade so the overlay tracks
	# the new map immediately; fall back to the active sprite otherwise.
	var ref_sprite: Sprite2D = sprite_b if sprite_b.texture != null else sprite_a
	if ref_sprite.texture == null:
		sector_overlay.set_map_transform(Vector2.ZERO, 1.0)
		ambient_under_layer.set_map_transform(Vector2.ZERO, 1.0)
		ambient_over_layer.set_map_transform(Vector2.ZERO, 1.0)
		return
	var tex_size := ref_sprite.texture.get_size()
	var scale_factor := ref_sprite.scale.x
	sector_overlay.set_map_transform(tex_size, scale_factor)
	ambient_under_layer.set_map_transform(tex_size, scale_factor)
	ambient_over_layer.set_map_transform(tex_size, scale_factor)


func _on_hex_visibility_changed(is_vis: bool) -> void:
	hex_overlay.visible = is_vis


# Map metadata (incl. map_fit) resolved — re-fit both map sprites at the new
# fraction and republish the transform so the sector overlay tracks it.
func _on_map_metadata_changed(_meta: Dictionary) -> void:
	_refit_sprite(sprite_a)
	_refit_sprite(sprite_b)
	_publish_map_transform()


# --- Crossfade ------------------------------------------------------------

func _crossfade_to(texture: Texture2D) -> void:
	if _crossfade_tween:
		_crossfade_tween.kill()

	# If nothing's playing yet, just snap in with a quick fade.
	if sprite_a.texture == null:
		sprite_a.texture = texture
		_refit_sprite(sprite_a)
		sprite_a.modulate = Color(1, 1, 1, 0)
		_crossfade_tween = create_tween()
		_crossfade_tween.tween_property(sprite_a, "modulate:a", 1.0, CROSSFADE_DURATION)
		return

	# Stage the incoming texture on sprite_b, then crossfade B in and A
	# out in parallel. When done, swap them so sprite_a is once again the
	# active layer (keeps the "outgoing" buffer free for the next swap).
	sprite_b.texture = texture
	_refit_sprite(sprite_b)
	sprite_b.modulate = Color(1, 1, 1, 0)

	_crossfade_tween = create_tween().set_parallel(true)
	_crossfade_tween.tween_property(sprite_a, "modulate:a", 0.0, CROSSFADE_DURATION)
	_crossfade_tween.tween_property(sprite_b, "modulate:a", 1.0, CROSSFADE_DURATION)
	_crossfade_tween.chain().tween_callback(_finish_crossfade)


func _finish_crossfade() -> void:
	# Swap the two sprite slots so sprite_a is always "active."
	var tmp := sprite_a
	sprite_a = sprite_b
	sprite_b = tmp
	sprite_b.texture = null
	sprite_b.modulate = Color(1, 1, 1, 0)


func _refit_sprite(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var viewport_size := vp.get_visible_rect().size
	var tex_size := sprite.texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return
	# Contain-fit, then shrink by the per-map fit fraction so a map can sit
	# inside a wider backdrop (e.g. the Atlantis city in its crater).
	var scale_factor: float = min(
		viewport_size.x / tex_size.x,
		viewport_size.y / tex_size.y,
	) * SessionState.current_map_fit
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.position = Vector2.ZERO


# --- Token visuals --------------------------------------------------------

func _on_token_added(id: int, data: Dictionary) -> void:
	var visual := TokenVisual.new()
	visual.set_data(data)
	visual.position = data.get("position", Vector2.ZERO)
	token_layer.add_child(visual)
	token_visuals[id] = visual


func _on_token_removed(id: int) -> void:
	if not token_visuals.has(id):
		return
	token_visuals[id].queue_free()
	token_visuals.erase(id)


# Map switch: rebuild all token visuals from the newly-active map's set.
func _on_tokens_reloaded() -> void:
	for v in token_visuals.values():
		v.queue_free()
	token_visuals.clear()
	for id in SessionState.tokens:
		_on_token_added(id, SessionState.tokens[id])


func _on_token_moved(id: int, world_position: Vector2) -> void:
	if not token_visuals.has(id):
		return
	token_visuals[id].position = world_position


func _on_token_data_changed(id: int, data: Dictionary) -> void:
	if not token_visuals.has(id):
		return
	token_visuals[id].set_data(data)


# ---------------------------------------------------------------------------
# Inner classes
# ---------------------------------------------------------------------------

class HexOverlay extends Node2D:
	# Pointy-top hexagons. Radius is per-map (SessionState provides it).
	#   horizontal spacing = sqrt(3) * radius
	#   vertical spacing   = 1.5 * radius
	# Odd rows offset by half the horizontal spacing.

	const LINE_COLOR := Color(0.0, 0.0, 0.0, 0.42)
	const LINE_WIDTH := 1.5

	func _ready() -> void:
		get_viewport().size_changed.connect(queue_redraw)
		SessionState.current_map_metadata_changed.connect(func(_m): queue_redraw())

	func _draw() -> void:
		var bounds := get_viewport().get_visible_rect().size
		var radius := SessionState.get_current_hex_radius_px()
		var hx_spacing := sqrt(3.0) * radius
		var vy_spacing := 1.5 * radius

		var rows := int(bounds.y / vy_spacing) + 2
		var cols := int(bounds.x / hx_spacing) + 2

		# Camera2D is centered on origin → viewport top-left is -bounds/2.
		var origin := -bounds * 0.5

		for row in rows:
			for col in cols:
				var x_offset: float = (hx_spacing * 0.5) if (row % 2 == 1) else 0.0
				var center := origin + Vector2(
					col * hx_spacing + x_offset,
					row * vy_spacing,
				)
				_draw_hex(center, radius)

	func _draw_hex(center: Vector2, radius: float) -> void:
		var points := PackedVector2Array()
		for i in 6:
			var angle: float = PI / 3.0 * i - PI / 2.0  # pointy-top
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		points.append(points[0])
		draw_polyline(points, LINE_COLOR, LINE_WIDTH, true)


class TokenVisual extends Node2D:
	# Token radius is derived from the current hex radius and the token's
	# size enum so tokens read at a sensible size on every map.
	const TOKEN_TO_HEX_RATIO := 0.7
	var color: Color = Color.WHITE
	var label_text: String = ""
	var size_multiplier: float = 1.0
	var is_combatant: bool = false
	var hp_max: int = 10
	var hp_current: int = 10
	var fp_max: int = 10
	var fp_current: int = 10
	var statuses: Array = []

	func _ready() -> void:
		SessionState.current_map_metadata_changed.connect(func(_m): queue_redraw())

	func set_data(data: Dictionary) -> void:
		color = data.get("color", Color.WHITE)
		label_text = data.get("label", data.get("name", ""))
		size_multiplier = SessionState.token_size_multiplier(data.get("size", "medium"))
		is_combatant = data.get("is_combatant", false)
		hp_max = int(data.get("hp_max", 10))
		hp_current = int(data.get("hp_current", 10))
		fp_max = int(data.get("fp_max", 10))
		fp_current = int(data.get("fp_current", 10))
		statuses = data.get("statuses", [])
		queue_redraw()

	func _draw() -> void:
		var radius := SessionState.get_current_hex_radius_px() * TOKEN_TO_HEX_RATIO * size_multiplier
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0, 0, 0, 0.85), 2.5, true)
		if is_combatant:
			_draw_bars(radius)
		if label_text != "":
			_draw_label(radius)
		if is_combatant and not statuses.is_empty():
			_draw_statuses(radius)

	func _draw_label(radius: float) -> void:
		var font := ThemeDB.fallback_font
		var font_size := int(max(12.0, radius * 0.55))
		var text_width := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var x := -text_width * 0.5
		var y := radius + font_size + 4
		# Shadow then text — readable against any map color.
		font.draw_string(get_canvas_item(), Vector2(x + 2, y + 2), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.85))
		font.draw_string(get_canvas_item(), Vector2(x, y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	func _draw_bars(radius: float) -> void:
		# HP bar (taller, sits just above the circle); FP bar stacked above.
		var bar_w := radius * 2.0
		var hp_h := maxf(4.0, radius * 0.16)
		var fp_h := maxf(3.0, radius * 0.12)
		var gap := 2.0
		var hp_top := -radius - hp_h - 6.0
		var fp_top := hp_top - fp_h - gap
		var hp_color := _hp_color()
		_draw_bar(Rect2(Vector2(-bar_w * 0.5, hp_top), Vector2(bar_w, hp_h)), float(hp_current) / max(1.0, float(hp_max)), hp_color)
		_draw_bar(Rect2(Vector2(-bar_w * 0.5, fp_top), Vector2(bar_w, fp_h)), float(fp_current) / max(1.0, float(fp_max)), Color(0.40, 0.65, 0.95))

	func _draw_bar(rect: Rect2, ratio: float, fg: Color) -> void:
		var r := clampf(ratio, 0.0, 1.0)
		# Black backdrop with slight inset, then filled portion in fg.
		draw_rect(Rect2(rect.position - Vector2(1, 1), rect.size + Vector2(2, 2)), Color(0, 0, 0, 0.85))
		draw_rect(rect, Color(0.18, 0.18, 0.18, 0.9))
		if r > 0.0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * r, rect.size.y)), fg)

	func _hp_color() -> Color:
		if hp_max <= 0:
			return Color(0.85, 0.85, 0.85)
		var ratio := float(hp_current) / float(hp_max)
		if hp_current <= 0:
			return Color(0.85, 0.15, 0.15)  # red — at or below 0 HP
		if ratio <= 0.333:
			return Color(0.95, 0.80, 0.20)  # yellow — reeling (1/3 HP)
		return Color(0.35, 0.85, 0.35)

	func _draw_statuses(radius: float) -> void:
		# A row of small lettered disks under the label. Position is below
		# the label baseline; sized as a fraction of token radius.
		var font := ThemeDB.fallback_font
		var label_font_size := int(max(12.0, radius * 0.55))
		var disk_r := maxf(7.0, radius * 0.20)
		var spacing := disk_r * 2.4
		var row_w := spacing * statuses.size() - (spacing - disk_r * 2.0)
		var x0 := -row_w * 0.5 + disk_r
		var y := radius + label_font_size + disk_r + 10.0
		var font_size := int(disk_r * 1.4)
		for i in statuses.size():
			var status_id: String = statuses[i]
			var meta: Dictionary = SessionState.status_display(status_id)
			if meta.is_empty():
				continue
			var center := Vector2(x0 + i * spacing, y)
			draw_circle(center, disk_r, meta.get("color", Color.WHITE))
			draw_arc(center, disk_r, 0.0, TAU, 16, Color(0, 0, 0, 0.85), 1.5, true)
			var letter: String = meta.get("letter", "?")
			var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			font.draw_string(
				get_canvas_item(),
				center + Vector2(-text_size.x * 0.5, text_size.y * 0.35),
				letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK,
			)


class TintLayer extends Node2D:
	# Full-viewport multiplicative color tint, sitting above the map but
	# below particles/hex/tokens. White (1,1,1,1) = no effect.

	var _color: Color = Color(1.0, 1.0, 1.0, 1.0)
	# Final tint = mood tint × lighting tint (time-of-day × season). Both
	# default to ~white so the scene is unchanged until either is set.
	var _mood_color: Color = Color(1.0, 1.0, 1.0, 1.0)
	var _light_color: Color = Color(1.0, 1.0, 1.0, 1.0)

	func _ready() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		material = mat
		get_viewport().size_changed.connect(queue_redraw)
		SessionState.current_scene_mood_changed.connect(_on_mood_changed)
		SessionState.scene_lighting_changed.connect(_on_light_changed)
		_on_mood_changed(SessionState.current_scene_mood)
		_light_color = SessionState.compute_scene_tint()
		_recolor()

	func _on_mood_changed(mood_id: String) -> void:
		var mood: Dictionary = SessionState.SCENE_MOODS.get(mood_id, {})
		_mood_color = mood.get("tint", Color(1.0, 1.0, 1.0, 1.0))
		_recolor()

	func _on_light_changed(tint: Color) -> void:
		_light_color = tint
		_recolor()

	func _recolor() -> void:
		_color = Color(
			_mood_color.r * _light_color.r,
			_mood_color.g * _light_color.g,
			_mood_color.b * _light_color.b,
			1.0)
		queue_redraw()

	func _draw() -> void:
		var bounds := get_viewport().get_visible_rect().size
		draw_rect(Rect2(-bounds * 0.5, bounds), _color)


class BackdropLayer extends Sprite2D:
	# Full-frame image behind the map — the seabed/crater that fills the 16:9
	# around the (smaller, map_fit-scaled) circular city. COVER-scaled to the
	# viewport and centered on the origin (the Camera2D centers the viewport on
	# origin). z_index below the map sprites. Hidden when the map has no backdrop.
	func _ready() -> void:
		centered = true
		z_index = -100
		SessionState.current_backdrop_changed.connect(_on_backdrop_changed)
		get_viewport().size_changed.connect(_refit)
		_on_backdrop_changed(SessionState.current_backdrop_path)

	func _on_backdrop_changed(path: String) -> void:
		if path != "" and ResourceLoader.exists(path):
			texture = load(path)
			visible = true
			_refit()
		else:
			texture = null
			visible = false

	func _refit() -> void:
		if texture == null:
			return
		var vp := get_viewport()
		if vp == null:
			return
		var vs := vp.get_visible_rect().size
		var ts := texture.get_size()
		if ts.x <= 0 or ts.y <= 0:
			return
		# COVER — fill the whole viewport, cropping overflow.
		var s: float = max(vs.x / ts.x, vs.y / ts.y)
		scale = Vector2(s, s)
		position = Vector2.ZERO


class BloomLayer extends Node2D:
	# Full-viewport ADDITIVE white wash for bright flashes (a "miracle", a
	# lightning strike) that a multiplicative tint can't produce — it brightens
	# ABOVE the map's own colour. Alpha tracks SessionState.current_light_bloom
	# (0..1), tweened by transition_lighting. Sits above the map/atmosphere but
	# below handouts (2048) and blackout (4096).
	var _bloom: float = 0.0

	func _ready() -> void:
		z_index = 1024
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
		SessionState.scene_bloom_changed.connect(_on_bloom)
		get_viewport().size_changed.connect(queue_redraw)
		_bloom = SessionState.current_light_bloom
		queue_redraw()

	func _on_bloom(b: float) -> void:
		_bloom = b
		queue_redraw()

	func _draw() -> void:
		if _bloom <= 0.0:
			return
		var bounds := get_viewport().get_visible_rect().size
		draw_rect(Rect2(-bounds * 0.5, bounds), Color(1, 1, 1, clampf(_bloom, 0.0, 1.0)))


class BlackoutLayer extends Node2D:
	# Full-viewport black overlay, fading in/out on blackout. Top-most so it
	# hides the entire projected frame; the GM tablet is unaffected.
	var _alpha: float = 0.0
	var _tween: Tween

	func _ready() -> void:
		z_index = 4096
		SessionState.blackout_changed.connect(_on_blackout)
		get_viewport().size_changed.connect(queue_redraw)
		_alpha = 1.0 if SessionState.is_blackout else 0.0
		queue_redraw()

	func _on_blackout(on: bool) -> void:
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_method(_set_alpha, _alpha, (1.0 if on else 0.0), 0.6)

	func _set_alpha(a: float) -> void:
		_alpha = a
		queue_redraw()

	func _draw() -> void:
		if _alpha <= 0.0:
			return
		var bounds := get_viewport().get_visible_rect().size
		draw_rect(Rect2(-bounds * 0.5, bounds), Color(0, 0, 0, _alpha))


class HandoutLayer extends Node2D:
	# Full-screen handout image (character sheet / portrait / letter) over the
	# map, fading in on reveal and back to the map on hide.
	var _texture: Texture2D
	var _alpha: float = 0.0
	var _tween: Tween

	func _ready() -> void:
		z_index = 2048
		SessionState.current_handout_changed.connect(_on_handout_changed)
		get_viewport().size_changed.connect(queue_redraw)

	func _on_handout_changed(path: String) -> void:
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		if path != "":
			_texture = load(path) as Texture2D
			_tween.tween_method(_set_alpha, _alpha, 1.0, 0.5)
		else:
			_tween.tween_method(_set_alpha, _alpha, 0.0, 0.5)

	func _set_alpha(a: float) -> void:
		_alpha = a
		queue_redraw()

	func _draw() -> void:
		if _alpha <= 0.0:
			return
		var bounds := get_viewport().get_visible_rect().size
		# Dark backdrop so the map doesn't show through the letterbox.
		draw_rect(Rect2(-bounds * 0.5, bounds), Color(0, 0, 0, _alpha))
		if _texture == null:
			return
		var tex := _texture.get_size()
		if tex.x <= 0 or tex.y <= 0:
			return
		var sf: float = min(bounds.x / tex.x, bounds.y / tex.y)
		var disp := tex * sf
		draw_texture_rect(_texture, Rect2(-disp * 0.5, disp), false, Color(1, 1, 1, _alpha))


class PingLayer extends Node2D:
	# One-shot expanding-ring pulse at a map location — "look here."
	var _pos: Vector2 = Vector2.ZERO
	var _t: float = 1.0  # 0..1 animation progress; >=1 = idle
	const DURATION := 1.0
	const MAX_RADIUS := 140.0

	func _ready() -> void:
		SessionState.ping_emitted.connect(_on_ping)

	func _on_ping(world_pos: Vector2) -> void:
		_pos = world_pos
		_t = 0.0
		set_process(true)

	func _process(delta: float) -> void:
		_t += delta / DURATION
		if _t >= 1.0:
			_t = 1.0
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		if _t >= 1.0:
			return
		# Two expanding rings, fading out.
		var alpha := 1.0 - _t
		for k in [0.0, 0.35]:
			var p: float = clampf(_t - k, 0.0, 1.0)
			var r: float = 20.0 + MAX_RADIUS * p
			draw_arc(_pos, r, 0.0, TAU, 48, Color(1.0, 0.9, 0.3, alpha * (1.0 - p)), 4.0, true)


class ParticleLayer extends CPUParticles2D:
	# Atmospheric particles — snow, embers, rain, leaves, dust — driven by
	# the current scene mood. Emission rect and origin are derived from
	# viewport size and rebuilt on resize. Each preset gets a real texture
	# (a generated leaf sprite; procedural soft-dot / streak for the rest) so
	# particles read as motes/flakes/leaves rather than the default squares.

	const LEAF_PATH := "res://assets/particles/leaf.png"
	const SNOW_PATH := "res://assets/particles/snow.png"
	var _dot_tex: Texture2D
	var _streak_tex: Texture2D
	var _leaf_tex: Texture2D
	var _snow_tex: Texture2D
	var _add_mat: CanvasItemMaterial

	# Mirroring support (GM preview). The projector leaves both at their
	# defaults and behaves exactly as before; map_preview.gd sets them so the
	# same presets render into a small stage rect instead of the full viewport.
	#   bounds_override — emission area in the mirror's pixels (ZERO = viewport)
	#   world_scale     — mirror-pixels per projector-pixel; scales speeds,
	#                     gravity and particle size so rain falls at the same
	#                     apparent rate in a pane 1/4 the size.
	# Floor on how far particle SIZE may shrink in a mirror (see _apply_common).
	const MIRROR_MIN_SIZE_SCALE := 0.45
	var bounds_override: Vector2 = Vector2.ZERO
	var world_scale: float = 1.0

	func _ready() -> void:
		one_shot = false
		local_coords = false
		emitting = false
		get_viewport().size_changed.connect(_reapply)
		SessionState.current_scene_mood_changed.connect(func(_id): _reapply())
		SessionState.scene_effects_changed.connect(func(_e): _reapply())
		_reapply()

	func _reapply() -> void:
		# A staged scene's explicit effects win; otherwise fall back to the
		# legacy mood's particle preset.
		var preset := _particle_from_effects()
		if preset == "":
			preset = SessionState.get_current_scene_mood_data().get("particles", "none")
		_apply_preset(preset)

	func _particle_from_effects() -> String:
		for e in SessionState.current_scene_effects:
			match e:
				"snow", "rain", "leaves", "embers", "dust":
					return e
				"dust_motes":
					return "dust"
				"ash":
					return "embers"
		return ""

	func _apply_preset(preset: String) -> void:
		var bounds := bounds_override
		if bounds == Vector2.ZERO:
			var vp := get_viewport()
			if vp == null:
				return
			bounds = vp.get_visible_rect().size
		material = null  # default (mix) blend; embers overrides to additive
		match preset:
			"none":
				emitting = false
				return
			"snow":
				texture = _snow_texture()
				_config_falling(bounds, 200, 12.0, Color(1.0, 1.0, 1.0, 0.9), 0.018, 0.032, Vector2(20, 60), 10, 25)
			"rain":
				# Rain wants MANY THIN FAINT streaks falling FAST. The old preset
				# was 600 fat (8-16px wide) slow streaks at alpha 0.7, which on a
				# projector read as film scratches rather than weather. Halving the
				# alpha and thinning the streak to ~2-4px while trebling the fall
				# speed puts each drop on screen briefly enough to blur.
				texture = _streak_texture()
				_config_falling(bounds, 900, 0.8, Color(0.72, 0.80, 0.92, 0.34), 0.45, 0.85, Vector2(0, 2600), 700, 1000)
				# Steeper wind-slant than the shared falling default; rain doesn't
				# drift the way snow does.
				direction = Vector2(0.16, 1).normalized()
				spread = 4.0
			"leaves":
				texture = _leaf_texture()
				_config_falling(bounds, 70, 15.0, Color(1.0, 1.0, 1.0, 0.75), 0.07, 0.13, Vector2(40, 50), 30, 80)
				# Leaves tumble as they fall.
				angle_min = 0.0
				angle_max = 360.0
				angular_velocity_min = -60.0
				angular_velocity_max = 60.0
			"embers":
				texture = _dot_texture()
				material = _additive_material()
				_config_rising(bounds, 150, 4.0, Color(1.0, 0.6, 0.2, 0.9), 0.04, 0.10, Vector2(0, -100), 20, 60)
			"dust":
				# Wind-borne dust/sand haze. Additive soft-dots (so they GLOW as
				# sunlit motes rather than muddy tan-on-tan specks), emitted across
				# the WHOLE viewport so the air reads as hazy everywhere — not just a
				# thin stream entering from one edge. Dense, small-to-gusty, pale, and
				# blowing on a NW→SE diagonal to match the baked NW sun.
				texture = _dot_texture()
				material = _additive_material()
				_config_ambient(bounds, 260, 5.5, Color(0.95, 0.88, 0.72, 0.5), 0.05, 0.20, Vector2(170, 55), 90, 210)
			_:
				emitting = false
				return
		emitting = true

	func _config_falling(bounds: Vector2, n: int, life: float, col: Color, sc_min: float, sc_max: float, grav: Vector2, vmin: float, vmax: float) -> void:
		position = Vector2(0, -bounds.y * 0.5 - 20.0 * world_scale)
		emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		emission_rect_extents = Vector2(bounds.x * 0.5 + 40.0 * world_scale, 5.0 * world_scale)
		direction = Vector2(0.05, 1).normalized()
		spread = 15.0
		_apply_common(n, life, col, sc_min, sc_max, grav, vmin, vmax)

	# Emits across the ENTIRE viewport (not one edge), so a pervasive drifting
	# haze — blowing dust — fills the whole frame at once. Direction is a gentle
	# NW→SE diagonal to sit with the baked NW lighting.
	func _config_ambient(bounds: Vector2, n: int, life: float, col: Color, sc_min: float, sc_max: float, grav: Vector2, vmin: float, vmax: float) -> void:
		position = Vector2.ZERO
		emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		emission_rect_extents = Vector2(bounds.x * 0.5 + 40.0 * world_scale, bounds.y * 0.5 + 40.0 * world_scale)
		direction = Vector2(1.0, 0.35).normalized()
		spread = 25.0
		_apply_common(n, life, col, sc_min, sc_max, grav, vmin, vmax)

	func _config_rising(bounds: Vector2, n: int, life: float, col: Color, sc_min: float, sc_max: float, grav: Vector2, vmin: float, vmax: float) -> void:
		position = Vector2(0, bounds.y * 0.5 + 20.0 * world_scale)
		emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		emission_rect_extents = Vector2(bounds.x * 0.5, 5.0 * world_scale)
		direction = Vector2(0, -1)
		spread = 25.0
		_apply_common(n, life, col, sc_min, sc_max, grav, vmin, vmax)

	func _config_horizontal(bounds: Vector2, n: int, life: float, col: Color, sc_min: float, sc_max: float, grav: Vector2, vmin: float, vmax: float) -> void:
		position = Vector2(-bounds.x * 0.5 - 20.0 * world_scale, 0)
		emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		emission_rect_extents = Vector2(5.0 * world_scale, bounds.y * 0.5)
		direction = Vector2(1, 0)
		spread = 30.0
		_apply_common(n, life, col, sc_min, sc_max, grav, vmin, vmax)

	func _apply_common(n: int, life: float, col: Color, sc_min: float, sc_max: float, grav: Vector2, vmin: float, vmax: float) -> void:
		amount = n
		lifetime = life
		color = col
		# Reset spin each apply; leaves re-enable it after this call.
		angle_min = 0.0
		angle_max = 0.0
		angular_velocity_min = 0.0
		angular_velocity_max = 0.0
		# world_scale is 1.0 on the projector; the GM preview mirror sets it so
		# sizes and speeds shrink with the pane instead of raining boulders.
		#
		# Sizes get a floor. Scaling them strictly with the pane makes thin
		# particles — rain streaks are only 2-4 px wide on the projector —
		# collapse below a pixel in the mirror, so the GM's own view says "dry"
		# while the players are being rained on. The preview is a status
		# readout, not a WYSIWYG: slightly-too-fat weather beats invisible
		# weather. Speeds still scale honestly, so the motion reads right.
		var size_scale: float = maxf(world_scale, MIRROR_MIN_SIZE_SCALE)
		scale_amount_min = sc_min * size_scale
		scale_amount_max = sc_max * size_scale
		gravity = grav * world_scale
		initial_velocity_min = vmin * world_scale
		initial_velocity_max = vmax * world_scale

	func _leaf_texture() -> Texture2D:
		if _leaf_tex == null:
			if ResourceLoader.exists(LEAF_PATH):
				_leaf_tex = load(LEAF_PATH)
			else:
				_leaf_tex = _dot_texture()
		return _leaf_tex

	func _snow_texture() -> Texture2D:
		if _snow_tex == null:
			_snow_tex = load(SNOW_PATH) if ResourceLoader.exists(SNOW_PATH) else _dot_texture()
		return _snow_tex

	func _additive_material() -> CanvasItemMaterial:
		if _add_mat == null:
			_add_mat = CanvasItemMaterial.new()
			_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		return _add_mat

	func _dot_texture() -> Texture2D:
		if _dot_tex == null:
			_dot_tex = _make_soft_dot(64)
		return _dot_tex

	func _streak_texture() -> Texture2D:
		if _streak_tex == null:
			_streak_tex = _make_streak(6, 110)   # thin + long: a rain streak, not a scratch
		return _streak_tex

	func _make_soft_dot(size: int) -> Texture2D:
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := Vector2(size * 0.5, size * 0.5)
		var mr := float(size) * 0.5
		for y in size:
			for x in size:
				var t: float = clampf(1.0 - Vector2(x, y).distance_to(c) / mr, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(t, 1.6)))
		return ImageTexture.create_from_image(img)

	func _make_streak(w: int, h: int) -> Texture2D:
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var cx := float(w) * 0.5
		for y in h:
			for x in w:
				var dx: float = abs(float(x) - cx) / (float(w) * 0.5)
				var ay: float = 1.0 - abs(float(y) - float(h) * 0.5) / (float(h) * 0.5)
				var a: float = clampf(1.0 - dx, 0.0, 1.0) * clampf(ay + 0.2, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * 0.85))
		return ImageTexture.create_from_image(img)


class InitiativeRail extends Node2D:
	# Right-edge side rail showing the initiative order during combat.
	# Drawn in screen-space (translated to the top-right of the viewport).
	# Hidden when combat is inactive or there are no combatants. Each entry:
	# coloured swatch, name + Basic Speed, HP bar, FP bar. Active entry has
	# a bright border.

	const RAIL_WIDTH := 280.0
	const ENTRY_HEIGHT := 64.0
	const HEADER_HEIGHT := 36.0
	const PAD := 10.0

	func _ready() -> void:
		z_index = 100  # always on top of map/tokens/atmosphere
		get_viewport().size_changed.connect(queue_redraw)
		SessionState.combat_state_changed.connect(func(_a): queue_redraw())
		SessionState.combat_round_changed.connect(func(_r): queue_redraw())
		SessionState.active_combatant_changed.connect(func(_id): queue_redraw())
		SessionState.token_added.connect(func(_id, _d): queue_redraw())
		SessionState.token_removed.connect(func(_id): queue_redraw())
		SessionState.token_data_changed.connect(func(_id, _d): queue_redraw())

	func _draw() -> void:
		if not SessionState.is_combat_active:
			return
		var order: Array = SessionState.get_combat_order()
		if order.is_empty():
			return

		var bounds := get_viewport().get_visible_rect().size
		# Camera2D centres the viewport on origin, so the top-right corner
		# of the viewport in world space is +bounds/2.
		var top_right := bounds * 0.5
		var rail_origin := top_right - Vector2(RAIL_WIDTH + PAD, -PAD)
		var rail_height := HEADER_HEIGHT + ENTRY_HEIGHT * order.size() + PAD

		# Backdrop
		draw_rect(Rect2(rail_origin, Vector2(RAIL_WIDTH, rail_height)), Color(0.0, 0.0, 0.0, 0.65))
		draw_rect(Rect2(rail_origin, Vector2(RAIL_WIDTH, rail_height)), Color(1, 1, 1, 0.15), false, 1.5)

		# Header — "Round N"
		var font := ThemeDB.fallback_font
		var header_text := "Round %d" % SessionState.combat_round
		font.draw_string(
			get_canvas_item(),
			rail_origin + Vector2(PAD, 24),
			header_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE,
		)

		# Entries
		var y := rail_origin.y + HEADER_HEIGHT
		for id in order:
			var token: Dictionary = SessionState.tokens.get(id, {})
			if token.is_empty():
				continue
			_draw_entry(Rect2(rail_origin.x, y, RAIL_WIDTH, ENTRY_HEIGHT), token, id == SessionState.active_combatant_id, font)
			y += ENTRY_HEIGHT

	func _draw_entry(rect: Rect2, token: Dictionary, is_active: bool, font: Font) -> void:
		# Active highlight
		if is_active:
			draw_rect(rect, Color(0.95, 0.85, 0.20, 0.18))
			draw_rect(rect, Color(0.95, 0.85, 0.20, 0.95), false, 2.0)

		# Color swatch (left)
		var swatch_size := 14.0
		var swatch_center := Vector2(rect.position.x + PAD + swatch_size * 0.5, rect.position.y + 14)
		draw_circle(swatch_center, swatch_size * 0.5, token.get("color", Color.WHITE))
		draw_arc(swatch_center, swatch_size * 0.5, 0.0, TAU, 16, Color(0, 0, 0, 0.85), 1.0, true)

		# Name + Basic Speed
		var label_text: String = token.get("label", token.get("name", "Combatant"))
		var bs: float = token.get("basic_speed", SessionState.DEFAULT_BASIC_SPEED)
		var header_y := rect.position.y + 20
		var header_x := rect.position.x + PAD + swatch_size + 8
		font.draw_string(get_canvas_item(), Vector2(header_x, header_y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		var bs_text := "BS %.2f" % bs
		var bs_w := font.get_string_size(bs_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		font.draw_string(get_canvas_item(), Vector2(rect.end.x - PAD - bs_w, header_y - 2), bs_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.85))

		# Bars (HP then FP)
		var bar_x := rect.position.x + PAD
		var bar_w := rect.size.x - PAD * 2.0
		var hp_max: int = max(1, int(token.get("hp_max", 10)))
		var hp_cur: int = int(token.get("hp_current", hp_max))
		var fp_max: int = max(1, int(token.get("fp_max", 10)))
		var fp_cur: int = int(token.get("fp_current", fp_max))
		var hp_color := Color(0.35, 0.85, 0.35)
		if hp_cur <= 0:
			hp_color = Color(0.85, 0.15, 0.15)
		elif float(hp_cur) / float(hp_max) <= 0.333:
			hp_color = Color(0.95, 0.80, 0.20)
		_draw_rail_bar(Rect2(bar_x, rect.position.y + 30, bar_w, 8), float(hp_cur) / float(hp_max), hp_color, "HP %d/%d" % [hp_cur, hp_max], font)
		_draw_rail_bar(Rect2(bar_x, rect.position.y + 46, bar_w, 6), float(fp_cur) / float(fp_max), Color(0.40, 0.65, 0.95), "FP %d/%d" % [fp_cur, fp_max], font)

	func _draw_rail_bar(rect: Rect2, ratio: float, fg: Color, label: String, font: Font) -> void:
		var r := clampf(ratio, 0.0, 1.0)
		draw_rect(rect, Color(0.18, 0.18, 0.18, 0.95))
		if r > 0.0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * r, rect.size.y)), fg)
		draw_rect(rect, Color(0, 0, 0, 0.6), false, 1.0)
		# Label centred over the bar
		var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var x := rect.position.x + (rect.size.x - size.x) * 0.5
		var y := rect.position.y + rect.size.y - 1
		font.draw_string(get_canvas_item(), Vector2(x + 1, y + 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.9))
		font.draw_string(get_canvas_item(), Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


class SectorOverlay extends Node2D:
	# Renders sector polygons + labels on top of the active map. Geometry
	# comes from SessionState.current_sector_overlay (set when the map
	# loads); per-sector current tier comes from SessionState.facility_state.
	#
	# Polygons are authored in map-texture-pixel coordinates. The projector
	# tells us the active texture size + world-space scale via
	# set_map_transform(); we convert points in _draw.

	# Light tier TINT — kept low-alpha so the painted underwater art shows
	# through; the tier reads mainly from the accent border below. (Pre-art this
	# was heavy flat colour that muted the map.)
	const TIER_COLORS := {
		1: Color(0.34, 0.48, 0.56, 0.10),  # atlantean baseline — barely tints, art breathes
		2: Color(0.45, 0.70, 0.96, 0.22),  # industrial steel sheen
		3: Color(1.00, 0.82, 0.38, 0.30),  # ATA gold — gilded / energized
	}
	# Bright per-tier border accent — the "powered paneling" glow. Higher tier =
	# brighter + thicker, so an upgraded module reads at a glance without hiding
	# the art beneath it.
	const TIER_ACCENT := {
		1: Color(0.55, 0.72, 0.80, 0.55),
		2: Color(0.60, 0.82, 1.00, 0.88),
		3: Color(1.00, 0.88, 0.45, 0.98),
	}
	const TIER_BORDER_WIDTH := { 1: 1.5, 2: 2.5, 3: 4.0 }
	const SELECTED_OUTLINE := Color(0.95, 0.95, 0.30, 0.95)
	const UPGRADING_PULSE := Color(0.95, 0.55, 0.20, 0.85)

	var _tex_size: Vector2 = Vector2.ZERO
	var _scale: float = 1.0
	var _time: float = 0.0

	func _ready() -> void:
		SessionState.current_sector_overlay_changed.connect(func(_o): queue_redraw())
		SessionState.facility_state_changed.connect(queue_redraw)
		SessionState.sector_tier_changed.connect(func(_id, _t): queue_redraw())
		SessionState.sector_selection_changed.connect(func(_id): queue_redraw())
		set_process(true)

	func set_map_transform(tex_size: Vector2, scale_factor: float) -> void:
		_tex_size = tex_size
		_scale = scale_factor
		queue_redraw()

	func _process(delta: float) -> void:
		# Pulse the "upgrading" outline. Only consume frames when at least
		# one sector is actually upgrading; otherwise the redraw is wasted.
		var any_upgrading := false
		for entry in SessionState.facility_state.get("sectors", {}).values():
			if entry.get("upgrading", false):
				any_upgrading = true
				break
		if any_upgrading:
			_time += delta
			queue_redraw()

	func _draw() -> void:
		if _tex_size.x <= 0 or _tex_size.y <= 0:
			return
		var overlay: Dictionary = SessionState.current_sector_overlay
		var sectors: Array = overlay.get("sectors", [])
		if sectors.is_empty():
			return
		var font := ThemeDB.fallback_font
		var selected_id: String = SessionState.current_selected_sector_id
		for sector in sectors:
			if not (sector is Dictionary):
				continue
			_draw_sector(sector, font, selected_id)

	func _draw_sector(sector: Dictionary, font: Font, selected_id: String) -> void:
		var id: String = sector.get("id", "")
		var raw_polygon: Array = sector.get("polygon", [])
		if raw_polygon.size() < 3:
			return
		var points := PackedVector2Array()
		for p in raw_polygon:
			if not (p is Array) or p.size() < 2:
				continue
			points.append(_map_px_to_world(Vector2(p[0], p[1])))
		if points.size() < 3:
			return

		var tier: int = SessionState.get_sector_tier(id)
		var fill: Color = TIER_COLORS.get(tier, TIER_COLORS[1])

		draw_colored_polygon(points, fill)
		var loop := points.duplicate()
		loop.append(points[0])
		# Bright tier-accent border (the energized "powered paneling" read),
		# brighter + thicker at higher tiers.
		var accent: Color = TIER_ACCENT.get(tier, TIER_ACCENT[1])
		var bw: float = TIER_BORDER_WIDTH.get(tier, 2.0)
		draw_polyline(loop, accent, bw, true)

		if SessionState.is_sector_upgrading(id):
			var pulse: float = 0.55 + 0.45 * (0.5 + 0.5 * sin(_time * 3.0))
			var pulse_col := UPGRADING_PULSE
			pulse_col.a = pulse
			draw_polyline(loop, pulse_col, 3.5, true)

		if id != "" and id == selected_id:
			draw_polyline(loop, SELECTED_OUTLINE, 3.0, true)

		# Label — name + [Tn] tier badge, on a dark pill so it stays legible
		# over the busy caustics + bright sectors.
		var anchor_raw: Array = sector.get("label_anchor", [])
		if anchor_raw.size() >= 2:
			var anchor := _map_px_to_world(Vector2(anchor_raw[0], anchor_raw[1]))
			var name_text: String = sector.get("name", id)
			var badge_text := "%s  [T%d]" % [name_text, tier]
			# Inner-ring labels run a touch smaller so the 8 of them don't crowd
			# near the meteor.
			var base: float = 18.0 if sector.get("ring", "") == "inner" else 21.0
			var font_size := int(max(13.0, base * _scale))
			var tw := font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var ascent := font.get_ascent(font_size)
			var text_h := ascent + font.get_descent(font_size)
			# Center the label box on the anchor (draw_string takes a baseline).
			var box := Rect2(anchor.x - tw * 0.5, anchor.y - text_h * 0.5, tw, text_h)
			var pad := Vector2(font_size * 0.45, font_size * 0.30)
			_draw_pill(Rect2(box.position - pad, box.size + pad * 2.0), Color(0.03, 0.05, 0.09, 0.66))
			font.draw_string(get_canvas_item(), Vector2(box.position.x, box.position.y + ascent), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.97, 0.98, 1.0))

	func _draw_pill(rect: Rect2, col: Color) -> void:
		# Rounded dark backdrop: a full-height center bar plus two circular end
		# caps. Cheap, reads as a pill without a StyleBox.
		var r: float = min(rect.size.y * 0.5, 10.0)
		draw_rect(Rect2(rect.position + Vector2(r, 0), Vector2(rect.size.x - r * 2.0, rect.size.y)), col)
		draw_circle(rect.position + Vector2(r, rect.size.y * 0.5), r, col)
		draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y * 0.5), r, col)

	func _map_px_to_world(p: Vector2) -> Vector2:
		# Sprite is centered at origin and scaled by _scale to fit viewport.
		return (p - _tex_size * 0.5) * _scale


class AmbientLayer extends Node2D:
	# Hosts named ambient effects (meteor_glow, underwater_caustics, ...)
	# driven by SessionState.current_ambient_effects. Effects are added or
	# removed when the map's effect list changes. Each effect knows how to
	# read its own tunables from SessionState.current_ambient_config.
	#
	# role decides which effects this layer hosts. Caustics ride UNDER (so
	# the sector overlay sits on top of them); meteor glow rides OVER (it
	# visually emanates from the inner ring, in front of sectors).

	const ROLE_UNDER := "under"
	const ROLE_OVER  := "over"

	const UNDER_EFFECTS := {
		"underwater_caustics": true,
	}
	const OVER_EFFECTS := {
		"meteor_glow": true,
		"firelight": true,
	}

	var role: String = ROLE_UNDER
	var _effects: Dictionary = {}  # name -> Node
	var _tex_size: Vector2 = Vector2.ZERO
	var _scale: float = 1.0

	func _ready() -> void:
		SessionState.current_ambient_effects_changed.connect(func(_e): _rebuild())
		_rebuild()

	func set_map_transform(tex_size: Vector2, scale_factor: float) -> void:
		_tex_size = tex_size
		_scale = scale_factor
		for effect in _effects.values():
			if effect.has_method("apply_map_transform"):
				effect.apply_map_transform(tex_size, scale_factor)

	func _rebuild() -> void:
		# Determine which effects belong on this layer right now.
		var wanted: Dictionary = {}
		for raw in SessionState.current_ambient_effects:
			var effect_id: String = raw
			if role == ROLE_UNDER and UNDER_EFFECTS.has(effect_id):
				wanted[effect_id] = true
			elif role == ROLE_OVER and OVER_EFFECTS.has(effect_id):
				wanted[effect_id] = true
		# Remove effects no longer wanted.
		for effect_id in _effects.keys():
			if not wanted.has(effect_id):
				_effects[effect_id].queue_free()
				_effects.erase(effect_id)
		# Add new effects.
		for effect_id in wanted.keys():
			if _effects.has(effect_id):
				continue
			var node: Node = _make_effect(effect_id)
			if node == null:
				continue
			add_child(node)
			_effects[effect_id] = node
			if node.has_method("apply_map_transform"):
				node.apply_map_transform(_tex_size, _scale)
		# Re-apply per-effect config (intensity, position, ...) in case
		# only the config changed.
		for effect_id in _effects.keys():
			var cfg: Dictionary = SessionState.current_ambient_config.get(effect_id, {})
			if _effects[effect_id].has_method("apply_config"):
				_effects[effect_id].apply_config(cfg)

	func _make_effect(effect_id: String) -> Node:
		match effect_id:
			"underwater_caustics":
				return UnderwaterCausticsEffect.new()
			"meteor_glow":
				return MeteorGlowEffect.new()
			"firelight":
				return FirelightEffect.new()
		return null


class UnderwaterCausticsEffect extends ColorRect:
	# Full-viewport caustics shader. blend_mul lets the map show through,
	# brightened in the caustic bands. Position + size locked to the
	# viewport via a viewport-resize listener.

	const SHADER_PATH := "res://shaders/underwater_caustics.gdshader"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := load(SHADER_PATH)
		if shader == null:
			push_warning("UnderwaterCausticsEffect: shader missing at %s" % SHADER_PATH)
			return
		var mat := ShaderMaterial.new()
		mat.shader = shader
		material = mat
		get_viewport().size_changed.connect(_resize)
		_resize()

	func apply_config(cfg: Dictionary) -> void:
		if material == null:
			return
		if cfg.has("intensity"):
			material.set_shader_parameter("intensity", float(cfg["intensity"]))
		if cfg.has("speed"):
			material.set_shader_parameter("speed", float(cfg["speed"]))
		if cfg.has("tint") and cfg["tint"] is Array and cfg["tint"].size() >= 3:
			var arr: Array = cfg["tint"]
			var a: float = 1.0 if arr.size() < 4 else float(arr[3])
			material.set_shader_parameter("tint", Color(arr[0], arr[1], arr[2], a))

	func apply_map_transform(_tex_size: Vector2, _scale: float) -> void:
		# Caustics fill the viewport, not the map rect — so transform updates
		# are no-ops. Kept for interface uniformity.
		pass

	func _resize() -> void:
		# get_viewport() can be null if a stale instance's size_changed signal
		# fires after it's been freed during an ambient rebuild. Guard it —
		# without this the error aborts sizing and the caustics ColorRect stays
		# 0x0 (invisible).
		var vp := get_viewport()
		if vp == null:
			return
		var bounds := vp.get_visible_rect().size
		position = -bounds * 0.5
		size = bounds


class MeteorGlowEffect extends Node2D:
	# A pulsing additive radial glow positioned over the meteor (Inner Ring
	# centre by default; configurable via the sidecar's meteor_glow block).
	# Built from a procedural radial-gradient texture to avoid needing a
	# bundled art asset.

	const DEFAULT_RADIUS_PX := 220.0
	const DEFAULT_COLOR := Color(1.0, 0.78, 0.35, 1.0)
	const PULSE_PERIOD := 4.2  # seconds

	var _sprite: Sprite2D
	var _position_px: Vector2 = Vector2.ZERO  # in map-pixel space
	var _radius_px: float = DEFAULT_RADIUS_PX
	var _color: Color = DEFAULT_COLOR
	var _tex_size: Vector2 = Vector2.ZERO
	var _scale: float = 1.0
	var _time: float = 0.0
	var _has_position: bool = false

	func _ready() -> void:
		_sprite = Sprite2D.new()
		_sprite.centered = true
		_sprite.texture = _build_radial_texture()
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_sprite.material = mat
		_sprite.modulate = _color
		add_child(_sprite)
		set_process(true)
		_relayout()

	func apply_config(cfg: Dictionary) -> void:
		if cfg.has("position_px") and cfg["position_px"] is Array and cfg["position_px"].size() >= 2:
			var arr: Array = cfg["position_px"]
			_position_px = Vector2(arr[0], arr[1])
			_has_position = true
		if cfg.has("radius_px"):
			_radius_px = float(cfg["radius_px"])
		if cfg.has("color") and cfg["color"] is Array and cfg["color"].size() >= 3:
			var c: Array = cfg["color"]
			var a: float = 1.0 if c.size() < 4 else float(c[3])
			_color = Color(c[0], c[1], c[2], a)
			if _sprite != null:
				_sprite.modulate = _color
		_relayout()

	func apply_map_transform(tex_size: Vector2, scale_factor: float) -> void:
		_tex_size = tex_size
		_scale = scale_factor
		_relayout()

	func _process(delta: float) -> void:
		_time += delta
		if _sprite == null:
			return
		# Combined slow breathing scale + alpha throb. Sphere of influence
		# expands and contracts by ~12%, alpha by ~25%.
		var phase: float = (_time / PULSE_PERIOD) * TAU
		var s: float = 1.0 + 0.12 * sin(phase)
		var pulse_alpha: float = 1.0 - 0.25 * (0.5 - 0.5 * cos(phase))
		_sprite.scale = Vector2(_base_scale() * s, _base_scale() * s)
		_sprite.modulate = Color(_color.r, _color.g, _color.b, _color.a * pulse_alpha)

	func _relayout() -> void:
		if _sprite == null:
			return
		if _has_position and _tex_size.x > 0 and _tex_size.y > 0:
			# Map-pixel coords → world: same transform sector overlay uses.
			_sprite.position = (_position_px - _tex_size * 0.5) * _scale
		else:
			# No position configured → centre of the map (world origin).
			_sprite.position = Vector2.ZERO
		_sprite.scale = Vector2(_base_scale(), _base_scale())

	func _base_scale() -> float:
		# The radial texture is 256 px in diameter. Scale so its rendered
		# radius matches the configured world radius (radius_px * world scale).
		var target: float = _radius_px * _scale
		return target / 128.0  # texture half-size

	func _build_radial_texture() -> Texture2D:
		# Soft radial falloff: white core fading to transparent at the rim.
		var size := 256
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := Vector2(size * 0.5, size * 0.5)
		var max_r := float(size) * 0.5
		for y in size:
			for x in size:
				var d: float = Vector2(x, y).distance_to(c)
				var t: float = clampf(1.0 - d / max_r, 0.0, 1.0)
				var alpha: float = pow(t, 2.2)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
		return ImageTexture.create_from_image(img)
