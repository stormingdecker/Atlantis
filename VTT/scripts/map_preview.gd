extends Control

# MapPreview — GM-side interactive scaled-down view of the projector.
#
# Renders the current map fit-to-rect, the hex overlay if enabled, and
# all tokens. Handles mouse drag to move tokens (with snap-to-hex on
# release).
#
# Coordinate spaces:
#   * world space      — projector world coords (origin at center of
#                        projector viewport).
#   * preview space    — local pixel coords inside this Control.
#   * map texture px   — raw pixel coords on the source map image.
#
# Token positions are stored in world space (SessionState). When the
# user drags a token in preview space, this Control converts the new
# preview position back to world space using the published projector
# viewport size as the reference.

# Hex radius is per-map; token radius derives from it. Both match the
# projector's HexOverlay / TokenVisual so the preview is a faithful mirror.
const TOKEN_TO_HEX_RATIO := 0.7

# The projector's ParticleLayer, reused verbatim so weather can never drift
# between the two surfaces — one preset table, two stages. It is parented
# under a clip Control sized to the stage rect, with bounds_override /
# world_scale set so rain falls inside the preview at the projector's
# apparent rate.
const ProjectorScript = preload("res://scripts/projector.gd")

var _fx_clip: Control
var _fx_root: Node2D
var _fx_particles: CPUParticles2D

var _map_texture: Texture2D
var _dragging_token_id: int = -1
var _drag_offset_world: Vector2 = Vector2.ZERO

# Transient ping pulse mirror (world-space), so the GM sees their ping land.
var _ping_pos: Vector2 = Vector2.ZERO
var _ping_t: float = 1.0
const _PING_DURATION := 1.0
const _PING_MAX_RADIUS_WORLD := 140.0


