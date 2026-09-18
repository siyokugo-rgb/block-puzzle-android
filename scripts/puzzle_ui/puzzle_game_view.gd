class_name PuzzleGameView
extends Control

## Phase R-F/R-G: minimal Score Attack view. PuzzleSession is the only game-state SoT.
## Pre-session READY is UI-only (no PuzzleSession.State.READY). Session starts on START/Restart.
## Pre-game (OPENING + COUNTDOWN) freezes Session Timer; gameplay presentation keeps it live.
## Normal START/Restart pick a new Session seed; PuzzleSession remains deterministic for a given seed.

## Fixed seed for tests / Gate comparison / bug reproduction (not normal play).
const DEV_SEED := 42
const DEV_WIDTH := 6
const DEV_HEIGHT := 6
const DURATIONS_MS: Array[int] = [45000, 60000, 90000]
const DEFAULT_DURATION_MS := 60000
## Gameplay render upper target (matches project.godot application/run/max_fps).
const TARGET_FPS := 60
## DEV-only FPS overlay (not production UI).
const SHOW_DEV_FPS := true
const FPS_SAMPLE_INTERVAL_MS := 500.0
## Pre-game 3·2·1 (delta_ms-based; not frame-count).
const PRESTART_COUNTDOWN_MS := 3000.0
const COUNTDOWN_DIGIT_MS := 1000.0
## Non-blocking GO overlay after countdown; Session/input already live.
const GO_OVERLAY_MS := 400.0
## Normal-play Session seed range (positive int; QA-friendly).
const SESSION_SEED_MIN := 1
const SESSION_SEED_MAX := 2147483647
const MAX_SEED_RETRY := 4

enum StartPhase {
	READY,
	OPENING,
	COUNTDOWN,
	RUNNING,
}

var _session: PuzzleSession = null
var _mapper := GridInputMapper.new()
var _geometry: BoardGeometry = null
var _elapsed_accumulator_ms: float = 0.0
var _app_active: bool = true
var _duration_ms: int = DEFAULT_DURATION_MS
var _obstacle_mode: int = PuzzleSession.ObstacleMode.ROCK
var _last_move_note: String = ""
var _skip_timer_frames: int = 2
## After startup/focus, drop one abnormal first-frame spike (>1s). Normal play has no cap.
var _drop_transition_spike: bool = true
var _start_phase: int = StartPhase.READY
var _countdown_elapsed_ms: float = 0.0
var _go_overlay_remaining_ms: float = 0.0
## Normal-play seed source (independent of domain Orb/Obstacle RNG).
var _session_seed_rng := RandomNumberGenerator.new()
var _current_session_seed: int = 0
var _hud: VBoxContainer = null
var _score_label: Label = null
var _session_timer_label: Label = null
var _move_timer_label: Label = null
var _rock_label: Label = null
var _state_label: Label = null
var _note_label: Label = null
var _seed_label: Label = null
var _duration_row: HBoxContainer = null
var _duration_buttons: Dictionary = {} # ms -> Button
var _obstacle_row: HBoxContainer = null
var _obstacle_buttons: Dictionary = {} # mode -> Button
var _start_button: Button = null
var _restart_button: Button = null
var _board_area: Control = null
var _countdown_overlay: Label = null
var _presenter := ResolutionPresenter.new()
var _fps_label: Label = null
var _fps_sample_accum_ms: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	# Reinforce project.godot run/max_fps (Godot 4.7 Engine.max_fps).
	Engine.max_fps = TARGET_FPS
	_session_seed_rng.randomize()
	_build_hud()
	_enter_ready()
	set_process(true)
	queue_redraw()


func selected_obstacle_mode() -> int:
	return _obstacle_mode


