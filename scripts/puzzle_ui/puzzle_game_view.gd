class_name PuzzleGameView
extends Control

## Phase R-F: minimal Score Attack view. PuzzleSession is the only game-state SoT.
## Draws board_snapshot(); routes touch/mouse through GridInputMapper → session APIs.

const DEV_SEED := 42
const DEV_WIDTH := 6
const DEV_HEIGHT := 6
const DURATIONS_MS: Array[int] = [45000, 60000, 90000]

var _session: PuzzleSession = null
var _mapper := GridInputMapper.new()
var _geometry: BoardGeometry = null
var _elapsed_accumulator_ms: float = 0.0
var _app_active: bool = true
var _duration_ms: int = 60000
var _last_move_note: String = ""
var _hud: VBoxContainer = null
var _score_label: Label = null
var _timer_label: Label = null
var _state_label: Label = null
var _note_label: Label = null
var _duration_row: HBoxContainer = null
var _board_area: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_build_hud()
	_start_session(_duration_ms)
	set_process(true)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_app_active = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_app_active = true
		_elapsed_accumulator_ms = 0.0
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()


func _build_hud() -> void:
	_hud = VBoxContainer.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_theme_constant_override("separation", 8)
	add_child(_hud)

	var title := Label.new()
	title.text = "Score Attack (DEV)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	_hud.add_child(title)

	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_score_label)

	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_timer_label)

	_state_label = Label.new()
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_state_label)

	_note_label = Label.new()
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_child(_note_label)

	_duration_row = HBoxContainer.new()
	_duration_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_duration_row.add_theme_constant_override("separation", 8)
	_hud.add_child(_duration_row)
	for ms in DURATIONS_MS:
		var btn := Button.new()
		btn.text = "%ds" % int(ms / 1000)
		btn.pressed.connect(_on_duration_pressed.bind(ms))
		_duration_row.add_child(btn)

	var restart := Button.new()
	restart.text = "Restart"
	restart.pressed.connect(_on_restart_pressed)
	_hud.add_child(restart)

	var seed_label := Label.new()
	seed_label.text = "DEV seed=%d · 6×6 · 5 OrbTypes" % DEV_SEED
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_label.add_theme_font_size_override("font_size", 12)
	_hud.add_child(seed_label)

	_board_area = Control.new()
	_board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_board_area)


func _on_duration_pressed(ms: int) -> void:
	_duration_ms = ms
	_start_session(ms)


func _on_restart_pressed() -> void:
	_start_session(_duration_ms)


func _start_session(duration_ms: int) -> void:
	_session = PuzzleSession.create_score_attack(DEV_WIDTH, DEV_HEIGHT, DEV_SEED, duration_ms)
	_mapper.clear()
	_elapsed_accumulator_ms = 0.0
	_last_move_note = ""
	_refresh_hud()
	queue_redraw()


func _process(delta: float) -> void:
	if _session == null or not _session.is_valid():
		return
	if not _app_active:
		return
	var st := _session.state()
	if st != PuzzleSession.State.IDLE and st != PuzzleSession.State.ROUTE_DRAG:
		_refresh_hud()
		return
	_elapsed_accumulator_ms += delta * 1000.0
	var whole_ms := int(floor(_elapsed_accumulator_ms))
	if whole_ms > 0:
		_session.advance_time(whole_ms)
		_elapsed_accumulator_ms -= float(whole_ms)
		_refresh_hud()
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _session == null or not _session.is_valid():
		return
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
		accept_event()
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event as InputEventScreenDrag)
		accept_event()
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		accept_event()
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
		accept_event()


func _handle_touch(ev: InputEventScreenTouch) -> void:
	if ev.pressed:
		if _mapper.source == GridInputMapper.PointerSource.MOUSE:
			return
		if _mapper.source == GridInputMapper.PointerSource.TOUCH and not _mapper.accepts_touch(ev.index):
			return
		if _mapper.source == GridInputMapper.PointerSource.NONE:
			if not _try_begin_at(ev.position):
				return
			_mapper.begin_touch(ev.index)
		return
	# release
	if not _mapper.accepts_touch(ev.index):
		return
	_finish_pointer()


func _handle_touch_drag(ev: InputEventScreenDrag) -> void:
	if not _mapper.accepts_touch(ev.index):
		return
	_pointer_move(ev.position)


func _handle_mouse_button(ev: InputEventMouseButton) -> void:
	if ev.button_index != MOUSE_BUTTON_LEFT:
		return
	# Ignore mouse while a touch owns the pointer (synthetic mouse after touch).
	if _mapper.source == GridInputMapper.PointerSource.TOUCH:
		return
	if ev.pressed:
		if _mapper.source != GridInputMapper.PointerSource.NONE:
			return
		if not _try_begin_at(ev.position):
			return
		_mapper.begin_mouse()
	else:
		if not _mapper.accepts_mouse():
			return
		_finish_pointer()