func _ready() -> void:
	custom_minimum_size = Vector2(480, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Without this, _draw() bleeds past the Control's rect into the
	# adjacent UI — the hex grid in particular spills into the right column.
	clip_contents = true

	SessionState.current_map_changed.connect(_on_current_map_changed)
	SessionState.current_map_metadata_changed.connect(func(_m): queue_redraw())
	SessionState.hex_grid_visibility_changed.connect(func(_v): queue_redraw())
	SessionState.projector_viewport_size_changed.connect(func(_s): queue_redraw())
	SessionState.token_added.connect(func(_id, _d): queue_redraw())
	SessionState.token_removed.connect(func(_id): queue_redraw())
	SessionState.token_moved.connect(func(_id, _p): queue_redraw())
	SessionState.token_data_changed.connect(func(_id, _d): queue_redraw())
	SessionState.token_selection_changed.connect(func(_id): queue_redraw())
	SessionState.tokens_reloaded.connect(queue_redraw)
	SessionState.current_sector_overlay_changed.connect(func(_o): queue_redraw())
	SessionState.facility_state_changed.connect(queue_redraw)
	SessionState.sector_tier_changed.connect(func(_id, _t): queue_redraw())
	SessionState.sector_selection_changed.connect(func(_id): queue_redraw())
	# Mirror the projector's scene tint (mood × time-of-day/season lighting).
	SessionState.current_scene_mood_changed.connect(func(_m): queue_redraw())
	SessionState.scene_lighting_changed.connect(func(_t): queue_redraw())
	SessionState.ping_emitted.connect(_on_ping)

	resized.connect(queue_redraw)

	if SessionState.current_map_path != "":
		_load_map_texture(SessionState.current_map_path)

	_build_effect_mirror()
	resized.connect(_layout_effect_mirror)
	SessionState.projector_viewport_size_changed.connect(func(_s): _layout_effect_mirror())
	SessionState.scene_effects_changed.connect(func(_e): _layout_effect_mirror())
	SessionState.current_scene_mood_changed.connect(func(_m): _layout_effect_mirror())


# --- Effect mirror (weather particles) ------------------------------------
#
# Without this the GM preview silently lied: the projector rained on the
# players and the operator's own view stayed dry.
func _build_effect_mirror() -> void:
	_fx_clip = Control.new()
	_fx_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_clip.clip_contents = true   # keep weather inside the 16:9 stage, not the pane
	add_child(_fx_clip)

	_fx_root = Node2D.new()
	_fx_clip.add_child(_fx_root)

	_fx_particles = ProjectorScript.ParticleLayer.new()
	_fx_root.add_child(_fx_particles)
	_layout_effect_mirror()


func _layout_effect_mirror() -> void:
	if _fx_clip == null or _fx_particles == null:
		return
	var stage := _stage_rect()
	_fx_clip.position = stage.position
	_fx_clip.size = stage.size
	# ParticleLayer's presets are laid out around their own origin, so centre
	# the root in the stage the way the projector's Camera2D centres its own.
	_fx_root.position = stage.size * 0.5
	_fx_particles.bounds_override = stage.size
	_fx_particles.world_scale = _preview_per_world()
	_fx_particles.call("_reapply")


func _on_current_map_changed(path: String) -> void:
	_load_map_texture(path)
	queue_redraw()


func _load_map_texture(path: String) -> void:
	_map_texture = load(path) as Texture2D


func _on_ping(world_pos: Vector2) -> void:
	_ping_pos = world_pos
	_ping_t = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_ping_t += delta / _PING_DURATION
	if _ping_t >= 1.0:
		_ping_t = 1.0
		set_process(false)
	queue_redraw()


# Combined scene tint = mood tint × lighting tint (time-of-day × season).
func _scene_tint() -> Color:
	var mood: Color = SessionState.get_current_scene_mood_data().get("tint", Color(1, 1, 1, 1))
	var light: Color = SessionState.compute_scene_tint()
	return Color(mood.r * light.r, mood.g * light.g, mood.b * light.b, 1.0)


# === Drawing ==============================================================

func _draw() -> void:
	var stage := _stage_rect()
	# Bezel — the pane area outside the 16:9 projector frame.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.06))
	# The stage = exactly what the projector shows (its 16:9 frame).
	draw_rect(stage, Color(0.09, 0.09, 0.12))

	var map_rect := _get_map_display_rect()

	# Map — modulated by the scene tint (mood × lighting) so the GM preview
	# reflects the projector's atmosphere. draw_texture_rect's modulate arg
	# multiplies the texture, matching the projector's multiplicative tint.
	if _map_texture != null:
		draw_texture_rect(_map_texture, map_rect, false, _scene_tint())

	# Sector overlay (between map and hex/token layers) — mirrors the
	# projector's SectorOverlay so the GM sees the same polygons.
	_draw_sector_overlay(map_rect)

	# Hex overlay
	if SessionState.hex_grid_visible:
		_draw_hex_overlay()

	# Tokens
	var base_radius_world := SessionState.get_current_hex_radius_px() * TOKEN_TO_HEX_RATIO
	var px_per_world := _preview_per_world()
	for id in SessionState.tokens:
		var data: Dictionary = SessionState.tokens[id]
		var world_pos: Vector2 = data.get("position", Vector2.ZERO)
		var preview_pos := _world_to_preview(world_pos)
		var size_mult := SessionState.token_size_multiplier(data.get("size", "medium"))
		var preview_radius := base_radius_world * size_mult * px_per_world
		var token_color: Color = data.get("color", Color.WHITE)
		draw_circle(preview_pos, preview_radius, token_color)
		draw_arc(preview_pos, preview_radius, 0.0, TAU, 24, Color(0, 0, 0, 0.85), 1.5, true)
		# Selection ring (cyan) on the inspected token; drag ring (yellow) wins.
		if id == SessionState.selected_token_id and id != _dragging_token_id:
			draw_arc(preview_pos, preview_radius + 3.0, 0.0, TAU, 32, Color(0.30, 0.90, 1.0, 0.9), 2.0, true)
		if id == _dragging_token_id:
			draw_arc(preview_pos, preview_radius + 4.0, 0.0, TAU, 32, Color.YELLOW, 2.0, true)
		if data.get("is_combatant", false):
			_draw_token_bars(preview_pos, preview_radius, data)
		var label_text: String = data.get("label", data.get("name", ""))
		if label_text != "":
			_draw_token_label(preview_pos, preview_radius, label_text)
		if data.get("is_combatant", false):
			var statuses: Array = data.get("statuses", [])
			if not statuses.is_empty():
				_draw_token_statuses(preview_pos, preview_radius, statuses)

	# Ping pulse (mirrors the projector), within the stage.
	if _ping_t < 1.0:
		var ppw := _preview_per_world()
		var ppos := _world_to_preview(_ping_pos)
		var alpha := 1.0 - _ping_t
		for k in [0.0, 0.35]:
			var p: float = clampf(_ping_t - k, 0.0, 1.0)
			var r: float = (20.0 + _PING_MAX_RADIUS_WORLD * p) * ppw
			draw_arc(ppos, r, 0.0, TAU, 40, Color(1.0, 0.9, 0.3, alpha * (1.0 - p)), 2.0, true)

	# Mask anything that spilled outside the 16:9 stage — edge hexes, or tokens
	# positioned beyond the projected frame — so the preview shows EXACTLY what
	# the projector shows (which clips at its viewport edge). clip_contents only
	# clips to the whole pane, not the stage, so we paint the bezel back over.
	_draw_bezel_mask(stage)

	# Projector-frame border on top, so the GM sees the exact 16:9 boundary
	# of what's being projected.
	draw_rect(stage, Color(0.40, 0.45, 0.60, 0.85), false, 2.0)


func _draw_bezel_mask(stage: Rect2) -> void:
	var bezel := Color(0.05, 0.05, 0.06)
	var s := stage
	# Four bands covering the pane area outside the stage.
	draw_rect(Rect2(0, 0, size.x, s.position.y), bezel)                                  # top
	draw_rect(Rect2(0, s.end.y, size.x, size.y - s.end.y), bezel)                        # bottom
	draw_rect(Rect2(0, s.position.y, s.position.x, s.size.y), bezel)                     # left
	draw_rect(Rect2(s.end.x, s.position.y, size.x - s.end.x, s.size.y), bezel)           # right


func _draw_token_label(center: Vector2, radius: float, text: String) -> void:
	var font := ThemeDB.fallback_font
	var font_size := int(max(10.0, radius * 0.55))
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := center.x - text_width * 0.5
	var y := center.y + radius + font_size + 3
	font.draw_string(get_canvas_item(), Vector2(x + 1, y + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.85))
	font.draw_string(get_canvas_item(), Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_token_bars(center: Vector2, radius: float, data: Dictionary) -> void:
	var bar_w := radius * 2.0
	var hp_h: float = max(3.0, radius * 0.16)
	var fp_h: float = max(2.0, radius * 0.12)
	var gap := 1.0
	var hp_top := center.y - radius - hp_h - 4.0
	var fp_top := hp_top - fp_h - gap
	var hp_max: int = max(1, int(data.get("hp_max", 10)))
	var hp_cur: int = int(data.get("hp_current", hp_max))
	var fp_max: int = max(1, int(data.get("fp_max", 10)))
	var fp_cur: int = int(data.get("fp_current", fp_max))
	var hp_color := Color(0.35, 0.85, 0.35)
	if hp_cur <= 0:
		hp_color = Color(0.85, 0.15, 0.15)
	elif float(hp_cur) / float(hp_max) <= 0.333:
		hp_color = Color(0.95, 0.80, 0.20)
	_draw_preview_bar(Rect2(Vector2(center.x - bar_w * 0.5, hp_top), Vector2(bar_w, hp_h)), float(hp_cur) / float(hp_max), hp_color)
	_draw_preview_bar(Rect2(Vector2(center.x - bar_w * 0.5, fp_top), Vector2(bar_w, fp_h)), float(fp_cur) / float(fp_max), Color(0.40, 0.65, 0.95))


func _draw_preview_bar(rect: Rect2, ratio: float, fg: Color) -> void:
	var r := clampf(ratio, 0.0, 1.0)
	draw_rect(Rect2(rect.position - Vector2(1, 1), rect.size + Vector2(2, 2)), Color(0, 0, 0, 0.85))
	draw_rect(rect, Color(0.18, 0.18, 0.18, 0.9))
	if r > 0.0:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * r, rect.size.y)), fg)