func select_obstacle_mode(mode: int) -> void:
	if mode != PuzzleSession.ObstacleMode.OFF and mode != PuzzleSession.ObstacleMode.ROCK:
		return
	_obstacle_mode = mode
	_refresh_obstacle_buttons()
	_refresh_hud()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_app_active = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_app_active = true
		_elapsed_accumulator_ms = 0.0
		_skip_timer_frames = 2
		_drop_transition_spike = true
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()


# --- Testable pre-session / launch helpers (no domain READY state) ---


func is_awaiting_start() -> bool:
	return _session == null


func selected_duration_ms() -> int:
	return _duration_ms


func select_duration(ms: int) -> void:
	if not DURATIONS_MS.has(ms):
		return
	_duration_ms = ms
	_refresh_duration_buttons()
	_refresh_hud()


func start_selected_session() -> void:
	_start_session(_duration_ms, _next_session_seed())


func restart_selected_session() -> void:
	_start_session(_duration_ms, _next_session_seed())


## Explicit seed for tests / Gate 2 / bug reproduction. Not used by normal START/Restart.
func start_session_with_seed(seed: int, duration_ms: int = -1) -> void:
	var dur := _duration_ms if duration_ms < 0 else duration_ms
	_start_session(dur, seed)


func current_session_seed() -> int:
	return _current_session_seed


## Next normal-play Session seed; never equals previous `_current_session_seed`.
func _next_session_seed() -> int:
	var candidate := _session_seed_rng.randi_range(SESSION_SEED_MIN, SESSION_SEED_MAX)
	var tries := 0
	while candidate == _current_session_seed and tries < MAX_SEED_RETRY:
		candidate = _session_seed_rng.randi_range(SESSION_SEED_MIN, SESSION_SEED_MAX)
		tries += 1
	if candidate == _current_session_seed:
		# Bounded fallback: always a different in-range value (not crypto).
		if _current_session_seed >= SESSION_SEED_MAX:
			candidate = SESSION_SEED_MIN
		else:
			candidate = _current_session_seed + 1
	return candidate


func has_playable_session() -> bool:
	return _session != null and _session.is_valid()


func start_phase() -> int:
	return _start_phase


func is_pre_game() -> bool:
	return _start_phase == StartPhase.OPENING or _start_phase == StartPhase.COUNTDOWN


func is_gameplay_running() -> bool:
	return _start_phase == StartPhase.RUNNING


## Countdown digit 3/2/1 while COUNTDOWN; 0 otherwise.
func countdown_digit() -> int:
	if _start_phase != StartPhase.COUNTDOWN:
		return 0
	var idx := int(floor(_countdown_elapsed_ms / COUNTDOWN_DIGIT_MS))
	if idx <= 0:
		return 3
	if idx == 1:
		return 2
	return 1


func is_go_overlay_visible() -> bool:
	return _start_phase == StartPhase.RUNNING and _go_overlay_remaining_ms > 0.0


## Test helper: skip opening/countdown into RUNNING without consuming Session time.
func force_enter_running_for_tests() -> void:
	if _presenter != null:
		_presenter.busy = false
		_presenter.phase = ResolutionPresenter.Phase.IDLE
	_begin_running()


func board_input_enabled() -> bool:
	# Pre-game (OPENING / COUNTDOWN) never accepts board input.
	if _start_phase != StartPhase.RUNNING:
		return false
	# Gameplay presentation still blocks input (visual ≠ domain board).
	if _presenter != null and _presenter.is_busy():
		return false
	return has_playable_session() and (
		_session.state() == PuzzleSession.State.IDLE
		or _session.state() == PuzzleSession.State.ROUTE_DRAG
	)


