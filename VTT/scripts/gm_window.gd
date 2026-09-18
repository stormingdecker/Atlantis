extends Control

# GM control panel.
#
# Layout:
#   Title bar
#   HSplitContainer:
#     [left]  MapPreview — scaled mirror of projector with drag-to-move tokens
#     [right] Tabbed-section control column (maps / tokens / audio)
#
# All state changes flow through the SessionState autoload. This script
# only translates user input into SessionState mutations and reflects
# SessionState back into the UI.

const MapPreview := preload("res://scripts/map_preview.gd")

const TOKEN_PALETTE: Array[Color] = [
	Color(0.95, 0.40, 0.40),  # red
	Color(0.40, 0.70, 0.95),  # blue
	Color(0.50, 0.85, 0.40),  # green
	Color(0.95, 0.85, 0.30),  # yellow
	Color(0.85, 0.50, 0.85),  # purple
	Color(0.95, 0.65, 0.30),  # orange
	Color(0.30, 0.80, 0.80),  # cyan
	Color(0.95, 0.55, 0.70),  # pink
]

var _next_token_palette_index: int = 0

# UI references — populated in _build_ui.
# Campaign -> Mission -> Area -> Map navigation (v0.9).
var _campaign_dropdown: OptionButton
var _campaign_ids: Array[String] = []     # dropdown row -> campaign id
var _mission_dropdown: OptionButton
var _mission_ids: Array[String] = []      # dropdown row -> mission id
var _mission_blurb: Label
var _area_list: ItemList
var _area_ids: Array[String] = []         # row -> area id
var _area_map_list: ItemList
var _area_map_ids: Array[String] = []     # row -> map id
var _staged_label: Label
var _seq_continue_btn: Button
var _seq_skip_btn: Button
var _adjacency_box: HBoxContainer

# Prep/Live mode (DESIGN §6.1). Live hides the setup-only sections so the
# controls touched constantly while running a scene are reachable without
# scroll-hunting. Section wrappers below are toggled by _apply_mode.
var _mode_live: bool = false
var _right_scroll: ScrollContainer
var _prep_btn: Button
var _live_btn: Button
var _briefing_toggle: Button
var _briefing_panel: BriefingPanel
var _maps_wrap: Control
var _audio_wrap: Control
var _facility_wrap: Control
var _calib_wrap: Control
var _calib_label: Label
var _map_list: ItemList
var _hex_toggle: CheckButton
var _blackout_toggle: CheckButton
var _ping_btn: Button
var _handout_list: ItemList
var _handout_paths: Array[String] = []
var _token_list: ItemList
var _suite_dropdown: OptionButton
var _tier_buttons: Dictionary = {}  # tier (String) -> Button
var _music_list: ItemList
var _sfx_list: ItemList
var _token_label_edit: LineEdit
var _token_size_dropdown: OptionButton
var _mood_dropdown: OptionButton
var _tod_slider: HSlider
var _tod_label: Label
var _season_slider: HSlider
var _season_label: Label

# Combat inspector widgets.
var _token_combatant_toggle: CheckBox
var _token_hp_current_spin: SpinBox
var _token_hp_max_spin: SpinBox
var _token_fp_current_spin: SpinBox
var _token_fp_max_spin: SpinBox
var _token_basic_speed_spin: SpinBox
var _token_status_checks: Dictionary = {}  # status_id (String) -> CheckBox
var _suppress_inspector_signals: bool = false

# Combat section widgets.
var _combat_round_label: Label
var _combat_active_label: Label
var _combat_start_btn: Button
var _combat_next_btn: Button
var _combat_end_btn: Button
var _combat_order_box: VBoxContainer

# Ordered suite ids matching _suite_dropdown rows.
var _suite_ids: Array[String] = []
# Ordered mood ids matching _mood_dropdown rows.
var _mood_ids: Array[String] = []
# The token currently shown in the inspector (-1 = none).
var _inspected_token_id: int = -1

# Facility section (v0.8).
var _facility_section: Control
var _facility_tp_label: Label
var _facility_tp_spin: SpinBox
var _facility_sector_list: ItemList
var _facility_sector_ids: Array[String] = []  # row -> sector_id
var _facility_sector_tier_dropdown: OptionButton
var _facility_sector_upgrading_toggle: CheckBox
var _facility_selected_label: Label
var _facility_ru_list: ItemList
var _facility_ru_input: LineEdit

# Token id is stored in each ItemList row's metadata (NOT matched by label —
# labels can collide, e.g. a mob of "Goblin"s). These helpers read it back.
func _token_id_at(row: int) -> int:
	if row < 0 or row >= _token_list.item_count:
		return -1
	var md = _token_list.get_item_metadata(row)
	return int(md) if md != null else -1


func _row_for_token(id: int) -> int:
	for r in _token_list.item_count:
		if _token_id_at(r) == id:
			return r
	return -1


func _ready() -> void:
	_build_ui()
	_wire_session_signals()
	_refresh_map_list()
	_refresh_music_list()
	_refresh_sfx_list()
	_refresh_suite_dropdown()
	_refresh_tier_highlight()
	_refresh_mood_dropdown()
	_refresh_token_inspector()
	_refresh_combat_section()
	_refresh_facility_section()
	_refresh_handout_list()
	_refresh_campaign_dropdown()


# === UI construction ======================================================

func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.anchor_right = 1.0
	root_vbox.anchor_bottom = 1.0
	root_vbox.offset_left = 12
	root_vbox.offset_top = 12
	root_vbox.offset_right = -12
	root_vbox.offset_bottom = -12
	root_vbox.add_theme_constant_override("separation", 8)
	add_child(root_vbox)

	# Title row — title on the left, Prep/Live mode toggle on the right.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	root_vbox.add_child(title_row)

	var title := Label.new()
	title.text = "Atlantis VTT — GM Control"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var mode_group := ButtonGroup.new()
	_prep_btn = Button.new()
	_prep_btn.text = "Prep"
	_prep_btn.toggle_mode = true
	_prep_btn.button_group = mode_group
	_prep_btn.tooltip_text = "Setup mode — all sections (maps, audio, facility) visible."
	_prep_btn.pressed.connect(func(): _apply_mode(false))
	title_row.add_child(_prep_btn)

	_live_btn = Button.new()
	_live_btn.text = "Live"
	_live_btn.toggle_mode = true
	_live_btn.button_group = mode_group
	_live_btn.tooltip_text = "Running mode — hides setup sections so the live controls are reachable without scrolling."
	_live_btn.pressed.connect(func(): _apply_mode(true))
	title_row.add_child(_live_btn)

	# Briefing toggle — overlays a GM-only reference/parchment map on the left
	# pane (never projected). Disabled when the current scene has no briefing.
	_briefing_toggle = Button.new()
	_briefing_toggle.text = "Briefing"
	_briefing_toggle.toggle_mode = true
	_briefing_toggle.disabled = true
	_briefing_toggle.tooltip_text = "Show this scene's GM briefing map over the preview (GM-only; not projected)."
	_briefing_toggle.toggled.connect(_on_briefing_toggled)
	title_row.add_child(_briefing_toggle)

	root_vbox.add_child(HSeparator.new())

	# Main split. The GM works mostly with physical props on the table, so the
	# control panel is the priority — give the preview a smaller pane (it still
	# letterboxes to the projector's 16:9 internally) and a wide control column.
	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Negative offset shrinks the preview below the 50/50 baseline so the
	# control panel gets the majority of the width (GM works off physical props).
	split.split_offset = -360
	root_vbox.add_child(split)

	# Left pane stacks the live preview and a GM-only briefing overlay (hidden
	# until toggled). Both fill the pane; the briefing sits on top when visible.
	var left_pane := Control.new()
	left_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left_pane)

	var preview := MapPreview.new()
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_pane.add_child(preview)

	_briefing_panel = BriefingPanel.new()
	_briefing_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_briefing_panel.visible = false
	left_pane.add_child(_briefing_panel)

	_right_scroll = ScrollContainer.new()
	_right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(_right_scroll)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 14)
	_right_scroll.add_child(right_vbox)

	# Section order: live-critical first (visible in both modes), setup-only
	# last (hidden in Live). Each section is wrapped so hiding it also hides
	# its leading separator.
	_add_section(right_vbox, _build_missions_section())      # stage + adjacency + sequence
	_add_section(right_vbox, _build_event_bar_section())     # hex / blackout / ping
	_add_section(right_vbox, _build_combat_section())
	_add_section(right_vbox, _build_tokens_section())
	_add_section(right_vbox, _build_atmosphere_section())
	_add_section(right_vbox, _build_handouts_section())
	# Prep-only (hidden in Live mode):
	_maps_wrap = _add_section(right_vbox, _build_maps_section())
	_audio_wrap = _add_section(right_vbox, _build_audio_section())
	_calib_wrap = _add_section(right_vbox, _build_calibration_section())
	_facility_section = _build_facility_section()
	_facility_wrap = _add_section(right_vbox, _facility_section)

	# Start in Prep (all sections visible).
	_prep_btn.set_pressed_no_signal(true)
	_apply_mode(false)