func _draw_token_statuses(center: Vector2, radius: float, statuses: Array) -> void:
	var font := ThemeDB.fallback_font
	var label_font_size := int(max(10.0, radius * 0.55))
	var disk_r: float = max(5.0, radius * 0.20)
	var spacing := disk_r * 2.4
	var row_w := spacing * statuses.size() - (spacing - disk_r * 2.0)
	var x0 := center.x - row_w * 0.5 + disk_r
	var y := center.y + radius + label_font_size + disk_r + 8.0
	var font_size := int(disk_r * 1.4)
	for i in statuses.size():
		var status_id: String = statuses[i]
		var meta: Dictionary = SessionState.status_display(status_id)
		if meta.is_empty():
			continue
		var c := Vector2(x0 + i * spacing, y)
		draw_circle(c, disk_r, meta.get("color", Color.WHITE))
		draw_arc(c, disk_r, 0.0, TAU, 16, Color(0, 0, 0, 0.85), 1.0, true)
		var letter: String = meta.get("letter", "?")
		var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		font.draw_string(get_canvas_item(), c + Vector2(-text_size.x * 0.5, text_size.y * 0.35), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)


func _draw_sector_overlay(map_rect: Rect2) -> void:
	if _map_texture == null:
		return
	var overlay: Dictionary = SessionState.current_sector_overlay
	var sectors: Array = overlay.get("sectors", [])
	if sectors.is_empty():
		return
	var tex_size := _map_texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return
	var font := ThemeDB.fallback_font
	var selected_id: String = SessionState.current_selected_sector_id
	for sector in sectors:
		if not (sector is Dictionary):
			continue
		_draw_sector_preview(sector, map_rect, tex_size, font, selected_id)