func is_presentation_busy() -> bool:
	return _presenter != null and _presenter.is_busy()


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

	_session_timer_label = Label.new()
	_session_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_session_timer_label)

	_move_timer_label = Label.new()
	_move_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_move_timer_label)

	_rock_label = Label.new()
	_rock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_rock_label)

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
	_duration_buttons.clear()
	for ms in DURATIONS_MS:
		var btn := Button.new()
		btn.text = "%ds" % int(ms / 1000)
		btn.pressed.connect(_on_duration_pressed.bind(ms))
		_duration_row.add_child(btn)
		_duration_buttons[ms] = btn

	_obstacle_row = HBoxContainer.new()
	_obstacle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_obstacle_row.add_theme_constant_override("separation", 8)
	_hud.add_child(_obstacle_row)
	_obstacle_buttons.clear()
	var off_btn := Button.new()
	off_btn.text = "Obstacle OFF"
	off_btn.pressed.connect(_on_obstacle_pressed.bind(PuzzleSession.ObstacleMode.OFF))
	_obstacle_row.add_child(off_btn)
	_obstacle_buttons[PuzzleSession.ObstacleMode.OFF] = off_btn
	var rock_btn := Button.new()
	rock_btn.text = "ROCK"
	rock_btn.pressed.connect(_on_obstacle_pressed.bind(PuzzleSession.ObstacleMode.ROCK))
	_obstacle_row.add_child(rock_btn)
	_obstacle_buttons[PuzzleSession.ObstacleMode.ROCK] = rock_btn

	_start_button = Button.new()
	_start_button.text = "START"
	_start_button.custom_minimum_size = Vector2(0, 48)
	_start_button.pressed.connect(_on_start_pressed)
	_hud.add_child(_start_button)

	_restart_button = Button.new()
	_restart_button.text = "Restart"
	_restart_button.pressed.connect(_on_restart_pressed)
	_hud.add_child(_restart_button)

	_seed_label = Label.new()
	_seed_label.name = "DevSeedLabel"
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_label.add_theme_font_size_override("font_size", 12)
	_hud.add_child(_seed_label)
	_refresh_seed_label()

	_board_area = Control.new()
	_board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_board_area)

	# Reused overlay (never recreated per frame) for 3·2·1 / GO.
	_countdown_overlay = Label.new()
	_countdown_overlay.name = "CountdownOverlay"
	_countdown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_overlay.add_theme_font_size_override("font_size", 96)
	_countdown_overlay.add_theme_color_override("font_color", Color(0.98, 0.98, 0.95, 0.95))
	_countdown_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_countdown_overlay.visible = false
	_countdown_overlay.text = ""
	_board_area.add_child(_countdown_overlay)

	if SHOW_DEV_FPS:
		_fps_label = Label.new()
		_fps_label.name = "DevFpsLabel"
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_fps_label.add_theme_font_size_override("font_size", 12)
		_fps_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75, 0.9))
		_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_fps_label.offset_left = -140.0
		_fps_label.offset_top = 8.0
		_fps_label.offset_right = -8.0
		_fps_label.offset_bottom = 48.0
		_fps_label.text = "FPS: --\nFrame: -- ms"
		add_child(_fps_label)


func _enter_ready() -> void:
	_session = null
	_mapper.clear()
	_elapsed_accumulator_ms = 0.0
	_skip_timer_frames = 2
	_drop_transition_spike = true
	_last_move_note = ""
	_geometry = null
	_start_phase = StartPhase.READY
	_countdown_elapsed_ms = 0.0
	_go_overlay_remaining_ms = 0.0
	if _presenter != null:
		_presenter.busy = false
		_presenter.phase = ResolutionPresenter.Phase.IDLE
	_update_countdown_overlay()
	_refresh_duration_buttons()
	_refresh_obstacle_buttons()
	_refresh_action_buttons()
	_refresh_seed_label()
	_refresh_hud()
	queue_redraw()


func _on_duration_pressed(ms: int) -> void:
	# Selection only — never auto-starts a session.
	select_duration(ms)


func _on_obstacle_pressed(mode: int) -> void:
	# Selection only — never auto-starts a session.
	select_obstacle_mode(mode)


func _on_start_pressed() -> void:
	# Button consumes the press; clear mapper so START cannot become a board drag.
	_mapper.clear()
	start_selected_session()