func _add_section(parent: Control, section: Control) -> Control:
	# Wrap [leading separator + section] so a section and its separator hide
	# together with the wrapper.
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 14)
	wrap.add_child(HSeparator.new())
	wrap.add_child(section)
	parent.add_child(wrap)
	return wrap


func _apply_mode(live: bool) -> void:
	_mode_live = live
	for w in [_maps_wrap, _audio_wrap, _calib_wrap, _facility_wrap]:
		if w != null:
			w.visible = not live


# --- Table calibration (v0.14) -------------------------------------------

func _build_calibration_section() -> Control:
	const STEP := 10.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(_section_header("Table Calibration"))

	var hint := Label.new()
	hint.text = "Align the projected map + grid to your physical grid mat. Persists across launches."
	hint.modulate = Color(0.65, 0.65, 0.65)
	hint.add_theme_font_size_override("font_size", 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	var pan := HBoxContainer.new()
	pan.add_theme_constant_override("separation", 6)
	box.add_child(pan)
	var pan_lbl := Label.new()
	pan_lbl.text = "Pan"
	pan_lbl.custom_minimum_size = Vector2(64, 0)
	pan.add_child(pan_lbl)
	for spec in [["←", Vector2(-STEP, 0)], ["→", Vector2(STEP, 0)], ["↑", Vector2(0, -STEP)], ["↓", Vector2(0, STEP)]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(SessionState.nudge_calibration.bind(spec[1]))
		pan.add_child(b)

	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 6)
	box.add_child(sr)
	var s_lbl := Label.new()
	s_lbl.text = "Scale"
	s_lbl.custom_minimum_size = Vector2(64, 0)
	sr.add_child(s_lbl)
	var zout := Button.new()
	zout.text = "−"
	zout.pressed.connect(SessionState.adjust_calibration_zoom.bind(-0.02))
	sr.add_child(zout)
	var zin := Button.new()
	zin.text = "+"
	zin.pressed.connect(SessionState.adjust_calibration_zoom.bind(0.02))
	sr.add_child(zin)

	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 6)
	box.add_child(rr)
	var r_lbl := Label.new()
	r_lbl.text = "Rotate"
	r_lbl.custom_minimum_size = Vector2(64, 0)
	rr.add_child(r_lbl)
	var rccw := Button.new()
	rccw.text = "⟲"
	rccw.pressed.connect(SessionState.adjust_calibration_rotation.bind(-1.0))
	rr.add_child(rccw)
	var rcw := Button.new()
	rcw.text = "⟳"
	rcw.pressed.connect(SessionState.adjust_calibration_rotation.bind(1.0))
	rr.add_child(rcw)
	var reset := Button.new()
	reset.text = "Reset"
	reset.pressed.connect(SessionState.reset_calibration)
	rr.add_child(reset)

	_calib_label = Label.new()
	_calib_label.modulate = Color(0.8, 0.8, 0.9)
	_calib_label.add_theme_font_size_override("font_size", 11)
	box.add_child(_calib_label)
	_refresh_calibration_label()
	return box


func _refresh_calibration_label() -> void:
	if _calib_label == null:
		return
	_calib_label.text = "Pan (%d, %d)   Scale %.2f×   Rotate %.0f°" % [
		int(SessionState.calibration_offset.x), int(SessionState.calibration_offset.y),
		SessionState.calibration_zoom, SessionState.calibration_rotation_deg]


# --- Campaign -> Mission -> Area -> Map (v0.9) ---------------------------
#
# Pick a campaign, then a mission, then an area; click a map to stage the
# whole scene (map + music + lighting + hex) in one action. Data is the
# Campaign->Mission->Area->Map tree in SessionState.campaigns (scanned by
# main.gd from assets/campaigns/, or shimmed from the legacy missions/ tree).