func _draw_sector_preview(sector: Dictionary, map_rect: Rect2, tex_size: Vector2, font: Font, selected_id: String) -> void:
	var id: String = sector.get("id", "")
	var raw_polygon: Array = sector.get("polygon", [])
	if raw_polygon.size() < 3:
		return
	var points := PackedVector2Array()
	for p in raw_polygon:
		if not (p is Array) or p.size() < 2:
			continue
		points.append(_map_px_to_preview(Vector2(p[0], p[1]), map_rect, tex_size))
	if points.size() < 3:
		return

	var tier: int = SessionState.get_sector_tier(id)
	var fill := _sector_tier_color(tier)
	draw_colored_polygon(points, fill)
	var loop := points.duplicate()
	loop.append(points[0])
	draw_polyline(loop, Color(fill.r * 0.4, fill.g * 0.4, fill.b * 0.4, 0.9), 1.5, true)

	if SessionState.is_sector_upgrading(id):
		draw_polyline(loop, Color(0.95, 0.55, 0.20, 0.85), 2.0, true)
	if id != "" and id == selected_id:
		draw_polyline(loop, Color(0.95, 0.95, 0.30, 0.95), 2.0, true)

	var anchor_raw: Array = sector.get("label_anchor", [])
	if anchor_raw.size() >= 2:
		var anchor := _map_px_to_preview(Vector2(anchor_raw[0], anchor_raw[1]), map_rect, tex_size)
		var name_text: String = sector.get("name", id)
		var badge_text := "%s [T%d]" % [name_text, tier]
		# Mirror the projector: dark pill behind centered text for legibility.
		var font_size := 11 if sector.get("ring", "") == "inner" else 12
		var tw := font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var ascent := font.get_ascent(font_size)
		var text_h := ascent + font.get_descent(font_size)
		var box := Rect2(anchor.x - tw * 0.5, anchor.y - text_h * 0.5, tw, text_h)
		var pad := Vector2(font_size * 0.45, font_size * 0.28)
		_draw_pill(Rect2(box.position - pad, box.size + pad * 2.0), Color(0.03, 0.05, 0.09, 0.66))
		font.draw_string(get_canvas_item(), Vector2(box.position.x, box.position.y + ascent), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.97, 0.98, 1.0))


func _draw_pill(rect: Rect2, col: Color) -> void:
	# Rounded dark backdrop (matches projector.gd). Full-height center bar + caps.
	var r: float = min(rect.size.y * 0.5, 9.0)
	draw_rect(Rect2(rect.position + Vector2(r, 0), Vector2(rect.size.x - r * 2.0, rect.size.y)), col)
	draw_circle(rect.position + Vector2(r, rect.size.y * 0.5), r, col)
	draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y * 0.5), r, col)


func _sector_tier_color(tier: int) -> Color:
	# Mirror projector.gd SectorOverlay.TIER_COLORS so the GM preview matches.
	match tier:
		2: return Color(0.55, 0.72, 0.92, 0.52)  # bright steel-blue — industrial
		3: return Color(0.97, 0.80, 0.32, 0.62)  # gold — ATA modern
		_: return Color(0.30, 0.42, 0.50, 0.38)  # muted teal — atlantean baseline


func _map_px_to_preview(p: Vector2, map_rect: Rect2, tex_size: Vector2) -> Vector2:
	return map_rect.position + Vector2(
		p.x / tex_size.x * map_rect.size.x,
		p.y / tex_size.y * map_rect.size.y,
	)


func _preview_to_map_px(preview: Vector2, map_rect: Rect2, tex_size: Vector2) -> Vector2:
	if map_rect.size.x <= 0 or map_rect.size.y <= 0:
		return Vector2.ZERO
	return Vector2(
		(preview.x - map_rect.position.x) / map_rect.size.x * tex_size.x,
		(preview.y - map_rect.position.y) / map_rect.size.y * tex_size.y,
	)