func _on_restart_pressed() -> void:
	_mapper.clear()
	restart_selected_session()


func _start_session(duration_ms: int, session_seed: int) -> void:
	_duration_ms = duration_ms
	_current_session_seed = session_seed
	_session = PuzzleSession.create_score_attack(
		DEV_WIDTH,
		DEV_HEIGHT,
		session_seed,
		duration_ms,
		CascadeResolver.MAX_CASCADE_STEPS,
		_obstacle_mode
	)
	_mapper.clear()
	_elapsed_accumulator_ms = 0.0
	_skip_timer_frames = 0
	_drop_transition_spike = false
	_last_move_note = ""
	_countdown_elapsed_ms = 0.0
	_go_overlay_remaining_ms = 0.0
	if _presenter != null:
		_presenter.busy = false
		_presenter.phase = ResolutionPresenter.Phase.IDLE
	_refresh_duration_buttons()
	_refresh_obstacle_buttons()
	_refresh_action_buttons()
	_refresh_seed_label()
	# ROCK: opening drop first (pre-game). OFF: skip straight to countdown.
	if _try_begin_opening_rock_presentation():
		_start_phase = StartPhase.OPENING
	else:
		_begin_countdown()
	_refresh_hud()
	queue_redraw()


## Presentation-only: initial R2 rocks drop from above into seeded top-row columns.
## Pre-game: Session Timer frozen while opening plays.
func _try_begin_opening_rock_presentation() -> bool:
	if _session == null or not _session.is_valid():
		return false
	if _session.obstacle_mode() != PuzzleSession.ObstacleMode.ROCK:
		return false
	var positions := _session.initial_rock_positions()
	if positions.is_empty():
		return false
	var before_orbs: Array = _session.board_snapshot()
	var before_obs: Array = _session.obstacle_snapshot()
	var before_hp: Array = _session.obstacle_hp_snapshot()
	var spawns: Array = []
	for pos in positions:
		before_obs[pos.y][pos.x] = ObstacleType.Id.NONE
		before_hp[pos.y][pos.x] = 0
		spawns.append(RockSpawnTrace.create(pos, PuzzleCell.ROCK_INITIAL_HP))
	var move := SessionMoveResult.resolved(
		0,
		[],
		0,
		_session.score(),
		false,
		before_orbs,
		before_obs,
		before_hp,
		[],
		spawns
	)
	_presenter.begin(move)
	return _presenter.is_busy()


func _begin_countdown() -> void:
	_start_phase = StartPhase.COUNTDOWN
	_countdown_elapsed_ms = 0.0
	_go_overlay_remaining_ms = 0.0
	_mapper.clear()
	_update_countdown_overlay()
	_refresh_hud()
	queue_redraw()


func _begin_running() -> void:
	_start_phase = StartPhase.RUNNING
	_countdown_elapsed_ms = 0.0
	_go_overlay_remaining_ms = GO_OVERLAY_MS
	# Clear any pre-game press so it cannot become the first drag.
	_mapper.clear()
	_elapsed_accumulator_ms = 0.0
	_skip_timer_frames = 0
	_drop_transition_spike = false
	_update_countdown_overlay()
	_refresh_hud()
	queue_redraw()


func _update_countdown_overlay() -> void:
	if _countdown_overlay == null:
		return
	var next := ""
	var show := false
	if _start_phase == StartPhase.COUNTDOWN:
		show = true
		next = str(countdown_digit())
	elif is_go_overlay_visible():
		show = true
		next = "GO!"
	_countdown_overlay.visible = show
	if show and _countdown_overlay.text != next:
		_countdown_overlay.text = next
	elif not show and _countdown_overlay.text != "":
		_countdown_overlay.text = ""


func _refresh_duration_buttons() -> void:
	for ms in _duration_buttons.keys():
		var btn: Button = _duration_buttons[ms]
		var selected: bool = int(ms) == _duration_ms
		btn.text = ("%ds ★" if selected else "%ds") % int(int(ms) / 1000)
		btn.disabled = false