func _handle_mouse_motion(ev: InputEventMouseMotion) -> void:
	if _mapper.source == GridInputMapper.PointerSource.TOUCH:
		return
	if not _mapper.accepts_mouse():
		return
	if (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		return
	_pointer_move(ev.position)


func _try_begin_at(local_pos: Vector2) -> bool:
	_update_geometry()
	if _geometry == null:
		return false
	var st := _session.state()
	if st != PuzzleSession.State.IDLE:
		return false
	var cell := _geometry.pixel_to_cell(local_pos)
	if cell.x < 0:
		return false
	if not _session.begin_drag(cell):
		return false
	_refresh_hud()
	queue_redraw()
	return true


func _pointer_move(local_pos: Vector2) -> void:
	_update_geometry()
	if _geometry == null:
		return
	if not _geometry.contains_pixel(local_pos):
		# Outside: keep route, no new steps, no clamp swaps.
		return
	var target := _geometry.pixel_to_cell(local_pos)
	if target.x < 0:
		return
	var current := _session.active_drag_current_cell()
	if current.x < 0:
		return
	if target == current:
		return
	var steps := GridInputMapper.interpolate_orthogonal(current, target)
	for step_cell in steps:
		var result := _session.step_drag(step_cell)
		if result == DragRoute.StepResult.REJECTED:
			break
	_refresh_hud()
	queue_redraw()


func _finish_pointer() -> void:
	_mapper.clear()
	if _session.state() != PuzzleSession.State.ROUTE_DRAG:
		_refresh_hud()
		queue_redraw()
		return
	var move := _session.release_drag()
	if move.is_success() and move.move_score() > 0:
		_last_move_note = "+%d  Cascade %d" % [move.move_score(), maxi(move.cascade_step_count(), 1)]
	elif move.is_success():
		_last_move_note = "No match"
	elif move.is_error():
		_last_move_note = "ERROR"
	else:
		_last_move_note = ""
	_refresh_hud()
	queue_redraw()


func _update_geometry() -> void:
	if _board_area == null or _session == null:
		_geometry = null
		return
	var area := _board_area.get_rect()
	# Board area is in this Control's local space via child's position.
	var top_left := _board_area.position
	var avail := _board_area.size
	if avail.x < 8.0 or avail.y < 8.0:
		# Fallback: use lower portion of this control.
		top_left = Vector2(16.0, size.y * 0.35)
		avail = Vector2(size.x - 32.0, size.y * 0.55)
	var side := minf(avail.x, avail.y)
	var cell := side / float(DEV_WIDTH)
	var board_pixel := cell * float(DEV_WIDTH)
	var origin := top_left + Vector2((avail.x - board_pixel) * 0.5, (avail.y - board_pixel) * 0.5)
	_geometry = BoardGeometry.create(origin, cell, DEV_WIDTH, DEV_HEIGHT)


func _refresh_hud() -> void:
	if _session == null:
		return
	_score_label.text = "Score: %d" % _session.score()
	var sec := float(_session.remaining_ms()) / 1000.0
	_timer_label.text = "Time: %.1fs" % sec
	_state_label.text = "State: %s" % _state_name(_session.state())
	var note := _last_move_note
	if _session.state() == PuzzleSession.State.SESSION_OVER:
		note = "SESSION OVER — Score %d — Restart / pick 45·60·90" % _session.score()
	elif _session.state() == PuzzleSession.State.ERROR:
		note = "ERROR — input blocked"
	_note_label.text = note


func _state_name(st: PuzzleSession.State) -> String:
	match st:
		PuzzleSession.State.INVALID:
			return "INVALID"
		PuzzleSession.State.IDLE:
			return "IDLE"
		PuzzleSession.State.ROUTE_DRAG:
			return "ROUTE_DRAG"
		PuzzleSession.State.RESOLVING:
			return "RESOLVING"
		PuzzleSession.State.SESSION_OVER:
			return "SESSION_OVER"
		PuzzleSession.State.ERROR:
			return "ERROR"
		_:
			return "?"


func _draw() -> void:
	_update_geometry()
	if _geometry == null or _session == null:
		return
	var snap: Array = _session.board_snapshot()
	var head := _session.active_drag_current_cell()
	for y in range(DEV_HEIGHT):
		if y >= snap.size():
			continue
		var row: Array = snap[y]
		for x in range(DEV_WIDTH):
			var cell := Vector2i(x, y)
			var rect := _geometry.cell_rect(cell)
			var orb_id: int = row[x] if x < row.size() else -1
			draw_rect(rect, Color(0.12, 0.14, 0.18), true)
			draw_rect(rect, Color(0.35, 0.38, 0.45), false, 2.0)
			if orb_id >= 0:
				var fill := _orb_color(orb_id)
				var inset := rect.grow(-rect.size.x * 0.12)
				draw_rect(inset, fill, true)
				var label := _orb_symbol(orb_id)
				var font := ThemeDB.fallback_font
				var font_size := int(maxi(12, int(rect.size.x * 0.35)))
				var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				var text_pos := inset.position + (inset.size - text_size) * 0.5 + Vector2(0, text_size.y * 0.8)
				draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.05, 0.05, 0.08))
			if head == cell and _session.has_active_drag():
				draw_rect(rect.grow(-3.0), Color(1.0, 1.0, 1.0, 0.85), false, 3.0)


func _orb_color(orb_id: int) -> Color:
	match orb_id:
		0:
			return Color(0.92, 0.32, 0.28) # red
		1:
			return Color(0.28, 0.62, 0.95) # blue
		2:
			return Color(0.30, 0.78, 0.42) # green
		3:
			return Color(0.95, 0.78, 0.22) # yellow
		4:
			return Color(0.72, 0.42, 0.88) # violet
		_:
			return Color(0.5, 0.5, 0.5)


func _orb_symbol(orb_id: int) -> String:
	match orb_id:
		0:
			return "1"
		1:
			return "2"
		2:
			return "3"
		3:
			return "4"
		4:
			return "5"
		_:
			return "?"