func _draw_hex_overlay() -> void:
	var hex_radius_world := SessionState.get_current_hex_radius_px()
	var preview_radius := hex_radius_world * _preview_per_world()
	if preview_radius < 4.0:
		return  # too small to be useful at this zoom
	var hx_spacing := sqrt(3.0) * preview_radius
	var vy_spacing := 1.5 * preview_radius
	var stage := _stage_rect()
	var rows := int(stage.size.y / vy_spacing) + 2
	var cols := int(stage.size.x / hx_spacing) + 2

	# Align the preview hex grid to the projector world grid: the projector's
	# grid origin (top-left of its viewport) maps to the stage's top-left.
	var projector_size: Vector2 = SessionState.projector_viewport_size
	var projector_grid_origin := -projector_size * 0.5
	var preview_grid_origin := _world_to_preview(projector_grid_origin)
	var x0 := preview_grid_origin.x
	var y0 := preview_grid_origin.y

	for row in rows:
		for col in cols:
			var x_offset: float = (hx_spacing * 0.5) if (row % 2 == 1) else 0.0
			var center := Vector2(
				x0 + col * hx_spacing + x_offset,
				y0 + row * vy_spacing,
			)
			# Keep hexes inside the 16:9 stage (don't spill into the bezel).
			if stage.has_point(center):
				_draw_hex_at(center, preview_radius)


func _draw_hex_at(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in 6:
		var angle: float = PI / 3.0 * i - PI / 2.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	points.append(points[0])
	draw_polyline(points, Color(0, 0, 0, 0.42), 1.0, true)


# === Coordinate transforms ===============================================

# The "stage" is the largest rect matching the projector's aspect ratio
# (1920x1080 = 16:9) centered in this control. It IS the projector frame: the
# preview is a faithful, letterboxed mirror of what's projected. Everything
# (map, hex, tokens, world coords) is fitted relative to the stage, so the GM
# tablet shows exactly the projector's 16:9 output regardless of the pane's
# own aspect.
func _stage_rect() -> Rect2:
	var proj: Vector2 = SessionState.projector_viewport_size
	var aspect: float = (proj.x / proj.y) if proj.y > 0.0 else (16.0 / 9.0)
	var w: float = size.x
	var h: float = w / aspect
	if h > size.y:
		h = size.y
		w = h * aspect
	return Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))


func _get_map_display_rect() -> Rect2:
	var stage := _stage_rect()
	if _map_texture == null:
		return stage
	var tex_size := _map_texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return stage
	# Mirror the projector's contain-fit *including* the per-map fit fraction
	# (projector.gd _refit_sprite), so a map that sits inside a backdrop —
	# the Atlantis home base in its crater — is the same size in both views.
	var scale_factor: float = min(
		stage.size.x / tex_size.x,
		stage.size.y / tex_size.y,
	) * SessionState.current_map_fit
	var display_size := tex_size * scale_factor
	var origin := stage.position + (stage.size - display_size) * 0.5
	return Rect2(origin, display_size)


func _preview_per_world() -> float:
	# Uniform preview-pixels-per-world-pixel: the stage and the projector
	# viewport share the same aspect, so this is simply stage width / projector
	# width (== stage height / projector height).
	var projector_size: Vector2 = SessionState.projector_viewport_size
	if projector_size.x <= 0:
		return 1.0
	return _stage_rect().size.x / projector_size.x


func _stage_center() -> Vector2:
	var stage := _stage_rect()
	return stage.position + stage.size * 0.5


func _world_to_preview(world: Vector2) -> Vector2:
	return world * _preview_per_world() + _stage_center()


func _preview_to_world(preview: Vector2) -> Vector2:
	var ratio := _preview_per_world()
	if ratio == 0.0:
		return Vector2.ZERO
	return (preview - _stage_center()) / ratio


# === Mouse input ==========================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_try_begin_drag(event.position)
			else:
				_end_drag()
	elif event is InputEventMouseMotion:
		if _dragging_token_id != -1:
			_continue_drag(event.position)