func _refresh_obstacle_buttons() -> void:
	for mode in _obstacle_buttons.keys():
		var btn: Button = _obstacle_buttons[mode]
		var selected: bool = int(mode) == _obstacle_mode
		# OFF is DEV/QA/Gate baseline — not the product-standard mode.
		if int(mode) == PuzzleSession.ObstacleMode.OFF:
			btn.text = "Obstacle OFF (DEV) ★" if selected else "Obstacle OFF (DEV)"
		else:
			btn.text = "ROCK ★" if selected else "ROCK"
		btn.disabled = false


func _refresh_seed_label() -> void:
	if _seed_label == null:
		return
	var move_s := float(PuzzleSession.MOVE_DURATION_MS) / 1000.0
	if is_awaiting_start() or _session == null:
		_seed_label.text = "DEV · Seed: RANDOM · 6×6 · Move %.1fs" % move_s
	else:
		_seed_label.text = "DEV · Seed: %d · 6×6 · Move %.1fs" % [
			_session.session_seed(),
			move_s,
		]


func _refresh_action_buttons() -> void:
	var awaiting := is_awaiting_start()
	if _start_button != null:
		_start_button.visible = awaiting
		_start_button.disabled = not awaiting
	if _restart_button != null:
		_restart_button.visible = not awaiting
		_restart_button.disabled = awaiting


func _process(delta: float) -> void:
	_update_dev_fps_monitor(delta)
	# Pre-game vs gameplay: do not use presenter.busy alone for Session clock.
	if _app_active:
		match _start_phase:
			StartPhase.OPENING:
				if _presenter != null and _presenter.is_busy():
					_presenter.advance(delta * 1000.0)
				else:
					_begin_countdown()
			StartPhase.COUNTDOWN:
				_countdown_elapsed_ms += delta * 1000.0
				if _countdown_elapsed_ms >= PRESTART_COUNTDOWN_MS:
					_begin_running()
				else:
					_update_countdown_overlay()
			StartPhase.RUNNING:
				if _presenter != null and _presenter.is_busy():
					_presenter.advance(delta * 1000.0)
				_advance_session_clock(delta)
				if _go_overlay_remaining_ms > 0.0:
					_go_overlay_remaining_ms = maxf(0.0, _go_overlay_remaining_ms - delta * 1000.0)
					if _go_overlay_remaining_ms <= 0.0:
						_update_countdown_overlay()
			_:
				pass
	_refresh_hud()
	if _start_phase != StartPhase.READY or (_session != null and _session.is_valid()):
		queue_redraw()


## Foreground Session clock. Pre-game / READY / background / SESSION_OVER / ERROR do not consume time.
## After RUNNING: advances during gameplay presentation too (Score Attack tempo).
func _advance_session_clock(delta: float) -> void:
	if _start_phase != StartPhase.RUNNING:
		return
	if _session == null or not _session.is_valid():
		return
	if not _app_active:
		return
	var st := _session.state()
	if st != PuzzleSession.State.IDLE and st != PuzzleSession.State.ROUTE_DRAG:
		return
	# Skip startup / focus transition frames (abnormal first delta); do not count them.
	if _skip_timer_frames > 0:
		_skip_timer_frames -= 1
		_elapsed_accumulator_ms = 0.0
		return
	# Active foreground: preserve all elapsed whole milliseconds (no per-frame gameplay cap).
	_elapsed_accumulator_ms += delta * 1000.0
	var whole_ms := int(floor(_elapsed_accumulator_ms))
	if whole_ms <= 0:
		return
	_elapsed_accumulator_ms -= float(whole_ms)
	# One-shot transition spike filter only (startup/focus). Not a gameplay cap.
	if _drop_transition_spike and whole_ms > 1000:
		_drop_transition_spike = false
		return
	_drop_transition_spike = false
	var before_state := _session.state()
	_session.advance_time(whole_ms)
	_on_domain_time_advanced(before_state)