func _build_missions_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	box.add_child(_section_header("Mission"))

	_campaign_dropdown = OptionButton.new()
	_campaign_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campaign_dropdown.item_selected.connect(_on_campaign_selected)
	box.add_child(_campaign_dropdown)

	_mission_dropdown = OptionButton.new()
	_mission_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_dropdown.item_selected.connect(_on_mission_selected)
	box.add_child(_mission_dropdown)

	_mission_blurb = Label.new()
	_mission_blurb.modulate = Color(0.65, 0.65, 0.65)
	_mission_blurb.add_theme_font_size_override("font_size", 11)
	_mission_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_mission_blurb)

	var area_caption := Label.new()
	area_caption.text = "Areas"
	area_caption.modulate = Color(0.75, 0.75, 0.85)
	area_caption.add_theme_font_size_override("font_size", 12)
	box.add_child(area_caption)

	_area_list = ItemList.new()
	_area_list.custom_minimum_size = Vector2(0, 90)
	_area_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area_list.item_selected.connect(_on_area_selected)
	box.add_child(_area_list)

	var map_caption := Label.new()
	map_caption.text = "Maps (click to stage)"
	map_caption.modulate = Color(0.75, 0.75, 0.85)
	map_caption.add_theme_font_size_override("font_size", 12)
	box.add_child(map_caption)

	_area_map_list = ItemList.new()
	_area_map_list.custom_minimum_size = Vector2(0, 90)
	_area_map_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area_map_list.item_activated.connect(_on_area_map_activated)
	_area_map_list.item_selected.connect(_on_area_map_activated)
	box.add_child(_area_map_list)

	_staged_label = Label.new()
	_staged_label.text = "(nothing staged)"
	_staged_label.modulate = Color(0.85, 0.85, 0.95)
	_staged_label.add_theme_font_size_override("font_size", 11)
	_staged_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_staged_label)

	# Entrance-sequence controls (on_enter): Continue advances a wait_for step;
	# Skip aborts the whole sequence. Disabled unless a sequence is active.
	var seq_row := HBoxContainer.new()
	seq_row.add_theme_constant_override("separation", 6)
	box.add_child(seq_row)
	_seq_continue_btn = Button.new()
	_seq_continue_btn.text = "Continue (Space)"
	_seq_continue_btn.disabled = true
	_seq_continue_btn.pressed.connect(SessionState.advance_sequence)
	seq_row.add_child(_seq_continue_btn)
	_seq_skip_btn = Button.new()
	_seq_skip_btn.text = "Skip"
	_seq_skip_btn.disabled = true
	_seq_skip_btn.pressed.connect(SessionState.cancel_sequence)
	seq_row.add_child(_seq_skip_btn)

	# Quick-jump buttons to the staged map's adjacent neighbors (one-tap move
	# around a multi-map area). Rebuilt on each stage.
	_adjacency_box = HBoxContainer.new()
	_adjacency_box.add_theme_constant_override("separation", 6)
	box.add_child(_adjacency_box)

	var hint := Label.new()
	hint.text = "Click a map to stage it — swaps the map, music, lighting, and VFX live on the projector."
	hint.modulate = Color(0.6, 0.6, 0.6)
	hint.add_theme_font_size_override("font_size", 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	return box


func _build_maps_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	box.add_child(_section_header("Maps"))

	_map_list = ItemList.new()
	_map_list.custom_minimum_size = Vector2(0, 160)
	_map_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_list.item_activated.connect(_on_map_item_activated)
	_map_list.item_selected.connect(_on_map_item_activated)
	box.add_child(_map_list)

	var hint := Label.new()
	hint.text = "Click a map to load (crossfade ~1.5 s)."
	hint.modulate = Color(0.65, 0.65, 0.65)
	hint.add_theme_font_size_override("font_size", 11)
	box.add_child(hint)

	var row := HBoxContainer.new()
	box.add_child(row)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(SessionState.request_library_refresh)
	row.add_child(refresh_btn)

	return box


# Live projector controls — the things the GM touches constantly while running
# a scene. Kept in its own bar (not buried in Maps) so it stays visible in
# Live mode. See DESIGN §6.1.
func _build_event_bar_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	box.add_child(_section_header("Projector"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	_hex_toggle = CheckButton.new()
	_hex_toggle.text = "Hex Grid"
	_hex_toggle.toggled.connect(SessionState.set_hex_grid_visible)
	row.add_child(_hex_toggle)

	_blackout_toggle = CheckButton.new()
	_blackout_toggle.text = "Blackout (B)"
	_blackout_toggle.tooltip_text = "Fade the PROJECTOR to black (your tablet still shows the scene). Stage the next beat, then untoggle to reveal."
	_blackout_toggle.toggled.connect(SessionState.set_blackout)
	row.add_child(_blackout_toggle)

	_ping_btn = Button.new()
	_ping_btn.text = "Ping (P)"
	_ping_btn.toggle_mode = true
	_ping_btn.tooltip_text = "Arm ping, then click the preview to pulse that spot on the projector."
	_ping_btn.toggled.connect(SessionState.set_ping_armed)
	row.add_child(_ping_btn)

	return box


func _build_tokens_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	box.add_child(_section_header("Tokens"))

	_token_list = ItemList.new()
	_token_list.custom_minimum_size = Vector2(0, 140)
	_token_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_token_list.item_selected.connect(_on_token_list_selected)
	box.add_child(_token_list)

	var hint := Label.new()
	hint.text = "Drag tokens directly on the preview. Snaps to hex on release if the hex grid is visible."
	hint.modulate = Color(0.65, 0.65, 0.65)
	hint.add_theme_font_size_override("font_size", 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	var row := HBoxContainer.new()
	box.add_child(row)

	var add_btn := Button.new()
	add_btn.text = "Add Token"
	add_btn.pressed.connect(_on_add_token_pressed)
	row.add_child(add_btn)

	var add_mob_btn := Button.new()
	add_mob_btn.text = "Add ×5"
	add_mob_btn.tooltip_text = "Drop 5 scattered tokens (a mob) at once."
	add_mob_btn.pressed.connect(_on_add_mob_pressed)
	row.add_child(add_mob_btn)

	var remove_btn := Button.new()
	remove_btn.text = "Remove Selected"
	remove_btn.pressed.connect(_on_remove_token_pressed)
	row.add_child(remove_btn)

	# --- Inspector for the currently-selected token ----------------------
	var inspector_label := Label.new()
	inspector_label.text = "Selected token"
	inspector_label.modulate = Color(0.75, 0.75, 0.85)
	inspector_label.add_theme_font_size_override("font_size", 12)
	box.add_child(inspector_label)

	var label_row := HBoxContainer.new()
	label_row.add_theme_constant_override("separation", 6)
	box.add_child(label_row)

	var label_caption := Label.new()
	label_caption.text = "Label"
	label_caption.custom_minimum_size = Vector2(48, 0)
	label_row.add_child(label_caption)

	_token_label_edit = LineEdit.new()
	_token_label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_token_label_edit.placeholder_text = "(select a token)"
	_token_label_edit.text_submitted.connect(_on_token_label_submitted)
	_token_label_edit.focus_exited.connect(_on_token_label_focus_exited)
	label_row.add_child(_token_label_edit)

	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 6)
	box.add_child(size_row)

	var size_caption := Label.new()
	size_caption.text = "Size"
	size_caption.custom_minimum_size = Vector2(48, 0)
	size_row.add_child(size_caption)

	_token_size_dropdown = OptionButton.new()
	_token_size_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in SessionState.TOKEN_SIZES:
		_token_size_dropdown.add_item(s.capitalize())
	_token_size_dropdown.item_selected.connect(_on_token_size_selected)
	size_row.add_child(_token_size_dropdown)

	# --- Combat sub-inspector (GURPS) ------------------------------------
	_token_combatant_toggle = CheckBox.new()
	_token_combatant_toggle.text = "Combatant (show HP/FP, include in initiative)"
	_token_combatant_toggle.toggled.connect(_on_token_combatant_toggled)
	box.add_child(_token_combatant_toggle)

	box.add_child(_build_combat_stat_row("HP",
		func(cur): _on_token_combat_field("hp_current", cur),
		func(mx): _on_token_combat_field("hp_max", mx)))
	box.add_child(_build_combat_stat_row("FP",
		func(cur): _on_token_combat_field("fp_current", cur),
		func(mx): _on_token_combat_field("fp_max", mx)))

	var bs_row := HBoxContainer.new()
	bs_row.add_theme_constant_override("separation", 6)
	box.add_child(bs_row)
	var bs_caption := Label.new()
	bs_caption.text = "Basic Speed"
	bs_caption.custom_minimum_size = Vector2(80, 0)
	bs_row.add_child(bs_caption)
	_token_basic_speed_spin = SpinBox.new()
	_token_basic_speed_spin.min_value = 0.0
	_token_basic_speed_spin.max_value = 20.0
	_token_basic_speed_spin.step = 0.25
	_token_basic_speed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_token_basic_speed_spin.value_changed.connect(func(v): _on_token_combat_field("basic_speed", v))
	bs_row.add_child(_token_basic_speed_spin)

	var status_label := Label.new()
	status_label.text = "Statuses"
	status_label.modulate = Color(0.75, 0.75, 0.85)
	status_label.add_theme_font_size_override("font_size", 11)
	box.add_child(status_label)

	# Two-column grid of status checkboxes.
	var status_grid := GridContainer.new()
	status_grid.columns = 2
	status_grid.add_theme_constant_override("h_separation", 8)
	box.add_child(status_grid)
	for status_id in SessionState.TOKEN_STATUSES:
		var meta: Dictionary = SessionState.status_display(status_id)
		var cb := CheckBox.new()
		cb.text = meta.get("display", status_id)
		cb.toggled.connect(_on_token_status_toggled.bind(status_id))
		status_grid.add_child(cb)
		_token_status_checks[status_id] = cb

	return box


func _build_combat_stat_row(caption_text: String,
		on_current: Callable, on_max: Callable) -> Control:
	# A "STAT  [cur] / [max]" row. Wires the new SpinBoxes into the inspector
	# instance vars by matching on the caption text.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var caption := Label.new()
	caption.text = caption_text
	caption.custom_minimum_size = Vector2(80, 0)
	row.add_child(caption)
	var cur := SpinBox.new()
	cur.min_value = -100
	cur.max_value = 1000
	cur.step = 1
	cur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cur.value_changed.connect(on_current)
	row.add_child(cur)
	var slash := Label.new()
	slash.text = "/"
	row.add_child(slash)
	var mx := SpinBox.new()
	mx.min_value = 1
	mx.max_value = 1000
	mx.step = 1
	mx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mx.value_changed.connect(on_max)
	row.add_child(mx)
	match caption_text:
		"HP":
			_token_hp_current_spin = cur
			_token_hp_max_spin = mx
		"FP":
			_token_fp_current_spin = cur
			_token_fp_max_spin = mx
	return row


func _build_combat_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	box.add_child(_section_header("Combat"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	_combat_start_btn = Button.new()
	_combat_start_btn.text = "Start Combat"
	_combat_start_btn.pressed.connect(SessionState.start_combat)
	row.add_child(_combat_start_btn)

	_combat_next_btn = Button.new()
	_combat_next_btn.text = "Next Turn"
	_combat_next_btn.pressed.connect(SessionState.advance_turn)
	row.add_child(_combat_next_btn)

	_combat_end_btn = Button.new()
	_combat_end_btn.text = "End Combat"
	_combat_end_btn.pressed.connect(func(): _confirm("End combat?", SessionState.end_combat))
	row.add_child(_combat_end_btn)

	_combat_round_label = Label.new()
	_combat_round_label.text = "Round —"
	box.add_child(_combat_round_label)

	_combat_active_label = Label.new()
	_combat_active_label.text = ""
	_combat_active_label.modulate = Color(0.85, 0.85, 0.95)
	box.add_child(_combat_active_label)

	var order_caption := Label.new()
	order_caption.text = "Initiative (sorted by Basic Speed desc)"
	order_caption.modulate = Color(0.65, 0.65, 0.65)
	order_caption.add_theme_font_size_override("font_size", 11)
	box.add_child(order_caption)

	_combat_order_box = VBoxContainer.new()
	_combat_order_box.add_theme_constant_override("separation", 2)
	box.add_child(_combat_order_box)

	return box


func _build_atmosphere_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	box.add_child(_section_header("Atmosphere"))

	_mood_dropdown = OptionButton.new()
	_mood_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mood_dropdown.item_selected.connect(_on_mood_selected)
	box.add_child(_mood_dropdown)

	var hint := Label.new()
	hint.text = "Scene mood — multiplicative color tint + particle overlay on the projector."
	hint.modulate = Color(0.65, 0.65, 0.65)
	hint.add_theme_font_size_override("font_size", 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	# --- Lighting: time-of-day + season sliders (v0.9) -------------------
	# Two independent knobs; the projector tint interpolates between the four
	# named stops on each. Multiplies with the mood tint above.
	_tod_label = Label.new()
	_tod_label.add_theme_font_size_override("font_size", 12)
	_tod_label.modulate = Color(0.75, 0.75, 0.85)
	box.add_child(_tod_label)

	_tod_slider = HSlider.new()
	_tod_slider.min_value = 0.0
	_tod_slider.max_value = 1.0
	_tod_slider.step = 0.01
	_tod_slider.value = SessionState.current_time_of_day
	_tod_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tod_slider.value_changed.connect(_on_tod_slider_changed)
	box.add_child(_tod_slider)

	_season_label = Label.new()
	_season_label.add_theme_font_size_override("font_size", 12)
	_season_label.modulate = Color(0.75, 0.75, 0.85)
	box.add_child(_season_label)

	_season_slider = HSlider.new()
	_season_slider.min_value = 0.0
	_season_slider.max_value = 1.0
	_season_slider.step = 0.01
	_season_slider.value = SessionState.current_season
	_season_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_season_slider.value_changed.connect(_on_season_slider_changed)
	box.add_child(_season_slider)

	_refresh_lighting_labels()

	return box


func _on_tod_slider_changed(v: float) -> void:
	SessionState.set_time_of_day(v)
	_refresh_lighting_labels()


func _on_season_slider_changed(v: float) -> void:
	SessionState.set_season(v)
	_refresh_lighting_labels()


func _refresh_lighting_labels() -> void:
	if _tod_label:
		_tod_label.text = "Time of day: %s" % SessionState.nearest_stop(
			SessionState.TOD_STOPS, SessionState.current_time_of_day).capitalize()
	if _season_label:
		_season_label.text = "Season: %s" % SessionState.nearest_stop(
			SessionState.SEASON_STOPS, SessionState.current_season).capitalize()


# --- Handouts (v0.10) ----------------------------------------------------

func _build_handouts_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	box.add_child(_section_header("Handouts"))

	_handout_list = ItemList.new()
	_handout_list.custom_minimum_size = Vector2(0, 90)
	_handout_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_handout_list.item_activated.connect(_on_handout_activated)
	box.add_child(_handout_list)

	var row := HBoxContainer.new()
	box.add_child(row)

	var reveal_btn := Button.new()
	reveal_btn.text = "Reveal"
	reveal_btn.pressed.connect(_on_reveal_handout_pressed)
	row.add_child(reveal_btn)

	var hide_btn := Button.new()
	hide_btn.text = "Hide"
	hide_btn.pressed.connect(SessionState.hide_handout)
	row.add_child(hide_btn)

	var hint := Label.new()
	hint.text = "Full-screen reveal on the projector (sheets, portraits, letters). Drop images in assets/handouts/."
	hint.modulate = Color(0.65, 0.65, 0.65)
	hint.add_theme_font_size_override("font_size", 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	return box


func _refresh_handout_list() -> void:
	if _handout_list == null:
		return
	_handout_list.clear()
	_handout_paths.clear()
	for path in SessionState.handout_library:
		_handout_list.add_item(_basename(path))
		_handout_paths.append(path)


func _on_handout_activated(row: int) -> void:
	if row >= 0 and row < _handout_paths.size():
		SessionState.reveal_handout(_handout_paths[row])


func _on_reveal_handout_pressed() -> void:
	var sel := _handout_list.get_selected_items()
	if not sel.is_empty():
		_on_handout_activated(sel[0])


func _build_audio_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	box.add_child(_section_header("Music"))

	# --- Mission Suite (location + 4-tier switcher) -----------------------
	var suite_label := Label.new()
	suite_label.text = "Mission suite"
	suite_label.modulate = Color(0.75, 0.75, 0.85)
	suite_label.add_theme_font_size_override("font_size", 12)
	box.add_child(suite_label)

	_suite_dropdown = OptionButton.new()
	_suite_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_suite_dropdown.item_selected.connect(_on_suite_selected)
	box.add_child(_suite_dropdown)

	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 4)
	box.add_child(tier_row)

	for tier in SessionState.MUSIC_TIERS:
		var btn := Button.new()
		btn.text = tier.capitalize()
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_tier_pressed.bind(tier))
		tier_row.add_child(btn)
		_tier_buttons[tier] = btn

	var suite_hint := Label.new()
	suite_hint.text = "Pick a suite, then tap a tier. Crossfade ~1.5 s. Disabled tiers have no track in this suite."
	suite_hint.modulate = Color(0.65, 0.65, 0.65)
	suite_hint.add_theme_font_size_override("font_size", 11)
	suite_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(suite_hint)

	# --- Singles (flat one-offs, recursive scan) --------------------------
	var singles_label := Label.new()
	singles_label.text = "Singles"
	singles_label.modulate = Color(0.75, 0.75, 0.85)
	singles_label.add_theme_font_size_override("font_size", 12)
	box.add_child(singles_label)

	_music_list = ItemList.new()
	_music_list.custom_minimum_size = Vector2(0, 120)
	_music_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_music_list)

	var music_row := HBoxContainer.new()
	box.add_child(music_row)

	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.pressed.connect(_on_play_music_pressed)
	music_row.add_child(play_btn)

	var stop_btn := Button.new()
	stop_btn.text = "Stop"
	stop_btn.pressed.connect(SessionState.stop_background_music)
	music_row.add_child(stop_btn)

	box.add_child(_section_header("SFX"))

	_sfx_list = ItemList.new()
	_sfx_list.custom_minimum_size = Vector2(0, 100)
	_sfx_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_sfx_list)

	var sfx_row := HBoxContainer.new()
	box.add_child(sfx_row)

	var trigger_btn := Button.new()
	trigger_btn.text = "Trigger"
	trigger_btn.pressed.connect(_on_trigger_sfx_pressed)
	sfx_row.add_child(trigger_btn)

	var sfx_hint := Label.new()
	sfx_hint.text = "Drop audio files into assets/audio/music or assets/audio/sfx (OGG, MP3, WAV)."
	sfx_hint.modulate = Color(0.65, 0.65, 0.65)
	sfx_hint.add_theme_font_size_override("font_size", 11)
	sfx_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sfx_hint)

	return box


func _section_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color(0.85, 0.85, 0.95)
	return label


# === SessionState wiring =================================================

func _wire_session_signals() -> void:
	SessionState.map_library_changed.connect(func(_paths): _refresh_map_list())
	SessionState.music_library_changed.connect(func(_paths): _refresh_music_list())
	SessionState.sfx_library_changed.connect(func(_paths): _refresh_sfx_list())
	SessionState.music_suites_changed.connect(func(_s): _refresh_suite_dropdown())
	SessionState.current_music_suite_changed.connect(_on_session_suite_changed)
	SessionState.current_music_tier_changed.connect(func(_t): _refresh_tier_highlight())
	SessionState.token_added.connect(_on_session_token_added)
	SessionState.token_removed.connect(_on_session_token_removed)
	SessionState.token_data_changed.connect(_on_session_token_data_changed)
	SessionState.token_selection_changed.connect(_on_session_token_selected)
	SessionState.tokens_reloaded.connect(_on_tokens_reloaded)
	SessionState.hex_grid_visibility_changed.connect(_on_session_hex_visibility_changed)
	SessionState.current_scene_mood_changed.connect(_on_session_mood_changed)
	SessionState.combat_state_changed.connect(func(_a): _refresh_combat_section())
	SessionState.combat_round_changed.connect(func(_r): _refresh_combat_section())
	SessionState.active_combatant_changed.connect(func(_id): _refresh_combat_section())
	SessionState.combat_order_changed.connect(func(_o): _refresh_combat_section())
	SessionState.projector_calibration_changed.connect(func(_o, _z, _r): _refresh_calibration_label())
	SessionState.current_sector_overlay_changed.connect(func(_o): _refresh_facility_section())
	SessionState.facility_state_changed.connect(_refresh_facility_section)
	SessionState.sector_tier_changed.connect(func(_id, _t): _refresh_facility_section())
	SessionState.sector_selection_changed.connect(_on_session_sector_selected)
	SessionState.campaigns_changed.connect(func(_c): _refresh_campaign_dropdown())
	SessionState.map_staged.connect(_on_session_map_staged)
	SessionState.blackout_changed.connect(_on_session_blackout_changed)
	SessionState.ping_armed_changed.connect(_on_session_ping_armed_changed)
	SessionState.handout_library_changed.connect(func(_p): _refresh_handout_list())
	SessionState.sequence_running_changed.connect(_on_session_sequence_running_changed)
	SessionState.sequence_waiting_changed.connect(_on_session_sequence_waiting_changed)
	SessionState.current_briefing_changed.connect(_on_session_briefing_changed)
	_on_session_briefing_changed(SessionState.current_briefing_path)


# --- GM briefing map ------------------------------------------------------

func _on_briefing_toggled(pressed: bool) -> void:
	if _briefing_panel:
		_briefing_panel.visible = pressed


# Enable the toggle only when a briefing exists; auto-close + disable when the
# new scene has none so the GM isn't left staring at a stale map.
func _on_session_briefing_changed(path: String) -> void:
	var has_briefing := path != ""
	if _briefing_toggle:
		_briefing_toggle.disabled = not has_briefing
		if not has_briefing and _briefing_toggle.button_pressed:
			_briefing_toggle.set_pressed_no_signal(false)
	if _briefing_panel and not has_briefing:
		_briefing_panel.visible = false


# --- Campaign -> Mission -> Area -> Map ----------------------------------

func _selected_campaign_id() -> String:
	var i := _campaign_dropdown.selected if _campaign_dropdown else -1
	return _campaign_ids[i] if i >= 0 and i < _campaign_ids.size() else ""


func _selected_mission_id() -> String:
	var i := _mission_dropdown.selected if _mission_dropdown else -1
	return _mission_ids[i] if i >= 0 and i < _mission_ids.size() else ""


func _selected_area_id() -> String:
	var sel := _area_list.get_selected_items() if _area_list else PackedInt32Array()
	if sel.is_empty():
		return ""
	var row: int = sel[0]
	return _area_ids[row] if row >= 0 and row < _area_ids.size() else ""


func _refresh_campaign_dropdown() -> void:
	if _campaign_dropdown == null:
		return
	_campaign_dropdown.clear()
	_campaign_ids.clear()
	for c in SessionState.campaigns:
		if not (c is Dictionary):
			continue
		_campaign_dropdown.add_item(c.get("title", c.get("id", "?")))
		_campaign_ids.append(c.get("id", ""))
	if _campaign_ids.is_empty():
		_mission_blurb.text = "(no campaigns found)"
		return
	# Keep the active campaign selected if we can.
	var idx := _campaign_ids.find(SessionState.current_campaign_id)
	_campaign_dropdown.select(idx if idx >= 0 else 0)
	_on_campaign_selected(_campaign_dropdown.selected)


func _on_campaign_selected(_idx: int) -> void:
	_refresh_mission_dropdown()


func _refresh_mission_dropdown() -> void:
	if _mission_dropdown == null:
		return
	_mission_dropdown.clear()
	_mission_ids.clear()
	var campaign := SessionState.get_campaign(_selected_campaign_id())
	for m in campaign.get("missions", []):
		if not (m is Dictionary):
			continue
		_mission_dropdown.add_item(m.get("title", m.get("id", "?")))
		_mission_ids.append(m.get("id", ""))
	if _mission_ids.is_empty():
		_mission_blurb.text = "(no missions in this campaign)"
		_refresh_area_list()
		return
	_mission_dropdown.select(0)
	_on_mission_selected(0)


func _on_mission_selected(_idx: int) -> void:
	var mission := SessionState.get_mission_in(_selected_campaign_id(), _selected_mission_id())
	_mission_blurb.text = mission.get("blurb", "")
	_refresh_area_list()


func _refresh_area_list() -> void:
	_area_list.clear()
	_area_ids.clear()
	var mission := SessionState.get_mission_in(_selected_campaign_id(), _selected_mission_id())
	for a in mission.get("areas", []):
		if not (a is Dictionary):
			continue
		_area_list.add_item(a.get("title", a.get("id", "?")))
		_area_ids.append(a.get("id", ""))
	# Auto-select the first area so the map list is populated.
	if not _area_ids.is_empty():
		_area_list.select(0)
	_refresh_area_map_list()


func _on_area_selected(_row: int) -> void:
	_refresh_area_map_list()


func _refresh_area_map_list() -> void:
	_area_map_list.clear()
	_area_map_ids.clear()
	var area := SessionState.get_area_in(
		_selected_campaign_id(), _selected_mission_id(), _selected_area_id())
	for mp in area.get("maps", []):
		if not (mp is Dictionary):
			continue
		_area_map_list.add_item(mp.get("title", mp.get("id", "?")))
		_area_map_ids.append(mp.get("id", ""))


func _on_area_map_activated(row: int) -> void:
	if row < 0 or row >= _area_map_ids.size():
		return
	SessionState.stage_map(
		_selected_campaign_id(), _selected_mission_id(),
		_selected_area_id(), _area_map_ids[row])


func _on_session_map_staged(campaign_id: String, mission_id: String, area_id: String, map_id: String) -> void:
	var area := SessionState.get_area_in(campaign_id, mission_id, area_id)
	var mp := SessionState.get_map_in(campaign_id, mission_id, area_id, map_id)
	_staged_label.text = "▶ Staged: %s — %s" % [
		area.get("title", area_id), mp.get("title", map_id)]
	_rebuild_adjacency_buttons(campaign_id, mission_id, area_id, mp)


func _rebuild_adjacency_buttons(campaign_id: String, mission_id: String, area_id: String, mp: Dictionary) -> void:
	if _adjacency_box == null:
		return
	for child in _adjacency_box.get_children():
		child.queue_free()
	var neighbors: Array = mp.get("adjacent", [])
	if neighbors.is_empty():
		return
	var go := Label.new()
	go.text = "Go to:"
	go.modulate = Color(0.7, 0.7, 0.8)
	go.add_theme_font_size_override("font_size", 11)
	_adjacency_box.add_child(go)
	for nid in neighbors:
		var neighbor := SessionState.get_map_in(campaign_id, mission_id, area_id, str(nid))
		if neighbor.is_empty():
			continue
		var btn := Button.new()
		btn.text = neighbor.get("title", str(nid))
		btn.pressed.connect(func(): SessionState.stage_map(campaign_id, mission_id, area_id, str(nid)))
		_adjacency_box.add_child(btn)


# --- Maps ----------------------------------------------------------------

func _refresh_map_list() -> void:
	_map_list.clear()
	for path in SessionState.map_library:
		_map_list.add_item(_basename(path))
		_map_list.set_item_metadata(_map_list.item_count - 1, path)


func _on_map_item_activated(index: int) -> void:
	if index < 0 or index >= _map_list.item_count:
		return
	var path: String = _map_list.get_item_metadata(index)
	SessionState.set_current_map(path)


func _on_session_hex_visibility_changed(is_vis: bool) -> void:
	if _hex_toggle and _hex_toggle.button_pressed != is_vis:
		_hex_toggle.set_pressed_no_signal(is_vis)


func _on_session_blackout_changed(on: bool) -> void:
	if _blackout_toggle and _blackout_toggle.button_pressed != on:
		_blackout_toggle.set_pressed_no_signal(on)


func _on_session_ping_armed_changed(armed: bool) -> void:
	if _ping_btn and _ping_btn.button_pressed != armed:
		_ping_btn.set_pressed_no_signal(armed)


func _on_session_sequence_running_changed(running: bool) -> void:
	if _seq_skip_btn:
		_seq_skip_btn.disabled = not running
	if not running and _seq_continue_btn:
		_seq_continue_btn.disabled = true


func _on_session_sequence_waiting_changed(waiting: bool) -> void:
	if _seq_continue_btn:
		_seq_continue_btn.disabled = not waiting


func _unhandled_key_input(event: InputEvent) -> void:
	# Live hotkeys. Only fire when a text field isn't consuming the key
	# (unhandled input already excludes focused LineEdits that accept it).
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B:
				SessionState.toggle_blackout()
			KEY_P:
				SessionState.set_ping_armed(not SessionState.ping_armed)
			KEY_SPACE:
				# Advance a paused entrance sequence.
				if SessionState.is_sequence_waiting:
					SessionState.advance_sequence()


# --- Tokens --------------------------------------------------------------

func _on_add_token_pressed() -> void:
	_add_one_token()


func _on_add_mob_pressed() -> void:
	# Quick mob: drop several scattered tokens at once.
	for i in 5:
		_add_one_token()


func _add_one_token() -> void:
	var count := SessionState.tokens.size()
	SessionState.add_token("Token %d" % (count + 1), _next_token_color(), _scatter_position(count))


# Palette cycles the 8 base colors, then varies value on each further cycle so
# a large mob stays distinguishable instead of repeating red at the 9th.
func _next_token_color() -> Color:
	var idx := _next_token_palette_index
	_next_token_palette_index += 1
	var base: Color = TOKEN_PALETTE[idx % TOKEN_PALETTE.size()]
	var cycle: int = idx / TOKEN_PALETTE.size()
	if cycle == 0:
		return base
	var v: float = clampf(base.v * (1.0 - 0.18 * (cycle % 3)), 0.35, 1.0)
	return Color.from_hsv(base.h, base.s, v, 1.0)


# Phyllotaxis scatter so newly-added tokens don't stack at the projector centre.
func _scatter_position(index: int) -> Vector2:
	if index <= 0:
		return Vector2.ZERO
	var angle := index * 2.399963  # golden angle (radians)
	var radius := 55.0 * sqrt(float(index))
	return Vector2(cos(angle), sin(angle)) * radius


func _on_remove_token_pressed() -> void:
	var selected := _token_list.get_selected_items()
	if selected.is_empty():
		return
	var id := _token_id_at(selected[0])
	if id == -1:
		return
	_confirm("Remove this token?", func(): SessionState.remove_token(id))


func _on_session_token_added(id: int, data: Dictionary) -> void:
	var row := _token_list.item_count
	var label: String = data.get("label", data.get("name", "Token"))
	var color: Color = data.get("color", Color.WHITE)
	_token_list.add_item(label)
	_token_list.set_item_metadata(row, id)  # id travels with the row — no label matching
	_token_list.set_item_icon_modulate(row, color)
	_refresh_combat_section()


func _on_session_token_removed(id: int) -> void:
	var row := _row_for_token(id)
	if row != -1:
		_token_list.remove_item(row)  # metadata on remaining rows is preserved
	if id == _inspected_token_id:
		_inspected_token_id = -1
		_refresh_token_inspector()
	_refresh_combat_section()


# Map switch: rebuild the token list from the newly-active map's set.
func _on_tokens_reloaded() -> void:
	_token_list.clear()
	for id in SessionState.tokens:
		_on_session_token_added(id, SessionState.tokens[id])
	_inspected_token_id = -1
	_refresh_token_inspector()
	_refresh_combat_section()


# --- Audio ---------------------------------------------------------------

func _refresh_music_list() -> void:
	_music_list.clear()
	for path in SessionState.music_library:
		_music_list.add_item(_basename(path))
		_music_list.set_item_metadata(_music_list.item_count - 1, path)


func _refresh_sfx_list() -> void:
	_sfx_list.clear()
	for path in SessionState.sfx_library:
		_sfx_list.add_item(_basename(path))
		_sfx_list.set_item_metadata(_sfx_list.item_count - 1, path)


func _on_play_music_pressed() -> void:
	var selected := _music_list.get_selected_items()
	if selected.is_empty():
		return
	var path: String = _music_list.get_item_metadata(selected[0])
	SessionState.set_background_music(path)


func _refresh_suite_dropdown() -> void:
	if _suite_dropdown == null:
		return
	_suite_dropdown.clear()
	_suite_ids.clear()
	var ids := SessionState.music_suites.keys()
	ids.sort()
	for id in ids:
		_suite_ids.append(id)
		_suite_dropdown.add_item(_suite_label(id))
	if _suite_ids.is_empty():
		_suite_dropdown.add_item("(no suites — drop folders into music/missions/)")
		_suite_dropdown.disabled = true
	else:
		_suite_dropdown.disabled = false
		var current_index := _suite_ids.find(SessionState.current_music_suite_id)
		if current_index >= 0:
			_suite_dropdown.select(current_index)
	_refresh_tier_highlight()


func _on_suite_selected(index: int) -> void:
	if index < 0 or index >= _suite_ids.size():
		return
	SessionState.set_current_music_suite(_suite_ids[index])


func _on_tier_pressed(tier: String) -> void:
	SessionState.set_current_music_tier(tier)


func _on_session_suite_changed(_id: String) -> void:
	# A suite swap may invalidate tier availability — repaint button states.
	_refresh_tier_highlight()
	var current_index := _suite_ids.find(SessionState.current_music_suite_id)
	if current_index >= 0 and _suite_dropdown:
		_suite_dropdown.select(current_index)


func _refresh_tier_highlight() -> void:
	var suite_id := SessionState.current_music_suite_id
	var suite: Dictionary = SessionState.music_suites.get(suite_id, {})
	var current_tier := SessionState.current_music_tier
	for tier in SessionState.MUSIC_TIERS:
		var btn: Button = _tier_buttons.get(tier)
		if btn == null:
			continue
		var has_track := suite.has(tier)
		btn.disabled = not has_track
		btn.set_pressed_no_signal(has_track and tier == current_tier)


func _suite_label(suite_id: String) -> String:
	# howland_1937 -> Howland 1937
	return suite_id.replace("_", " ").capitalize()


func _on_trigger_sfx_pressed() -> void:
	var selected := _sfx_list.get_selected_items()
	if selected.is_empty():
		return
	var path: String = _sfx_list.get_item_metadata(selected[0])
	SessionState.trigger_ambient_sfx(path)


# --- Token inspector ------------------------------------------------------

func _on_token_list_selected(row: int) -> void:
	# Route through SessionState so list-selection and preview-click share one
	# selection (and the preview can highlight the selected token).
	SessionState.select_token(_token_id_at(row))


func _on_session_token_selected(id: int) -> void:
	_inspected_token_id = id
	var row := _row_for_token(id)
	if row != -1 and not (row in _token_list.get_selected_items()):
		_token_list.select(row)
	elif id == -1:
		_token_list.deselect_all()
	_refresh_token_inspector()


func _on_session_token_data_changed(id: int, data: Dictionary) -> void:
	# Keep the list label in sync with the inspector edit.
	var row := _row_for_token(id)
	if row != -1:
		_token_list.set_item_text(row, data.get("label", data.get("name", "")))
	if id == _inspected_token_id:
		_refresh_token_inspector()
	# Combatant flag, Basic Speed, HP all change the initiative display.
	_refresh_combat_section()


func _refresh_token_inspector() -> void:
	if _token_label_edit == null or _token_size_dropdown == null:
		return
	if _inspected_token_id == -1 or not SessionState.tokens.has(_inspected_token_id):
		_token_label_edit.text = ""
		_token_label_edit.editable = false
		_token_size_dropdown.disabled = true
		_set_combat_inspector_enabled(false)
		return
	var data: Dictionary = SessionState.tokens[_inspected_token_id]
	_token_label_edit.editable = true
	if not _token_label_edit.has_focus():
		_token_label_edit.text = data.get("label", data.get("name", ""))
	_token_size_dropdown.disabled = false
	var size_str: String = data.get("size", "medium")
	var idx := SessionState.TOKEN_SIZES.find(size_str)
	if idx >= 0:
		_token_size_dropdown.select(idx)
	_refresh_combat_inspector(data)


func _set_combat_inspector_enabled(on: bool) -> void:
	if _token_combatant_toggle == null:
		return
	_token_combatant_toggle.disabled = not on
	for spin in [_token_hp_current_spin, _token_hp_max_spin, _token_fp_current_spin, _token_fp_max_spin, _token_basic_speed_spin]:
		if spin:
			spin.editable = on
	for cb in _token_status_checks.values():
		cb.disabled = not on
	if not on:
		_suppress_inspector_signals = true
		_token_combatant_toggle.button_pressed = false
		for cb in _token_status_checks.values():
			cb.button_pressed = false
		_suppress_inspector_signals = false


func _refresh_combat_inspector(data: Dictionary) -> void:
	_set_combat_inspector_enabled(true)
	_suppress_inspector_signals = true
	_token_combatant_toggle.button_pressed = bool(data.get("is_combatant", false))
	_token_hp_current_spin.value = int(data.get("hp_current", SessionState.DEFAULT_HP))
	_token_hp_max_spin.value = int(data.get("hp_max", SessionState.DEFAULT_HP))
	_token_fp_current_spin.value = int(data.get("fp_current", SessionState.DEFAULT_FP))
	_token_fp_max_spin.value = int(data.get("fp_max", SessionState.DEFAULT_FP))
	_token_basic_speed_spin.value = float(data.get("basic_speed", SessionState.DEFAULT_BASIC_SPEED))
	var statuses: Array = data.get("statuses", [])
	for status_id in _token_status_checks:
		_token_status_checks[status_id].button_pressed = statuses.has(status_id)
	_suppress_inspector_signals = false


func _on_token_combatant_toggled(pressed: bool) -> void:
	if _suppress_inspector_signals or _inspected_token_id == -1:
		return
	SessionState.update_token(_inspected_token_id, {"is_combatant": pressed})


func _on_token_combat_field(field: String, value) -> void:
	if _suppress_inspector_signals or _inspected_token_id == -1:
		return
	# SpinBox emits a float; HP/FP fields want int.
	if field in ["hp_current", "hp_max", "fp_current", "fp_max"]:
		value = int(value)
	SessionState.update_token(_inspected_token_id, {field: value})


func _on_token_status_toggled(pressed: bool, status_id: String) -> void:
	if _suppress_inspector_signals or _inspected_token_id == -1:
		return
	SessionState.toggle_token_status(_inspected_token_id, status_id, pressed)


# --- Combat section -------------------------------------------------------

func _refresh_combat_section() -> void:
	if _combat_round_label == null:
		return
	var order: Array = SessionState.get_active_order()
	var active := SessionState.is_combat_active
	_combat_start_btn.disabled = active or order.is_empty()
	_combat_next_btn.disabled = not active
	_combat_end_btn.disabled = not active
	if active:
		_combat_round_label.text = "Round %d" % SessionState.combat_round
		var active_id := SessionState.active_combatant_id
		var active_token: Dictionary = SessionState.tokens.get(active_id, {})
		var name_text: String = active_token.get("label", active_token.get("name", "—"))
		_combat_active_label.text = "Active: %s" % name_text
	else:
		_combat_round_label.text = "Round —"
		if order.is_empty():
			_combat_active_label.text = "(no combatants — flag tokens via the inspector)"
		else:
			_combat_active_label.text = "%d combatant(s) ready" % order.size()
	# Rebuild order list.
	for child in _combat_order_box.get_children():
		child.queue_free()
	for id in order:
		var token: Dictionary = SessionState.tokens.get(id, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var marker := Label.new()
		marker.text = "▶" if (active and id == SessionState.active_combatant_id) else "  "
		marker.custom_minimum_size = Vector2(16, 0)
		row.add_child(marker)
		var swatch := ColorRect.new()
		swatch.color = token.get("color", Color.WHITE)
		swatch.custom_minimum_size = Vector2(12, 12)
		row.add_child(swatch)
		var name_lbl := Label.new()
		name_lbl.text = token.get("label", token.get("name", "Combatant"))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var stat_lbl := Label.new()
		var bs: float = token.get("basic_speed", SessionState.DEFAULT_BASIC_SPEED)
		var hp_cur: int = int(token.get("hp_current", 10))
		var hp_max: int = int(token.get("hp_max", 10))
		stat_lbl.text = "BS %.2f  HP %d/%d" % [bs, hp_cur, hp_max]
		stat_lbl.modulate = Color(0.75, 0.75, 0.80)
		row.add_child(stat_lbl)
		# Reorder + delay controls (only meaningful while combat is running).
		if active:
			var up := Button.new()
			up.text = "▲"
			up.tooltip_text = "Move up (DX tiebreak)"
			up.pressed.connect(SessionState.move_combatant.bind(id, -1))
			row.add_child(up)
			var down := Button.new()
			down.text = "▼"
			down.tooltip_text = "Move down"
			down.pressed.connect(SessionState.move_combatant.bind(id, 1))
			row.add_child(down)
			var delay := Button.new()
			delay.text = "Delay"
			delay.tooltip_text = "Act later this round — drop to the end of the order."
			delay.pressed.connect(SessionState.delay_combatant.bind(id))
			row.add_child(delay)
		_combat_order_box.add_child(row)


func _on_token_label_submitted(text: String) -> void:
	_commit_token_label(text)


func _on_token_label_focus_exited() -> void:
	_commit_token_label(_token_label_edit.text)


func _commit_token_label(text: String) -> void:
	if _inspected_token_id == -1:
		return
	SessionState.update_token(_inspected_token_id, {"label": text})


func _on_token_size_selected(index: int) -> void:
	if _inspected_token_id == -1:
		return
	if index < 0 or index >= SessionState.TOKEN_SIZES.size():
		return
	SessionState.update_token(_inspected_token_id, {"size": SessionState.TOKEN_SIZES[index]})


# --- Atmosphere -----------------------------------------------------------

func _refresh_mood_dropdown() -> void:
	if _mood_dropdown == null:
		return
	_mood_dropdown.clear()
	_mood_ids.clear()
	# Stable order: "none" first, then the rest alphabetically by id.
	var ids: Array = SessionState.SCENE_MOODS.keys()
	ids.erase("none")
	ids.sort()
	ids.insert(0, "none")
	for id in ids:
		_mood_ids.append(id)
		var data: Dictionary = SessionState.SCENE_MOODS[id]
		_mood_dropdown.add_item(data.get("display", id))
	var current_index := _mood_ids.find(SessionState.current_scene_mood)
	if current_index >= 0:
		_mood_dropdown.select(current_index)


func _on_mood_selected(index: int) -> void:
	if index < 0 or index >= _mood_ids.size():
		return
	SessionState.set_current_scene_mood(_mood_ids[index])


func _on_session_mood_changed(mood_id: String) -> void:
	if _mood_dropdown == null:
		return
	var idx := _mood_ids.find(mood_id)
	if idx >= 0:
		_mood_dropdown.select(idx)


# --- Facility (v0.8) -----------------------------------------------------
#
# Sector tier management, TP balance, and owned Research Upgrades for the
# Atlantis base. The Sector list mirrors the overlay attached to the
# current map (empty for maps with no overlay). Click a sector on the
# preview to select it here; click a row to focus the tier dropdown.

func _build_facility_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	box.add_child(_section_header("Facility"))

	# TP balance row.
	var tp_row := HBoxContainer.new()
	tp_row.add_theme_constant_override("separation", 6)
	box.add_child(tp_row)

	var tp_caption := Label.new()
	tp_caption.text = "TP"
	tp_caption.custom_minimum_size = Vector2(36, 0)
	tp_row.add_child(tp_caption)

	_facility_tp_label = Label.new()
	_facility_tp_label.text = "0"
	_facility_tp_label.modulate = Color(0.85, 0.85, 0.95)
	tp_row.add_child(_facility_tp_label)

	var tp_spacer := Control.new()
	tp_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tp_row.add_child(tp_spacer)

	var tp_minus := Button.new()
	tp_minus.text = "−"
	tp_minus.tooltip_text = "Spend TP (by amount in the spin)"
	tp_minus.pressed.connect(func(): SessionState.adjust_tp(-int(_facility_tp_spin.value)))
	tp_row.add_child(tp_minus)

	_facility_tp_spin = SpinBox.new()
	_facility_tp_spin.min_value = 1
	_facility_tp_spin.max_value = 100
	_facility_tp_spin.step = 1
	_facility_tp_spin.value = 1
	_facility_tp_spin.custom_minimum_size = Vector2(72, 0)
	tp_row.add_child(_facility_tp_spin)

	var tp_plus := Button.new()
	tp_plus.text = "+"
	tp_plus.tooltip_text = "Award TP (by amount in the spin)"
	tp_plus.pressed.connect(func(): SessionState.adjust_tp(int(_facility_tp_spin.value)))
	tp_row.add_child(tp_plus)

	# Sectors.
	var sectors_caption := Label.new()
	sectors_caption.text = "Sectors"
	sectors_caption.modulate = Color(0.75, 0.75, 0.85)
	sectors_caption.add_theme_font_size_override("font_size", 12)
	box.add_child(sectors_caption)

	_facility_sector_list = ItemList.new()
	_facility_sector_list.custom_minimum_size = Vector2(0, 160)
	_facility_sector_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_facility_sector_list.item_selected.connect(_on_facility_sector_row_selected)
	box.add_child(_facility_sector_list)

	var sector_hint := Label.new()
	sector_hint.text = "Click a sector on the preview to select it here. Loads only when the current map has a sector overlay."
	sector_hint.modulate = Color(0.65, 0.65, 0.65)
	sector_hint.add_theme_font_size_override("font_size", 11)
	sector_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sector_hint)

	# Selected-sector inspector.
	_facility_selected_label = Label.new()
	_facility_selected_label.text = "(no selection)"
	box.add_child(_facility_selected_label)

	var sector_inspector := HBoxContainer.new()
	sector_inspector.add_theme_constant_override("separation", 6)
	box.add_child(sector_inspector)

	var tier_caption := Label.new()
	tier_caption.text = "Tier"
	tier_caption.custom_minimum_size = Vector2(48, 0)
	sector_inspector.add_child(tier_caption)

	_facility_sector_tier_dropdown = OptionButton.new()
	_facility_sector_tier_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_facility_sector_tier_dropdown.add_item("Tier 1 — Atlantean Baseline", 1)
	_facility_sector_tier_dropdown.add_item("Tier 2 — Industrial-Modern", 2)
	_facility_sector_tier_dropdown.add_item("Tier 3 — ATA Modern", 3)
	_facility_sector_tier_dropdown.item_selected.connect(_on_facility_tier_selected)
	sector_inspector.add_child(_facility_sector_tier_dropdown)

	_facility_sector_upgrading_toggle = CheckBox.new()
	_facility_sector_upgrading_toggle.text = "Upgrading"
	_facility_sector_upgrading_toggle.tooltip_text = "Marks the sector with a pulsing outline on both views."
	_facility_sector_upgrading_toggle.toggled.connect(_on_facility_upgrading_toggled)
	box.add_child(_facility_sector_upgrading_toggle)

	# Research Upgrades.
	var ru_caption := Label.new()
	ru_caption.text = "Research Upgrades owned"
	ru_caption.modulate = Color(0.75, 0.75, 0.85)
	ru_caption.add_theme_font_size_override("font_size", 12)
	box.add_child(ru_caption)

	_facility_ru_list = ItemList.new()
	_facility_ru_list.custom_minimum_size = Vector2(0, 100)
	_facility_ru_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_facility_ru_list)

	var ru_row := HBoxContainer.new()
	ru_row.add_theme_constant_override("separation", 6)
	box.add_child(ru_row)

	_facility_ru_input = LineEdit.new()
	_facility_ru_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_facility_ru_input.placeholder_text = "RU id (e.g. cumaean_cooperation)"
	_facility_ru_input.text_submitted.connect(_on_facility_ru_add_submitted)
	ru_row.add_child(_facility_ru_input)

	var ru_add := Button.new()
	ru_add.text = "Add"
	ru_add.pressed.connect(func(): _on_facility_ru_add_submitted(_facility_ru_input.text))
	ru_row.add_child(ru_add)

	var ru_remove := Button.new()
	ru_remove.text = "Remove Selected"
	ru_remove.pressed.connect(_on_facility_ru_remove_pressed)
	ru_row.add_child(ru_remove)

	return box


func _refresh_facility_section() -> void:
	if _facility_tp_label == null:
		return
	_facility_tp_label.text = "%d" % int(SessionState.facility_state.get("tp_balance", 0))
	_refresh_facility_sector_list()
	_refresh_facility_sector_inspector()
	_refresh_facility_ru_list()


func _refresh_facility_sector_list() -> void:
	_facility_sector_list.clear()
	_facility_sector_ids.clear()
	var overlay: Dictionary = SessionState.current_sector_overlay
	var sectors: Array = overlay.get("sectors", [])
	for sector in sectors:
		if not (sector is Dictionary):
			continue
		var id: String = sector.get("id", "")
		if id == "":
			continue
		var name_text: String = sector.get("name", id)
		var tier: int = SessionState.get_sector_tier(id)
		var suffix: String = "  ⚙" if SessionState.is_sector_upgrading(id) else ""
		_facility_sector_list.add_item("[%s] %s — T%d%s" % [id, name_text, tier, suffix])
		_facility_sector_ids.append(id)
	# Reflect current selection in the list.
	var sel_id: String = SessionState.current_selected_sector_id
	if sel_id != "":
		var idx := _facility_sector_ids.find(sel_id)
		if idx >= 0:
			_facility_sector_list.select(idx)


func _refresh_facility_sector_inspector() -> void:
	var id: String = SessionState.current_selected_sector_id
	var has_selection: bool = id != ""
	_facility_sector_tier_dropdown.disabled = not has_selection
	_facility_sector_upgrading_toggle.disabled = not has_selection
	if not has_selection:
		_facility_selected_label.text = "(no selection)"
		return
	# Find the sector's display name from the active overlay (if any).
	var overlay: Dictionary = SessionState.current_sector_overlay
	var name_text: String = id
	for sector in overlay.get("sectors", []):
		if sector is Dictionary and sector.get("id", "") == id:
			name_text = sector.get("name", id)
			break
	_facility_selected_label.text = "Selected: [%s] %s" % [id, name_text]
	var tier: int = SessionState.get_sector_tier(id)
	_facility_sector_tier_dropdown.select(clamp(tier - 1, 0, 2))
	_facility_sector_upgrading_toggle.set_pressed_no_signal(SessionState.is_sector_upgrading(id))


func _refresh_facility_ru_list() -> void:
	_facility_ru_list.clear()
	var owned: Array = SessionState.facility_state.get("ru_owned", [])
	for ru in owned:
		_facility_ru_list.add_item(str(ru))


func _on_facility_sector_row_selected(row: int) -> void:
	if row < 0 or row >= _facility_sector_ids.size():
		return
	SessionState.select_sector(_facility_sector_ids[row])


func _on_facility_tier_selected(index: int) -> void:
	var id: String = SessionState.current_selected_sector_id
	if id == "":
		return
	SessionState.set_sector_tier(id, index + 1)


func _on_facility_upgrading_toggled(pressed: bool) -> void:
	var id: String = SessionState.current_selected_sector_id
	if id == "":
		return
	SessionState.set_sector_upgrading(id, pressed)


func _on_facility_ru_add_submitted(text: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed == "":
		return
	SessionState.add_ru(trimmed)
	_facility_ru_input.text = ""


func _on_facility_ru_remove_pressed() -> void:
	var selected := _facility_ru_list.get_selected_items()
	if selected.is_empty():
		return
	var ru_text: String = _facility_ru_list.get_item_text(selected[0])
	SessionState.remove_ru(ru_text)


func _on_session_sector_selected(_sector_id: String) -> void:
	_refresh_facility_sector_inspector()
	# Re-select the row in the list to mirror the selection.
	var sel_id: String = SessionState.current_selected_sector_id
	if sel_id == "":
		_facility_sector_list.deselect_all()
		return
	var idx := _facility_sector_ids.find(sel_id)
	if idx >= 0:
		_facility_sector_list.select(idx)


# === Inner classes =======================================================

class BriefingPanel extends Control:
	# GM-only briefing/reference map overlay for the left pane. Shows the current
	# scene's briefing image (parchment map, objectives, routes) letterboxed on a
	# dark backdrop, with a caption reminding the GM it's not projected. Tracks
	# SessionState.current_briefing_path; visibility is driven by the toolbar
	# toggle in the outer window. NEVER touches the projector.
	var _tex_rect: TextureRect
	var _empty_label: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP  # eat clicks so they don't reach the preview under it

		var bg := ColorRect.new()
		bg.color = Color(0.07, 0.06, 0.05)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

		_tex_rect = TextureRect.new()
		_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tex_rect)

		# Caption pill — reminds the GM this is a private reference view.
		var caption := Label.new()
		caption.text = "  GM BRIEFING · not projected  "
		caption.add_theme_font_size_override("font_size", 12)
		caption.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75))
		caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		caption.add_theme_constant_override("outline_size", 4)
		caption.position = Vector2(8, 6)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(caption)

		_empty_label = Label.new()
		_empty_label.text = "No briefing map for this scene."
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_empty_label.modulate = Color(0.6, 0.6, 0.6)
		_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_empty_label)

		SessionState.current_briefing_changed.connect(_on_briefing_changed)
		_on_briefing_changed(SessionState.current_briefing_path)

	func _on_briefing_changed(path: String) -> void:
		if path != "" and ResourceLoader.exists(path):
			_tex_rect.texture = load(path)
			_empty_label.visible = false
		else:
			_tex_rect.texture = null
			_empty_label.visible = true


# === Utils ===============================================================

func _basename(path: String) -> String:
	var slash := path.rfind("/")
	if slash == -1:
		return path
	return path.substr(slash + 1)


# Pop a yes/no confirmation; run on_yes only if confirmed. Guards destructive
# actions (remove token, end combat) against a mid-session misclick.
func _confirm(text: String, on_yes: Callable) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = text
	add_child(dlg)
	dlg.canceled.connect(dlg.queue_free)
	dlg.c