func _try_begin_drag(preview_pos: Vector2) -> void:
	# Ping mode: this click drops a ping at the map location instead of dragging.
	if SessionState.ping_armed:
		SessionState.emit_ping(_preview_to_world(preview_pos))
		SessionState.set_ping_armed(false)
		return
	var base_radius_world := SessionState.get_current_hex_radius_px() * TOKEN_TO_HEX_RATIO
	var px_per_world := _preview_per_world()
	# Search in reverse order so visually-top tokens get hit first.
	var ids := SessionState.tokens.keys()
	ids.reverse()
	for id in ids:
		var data: Dictionary = SessionState.tokens[id]
		var token_preview_pos := _world_to_preview(data.get("position", Vector2.ZERO))
		var size_mult := SessionState.token_size_multiplier(data.get("size", "medium"))
		var preview_radius := base_radius_world * size_mult * px_per_world
		if preview_pos.distance_to(token_preview_pos) <= preview_radius:
			_dragging_token_id = id
			_drag_offset_world = data.get("position", Vector2.ZERO) - _preview_to_world(preview_pos)
			# Clicking a token also selects it (opens the inspector) — matches
			# how clicking a sector selects it.
			SessionState.select_token(id)
			queue_redraw()
			return
	# No token hit — fall through to sector selection on the same click.
	_try_select_sector(preview_pos)


func _try_select_sector(preview_pos: Vector2) -> void:
	if _map_texture == null:
		return
	var overlay: Dictionary = SessionState.current_sector_overlay
	var sectors: Array = overlay.get("sectors", [])
	if sectors.is_empty():
		# Click outside any sector clears selection — but only when an
		# overlay actually exists for this map.
		return
	var map_rect := _get_map_display_rect()
	if not map_rect.has_point(preview_pos):
		SessionState.select_sector("")
		return
	var tex_size := _map_texture.get_size()
	var map_px := _preview_to_map_px(preview_pos, map_rect, tex_size)
	# Hit-test in map-pixel space — cheaper and natural since polygons are
	# already authored there.
	for sector in sectors:
		if not (sector is Dictionary):
			continue
		var raw: Array = sector.get("polygon", [])
		if raw.size() < 3:
			continue
		var poly := PackedVector2Array()
		for p in raw:
			if not (p is Array) or p.size() < 2:
				continue
			poly.append(Vector2(p[0], p[1]))
		if poly.size() >= 3 and Geometry2D.is_point_in_polygon(map_px, poly):
			SessionState.select_sector(sector.get("id", ""))
			return
	SessionState.select_sector("")


func _continue_drag(preview_pos: Vector2) -> void:
	if _dragging_token_id == -1:
		return
	var new_world := _preview_to_world(preview_pos) + _drag_offset_world
	SessionState.move_token(_dragging_token_id, new_world)


func _end_drag() -> void:
	if _dragging_token_id == -1:
		return
	# Snap to nearest hex center if hex grid is visible.
	if SessionState.hex_grid_visible:
		var data: Dictionary = SessionState.tokens.get(_dragging_token_id, {})
		var current: Vector2 = data.get("position", Vector2.ZERO)
		var snapped := _snap_to_nearest_hex(current)
		SessionState.move_token(_dragging_token_id, snapped)
	_dragging_token_id = -1
	queue_redraw()


# === Hex snap =============================================================

func _snap_to_nearest_hex(world: Vector2) -> Vector2:
	# Find the hex center (in projector world space) closest to `world`.
	# Pointy-top layout, origin at the projector world center.
	var radius := SessionState.get_current_hex_radius_px()
	var hx_spacing := sqrt(3.0) * radius
	var vy_spacing := 1.5 * radius

	var projector_size: Vector2 = SessionState.projector_viewport_size
	var grid_origin := -projector_size * 0.5

	var relative := world - grid_origin
	var approx_row := int(round(relative.y / vy_spacing))
	var x_offset: float = (hx_spacing * 0.5) if (approx_row % 2 == 1) else 0.0
	var approx_col := int(round((relative.x - x_offset) / hx_spacing))

	# Check the candidate cell and its 6 neighbors; pick the nearest.
	var best := Vector2.ZERO
	var best_dist := INF
	for d_row in [-1, 0, 1]:
		for d_col in [-1, 0, 1]:
			var row: int = approx_row + d_row
			var col: int = approx_col + d_col
			var x_off: float = (hx_spacing * 0.5) if (row % 2 == 1) else 0.0
			var center := grid_origin + Vector2(
				col * hx_spacing + x_off,
				row * vy_spacing,
			)
			var dist := center.distance_squared_to(world)
			if dist < best_dist:
				best_dist = dist
				best = center
	return best