## DEV-only FPS sample; throttled so Label text is not rewritten every frame.
func _update_dev_fps_monitor(delta: float) -> void:
	if not SHOW_DEV_FPS or _fps_label == null:
		return
	_fps_sample_accum_ms += delta * 1000.0
	if _fps_sample_accum_ms < FPS_SAMPLE_INTERVAL_MS:
		return
	_fps_sample_accum_ms = 0.0
	var fps := Engine.get_frames_per_second()
	var frame_ms := 0.0
	if fps > 0.0:
		frame_ms = 1000.0 / float(fps)
	_fps_label.text = "FPS: %d\nFrame: %.1f ms" % [int(round(fps)), frame_ms]


func _gui_input(event: InputEvent) -> void:
	# Pre-session READY: board input disabled.
	if not board_input_enabled():
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
	if not board_input_enabled():
		return false
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
	if _session == null or _session.state() != PuzzleSession.State.ROUTE_DRAG:
		_refresh_hud()
		queue_redraw()
		return
	var move := _session.release_drag()
	# Consume stored packet so timer path does not replay the same presentation.
	_session.consume_last_move_result()
	if move.is_success() and move.move_score() > 0:
		_last_move_note = "+%d  Cascade %d" % [move.move_score(), maxi(move.cascade_step_count(), 1)]
	elif move.is_success():
		_last_move_note = "No match"
	elif move.is_error():
		_last_move_note = "ERROR"
	else:
		_last_move_note = ""
	if move.is_success() and move.has_presentation():
		_presenter.begin(move)
	_refresh_hud()
	queue_redraw()


func _update_geometry() -> void:
	if _board_area == null or _session == null:
		_geometry = null
		return
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


## Domain forced release (move/session expiry) may leave the pointer still down.
func _on_domain_time_advanced(before_state: PuzzleSession.State) -> void:
	if before_state != PuzzleSession.State.ROUTE_DRAG:
		return
	if _session == null or _session.state() == PuzzleSession.State.ROUTE_DRAG:
		return
	_mapper.clear()
	var reason := _session.last_end_reason()
	if reason == "move_expiry":
		_last_move_note = "Move timer expired — forced release"
	elif reason == "session_expiry":
		_last_move_note = "Session timer expired — forced release"
	var move := _session.consume_last_move_result()
	if move != null and move.is_success() and move.has_presentation():
		_presenter.begin(move)


func _refresh_hud() -> void:
	if _score_label == null:
		return
	if is_awaiting_start():
		_score_label.text = "Score: ---"
		_session_timer_label.text = "Session: ---"
		_move_timer_label.text = "Move: ---"
		if _rock_label != null:
			_rock_label.text = (
				"ROCK: --- (ON at START)"
				if _obstacle_mode == PuzzleSession.ObstacleMode.ROCK
				else "ROCK: OFF (DEV baseline)"
			)
		_state_label.text = "State: READY"
		_note_label.text = "READY — Pick duration / Obstacle and press START"
		_refresh_seed_label()
		_refresh_action_buttons()
		return
	if _session == null:
		return
	_refresh_seed_label()
	_score_label.text = "Score: %d" % _session.score()
	var session_sec := float(_session.remaining_ms()) / 1000.0
	_session_timer_label.text = "Session: %.1fs" % session_sec
	if _session.has_active_move_timer():
		var move_sec := float(_session.move_remaining_ms()) / 1000.0
		_move_timer_label.text = "Move: %.1fs" % move_sec
	else:
		_move_timer_label.text = "Move: ---"
	if _rock_label != null:
		if _session.obstacle_mode() == PuzzleSession.ObstacleMode.ROCK:
			_rock_label.text = "ROCK: %d" % _session.rock_count()
		else:
			_rock_label.text = "ROCK: OFF (DEV)"
	match _start_phase:
		StartPhase.OPENING:
			_state_label.text = "State: OPENING"
		StartPhase.COUNTDOWN:
			_state_label.text = "State: COUNTDOWN"
		StartPhase.RUNNING:
			if is_presentation_busy():
				_state_label.text = "State: PRESENTING"
			else:
				_state_label.text = "State: %s" % _state_name(_session.state())
		_:
			_state_label.text = "State: READY"
	var note := _last_move_note
	if _start_phase == StartPhase.OPENING:
		note = "Opening — rocks dropping"
	elif _start_phase == StartPhase.COUNTDOWN:
		note = "Get ready — %d" % countdown_digit()
	elif is_go_overlay_visible():
		note = "GO!"
	# SESSION OVER banner waits until presentation finishes (expiry mid-anim is OK).
	elif not is_presentation_busy() and _session.state() == PuzzleSession.State.SESSION_OVER:
		note = "SESSION OVER — Score %d — Restart / pick 45·60·90" % _session.score()
	elif _session.state() == PuzzleSession.State.ERROR:
		note = "ERROR — input blocked"
	_note_label.text = note
	_refresh_action_buttons()


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
	if is_awaiting_start():
		_draw_ready_placeholder()
		return
	_update_geometry()
	if _geometry == null or _session == null:
		return
	var presenting := _presenter != null and _presenter.is_busy()
	var snap: Array = _presenter.vis_orbs if presenting else _session.board_snapshot()
	var head := Vector2i(-1, -1) if presenting else _session.active_drag_current_cell()
	var cell_size := _geometry.cell_size()
	# --- Static layer: cells that are not active moving-token sources/targets ---
	for y in range(DEV_HEIGHT):
		if y >= snap.size():
			continue
		var row: Array = snap[y]
		for x in range(DEV_WIDTH):
			var cell := Vector2i(x, y)
			var rect := _geometry.cell_rect(cell)
			draw_rect(rect, Color(0.12, 0.14, 0.18), true)
			draw_rect(rect, Color(0.35, 0.38, 0.45), false, 2.0)
			if presenting and cell in _presenter.highlight_cells:
				draw_rect(rect.grow(-2.0), Color(1.0, 0.95, 0.35, 0.55), false, 3.0)
			if presenting and cell in _presenter.spawn_cells:
				draw_rect(rect.grow(-4.0), Color(0.95, 0.75, 0.25, 0.7), false, 3.0)
			# Suppress static tokens that are currently on the moving layer.
			if presenting and (
				_presenter.is_gravity_source(cell)
				or _presenter.is_gravity_destination(cell)
				or _presenter.is_refill_target(cell)
				or _presenter.is_spawn_target(cell)
			):
				continue
			var is_rock := (
				_presenter.is_rock(cell) if presenting else _session.is_rock_at(cell)
			)
			if is_rock:
				var rock_fill := Color(0.45, 0.45, 0.48)
				if presenting and cell in _presenter.flash_rocks:
					rock_fill = Color(0.85, 0.55, 0.35)
				_draw_rock_at_rect(rect, rock_fill, (
					_presenter.rock_hp_at(cell) if presenting else _session.rock_hp_at(cell)
				))
				continue
			var orb_id: int = row[x] if x < row.size() else -1
			if presenting:
				orb_id = _presenter.orb_at(cell)
			if orb_id >= 0:
				_draw_orb_at_rect(rect, orb_id, 1.0)
			if head == cell and _session.has_active_drag():
				draw_rect(rect.grow(-3.0), Color(1.0, 1.0, 1.0, 0.85), false, 3.0)
	# --- Moving layer: continuous token interpolation (Gravity / Refill / Respawn) ---
	if presenting:
		_draw_moving_tokens(cell_size)


func _draw_moving_tokens(_cell_size: float) -> void:
	if _presenter.phase == ResolutionPresenter.Phase.GRAVITY:
		for item in _presenter.gravity_moves:
			var mv: GravityMoveTrace = item
			var center := _presenter.gravity_token_center(mv, _geometry)
			var rect := _token_rect_at_center(center, mv.is_rock())
			if mv.is_rock():
				_draw_rock_at_rect(rect, Color(0.45, 0.45, 0.48), mv.rock_hp())
			else:
				_draw_orb_at_rect(rect, mv.orb_id(), 1.0)
		return
	if _presenter.phase == ResolutionPresenter.Phase.REFILL:
		for item in _presenter.refill_cells:
			var rf: RefillTrace = item
			var center := _presenter.refill_token_center(rf, _geometry)
			var rect := _token_rect_at_center(center, false)
			_draw_orb_at_rect(rect, rf.orb_id(), 1.0)
		return
	if (
		_presenter.phase == ResolutionPresenter.Phase.RESPAWN_WARN
		or _presenter.phase == ResolutionPresenter.Phase.RESPAWN_SHOW
	):
		for pos in _presenter.spawn_cells:
			var center := _presenter.spawn_token_center(pos, _geometry)
			var rect := _token_rect_at_center(center, true)
			var border := Color(0.95, 0.75, 0.25) if _presenter.phase == ResolutionPresenter.Phase.RESPAWN_WARN else Color(0.20, 0.20, 0.22)
			_draw_rock_at_rect(rect, Color(0.45, 0.45, 0.48), 2, border)


func _token_rect_at_center(center: Vector2, is_rock: bool) -> Rect2:
	var cs := _geometry.cell_size()
	var inset_frac := 0.08 if is_rock else 0.12
	var side := cs * (1.0 - inset_frac * 2.0)
	return Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))


func _draw_orb_at_rect(inset: Rect2, orb_id: int, alpha: float) -> void:
	var fill := _orb_color(orb_id)
	fill.a = alpha
	draw_rect(inset, fill, true)
	var label := _orb_symbol(orb_id)
	var font := ThemeDB.fallback_font
	var font_size := int(maxi(12, int(inset.size.x * 0.35)))
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos := inset.position + (inset.size - text_size) * 0.5 + Vector2(0, text_size.y * 0.8)
	draw_string(
		font,
		text_pos,
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(0.05, 0.05, 0.08, alpha)
	)


func _draw_rock_at_rect(inset: Rect2, fill: Color, hp: int, border: Color = Color(0.20, 0.20, 0.22)) -> void:
	draw_rect(inset, fill, true)
	draw_rect(inset, border, false, 2.0)
	var font := ThemeDB.fallback_font
	var font_size := int(maxi(12, int(inset.size.x * 0.36)))
	var label := "R%d" % hp if hp > 0 else "R"
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos := inset.position + (inset.size - text_size) * 0.5 + Vector2(0, text_size.y * 0.8)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.95, 0.95, 0.92))


func _draw_ready_placeholder() -> void:
	var top_left := Vector2(16.0, size.y * 0.38)
	var avail := Vector2(size.x - 32.0, size.y * 0.45)
	if _board_area != null and _board_area.size.y >= 8.0:
		top_left = _board_area.position
		avail = _board_area.size
	var rect := Rect2(top_left, avail)
	draw_rect(rect, Color(0.10, 0.12, 0.16), true)
	draw_rect(rect, Color(0.40, 0.44, 0.52), false, 2.0)
	var font := ThemeDB.fallback_font
	var line1 := "READY"
	var line2 := "Pick duration and press START"
	var fs1 := 28
	var fs2 := 16
	var s1 := font.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1)
	var s2 := font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
	var p1 := rect.position + Vector2((rect.size.x - s1.x) * 0.5, rect.size.y * 0.42)
	var p2 := rect.position + Vector2((rect.size.x - s2.x) * 0.5, rect.size.y * 0.55)
	draw_string(font, p1, line1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1, Color(0.92, 0.94, 0.98))
	draw_string(font, p2, line2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.75, 0.78, 0.85))


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
