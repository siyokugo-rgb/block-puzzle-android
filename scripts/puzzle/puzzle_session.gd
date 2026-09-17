class_name PuzzleSession
extends RefCounted

## Phase R-E / R-F: UI-free Score Attack session.
## Owns board, generator, drag, session timer, and per-move timer privately.

enum State {
	INVALID,
	IDLE,
	ROUTE_DRAG,
	RESOLVING,
	SESSION_OVER,
	ERROR,
}

## Signed 64-bit maximum (INT64_MAX). Godot `int` is 64-bit.
const SCORE_MAX := 9223372036854775807

## Per-drag move budget (Phase R-F Gate 1 DEV value; not production final).
const MOVE_DURATION_MS := 2000

var _state: State = State.INVALID
var _board: PuzzleBoard = null
var _generator: OrbGenerator = null
var _route: DragRoute = null
var _remaining_ms: int = 0
var _move_remaining_ms: int = 0
var _score: int = 0
var _max_cascade_steps: int = CascadeResolver.MAX_CASCADE_STEPS
var _expiry_handled: bool = false
var _last_end_reason: String = ""


## Create a Score Attack session. Uses one OrbGenerator for fill + later cascade refill.
## Optional max_cascade_steps is an internal safety seam (default 128); not a gameplay flag.
static func create_score_attack(
	width: int,
	height: int,
	seed_value: int,
	duration_ms: int,
	max_cascade_steps: int = CascadeResolver.MAX_CASCADE_STEPS
) -> PuzzleSession:
	var session := PuzzleSession.new()
	session._build(width, height, seed_value, duration_ms, max_cascade_steps)
	return session


func _build(
	width: int,
	height: int,
	seed_value: int,
	duration_ms: int,
	max_cascade_steps: int
) -> void:
	_state = State.INVALID
	_board = null
	_generator = null
	_route = null
	_remaining_ms = 0
	_move_remaining_ms = 0
	_score = 0
	_max_cascade_steps = max_cascade_steps
	_expiry_handled = false
	_last_end_reason = ""

	if width <= 0 or height <= 0:
		return
	if duration_ms <= 0:
		return
	if max_cascade_steps < 0:
		return

	var board := PuzzleBoard.create(width, height)
	if not board.is_valid():
		return
	var generator := OrbGenerator.create()
	if not generator.is_valid():
		return
	generator.set_seed(seed_value)
	if not generator.fill_match_stable(board):
		return
	var opening := MatchResolver.detect(board)
	if not opening.is_valid() or opening.has_matches():
		return

	_board = board
	_generator = generator
	_remaining_ms = duration_ms
	_move_remaining_ms = 0
	_score = 0
	_state = State.IDLE


# --- Read API ---


func state() -> State:
	return _state


func is_valid() -> bool:
	return _state != State.INVALID


func remaining_ms() -> int:
	return _remaining_ms


## Active only during ROUTE_DRAG; otherwise 0 (UI may show "---").
func move_remaining_ms() -> int:
	if _state != State.ROUTE_DRAG:
		return 0
	return _move_remaining_ms


func has_active_move_timer() -> bool:
	return _state == State.ROUTE_DRAG


## DEV/UI note for last forced end reason ("", "move_expiry", "session_expiry").
func last_end_reason() -> String:
	return _last_end_reason


func score() -> int:
	return _score


func board_width() -> int:
	return _board.width() if _board != null and _board.is_valid() else 0


func board_height() -> int:
	return _board.height() if _board != null and _board.is_valid() else 0


func orb_at(pos: Vector2i) -> int:
	if _board == null or not _board.is_valid():
		return -1
	return _board.orb_at(pos)


func board_snapshot() -> Array:
	if _board == null or not _board.is_valid():
		return []
	return _board.snapshot_orb_ids()


func has_active_drag() -> bool:
	return _route != null and _route.is_active()


func active_drag_current_cell() -> Vector2i:
	if not has_active_drag():
		return Vector2i(-1, -1)
	return _route.current_cell()


func active_drag_path_snapshot() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not has_active_drag():
		return out
	return _route.path_snapshot()


func active_drag_swap_count() -> int:
	if not has_active_drag():
		return 0
	return _route.swap_count()


# --- Drag ---


func begin_drag(cell: Vector2i) -> bool:
	if _state != State.IDLE:
		return false
	if _remaining_ms <= 0:
		return false
	if _board == null or not _board.is_valid():
		return false
	var route := DragRoute.begin(_board, cell)
	if route == null:
		return false
	_route = route
	_move_remaining_ms = MOVE_DURATION_MS
	_last_end_reason = ""
	_state = State.ROUTE_DRAG
	return true


func step_drag(next_cell: Vector2i) -> DragRoute.StepResult:
	if _state != State.ROUTE_DRAG:
		return DragRoute.StepResult.REJECTED
	if _remaining_ms <= 0:
		return DragRoute.StepResult.REJECTED
	if _move_remaining_ms <= 0:
		return DragRoute.StepResult.REJECTED
	if _route == null or not _route.is_active():
		return DragRoute.StepResult.REJECTED
	return _route.try_step(next_cell)


func release_drag() -> SessionMoveResult:
	if _state != State.ROUTE_DRAG:
		return SessionMoveResult.ignored()
	var swaps := 0
	if _route != null:
		swaps = _route.swap_count()
	_route = null
	_move_remaining_ms = 0
	if swaps == 0:
		if _remaining_ms > 0:
			_state = State.IDLE
		else:
			_state = State.SESSION_OVER
			_expiry_handled = true
		return SessionMoveResult.no_resolve(_score, _state == State.SESSION_OVER)
	return _resolve_after_release(_remaining_ms == 0)


# --- Timer ---


func advance_time(elapsed_ms: int) -> void:
	if elapsed_ms < 0:
		return
	if elapsed_ms == 0:
		return
	if _state != State.IDLE and _state != State.ROUTE_DRAG:
		# RESOLVING / SESSION_OVER / ERROR / INVALID: both timers paused.
		return

	if _state == State.IDLE:
		if _remaining_ms <= 0:
			return
		_remaining_ms = maxi(0, _remaining_ms - elapsed_ms)
		if _remaining_ms == 0:
			_handle_session_expiry()
		return

	# ROUTE_DRAG: deduct the same elapsed from Session + Move.
	if _remaining_ms <= 0 and _move_remaining_ms <= 0:
		return
	var session_before := _remaining_ms
	var move_before := _move_remaining_ms
	_remaining_ms = maxi(0, _remaining_ms - elapsed_ms)
	_move_remaining_ms = maxi(0, _move_remaining_ms - elapsed_ms)
	var session_hit := session_before > 0 and _remaining_ms == 0
	var move_hit := move_before > 0 and _move_remaining_ms == 0
	# Simultaneous → Session expiry wins; forced release once.
	if session_hit:
		_handle_session_expiry()
	elif move_hit:
		_handle_move_expiry()


func _handle_session_expiry() -> void:
	if _expiry_handled and _state != State.ROUTE_DRAG:
		return
	_expiry_handled = true
	_last_end_reason = "session_expiry"
	if _state == State.IDLE:
		_move_remaining_ms = 0
		_state = State.SESSION_OVER
		return
	if _state != State.ROUTE_DRAG:
		return
	var swaps := 0
	if _route != null:
		swaps = _route.swap_count()
	_route = null
	_move_remaining_ms = 0
	if swaps == 0:
		_state = State.SESSION_OVER
		return
	_resolve_after_release(true)


func _handle_move_expiry() -> void:
	if _state != State.ROUTE_DRAG:
		return
	_last_end_reason = "move_expiry"
	var swaps := 0
	if _route != null:
		swaps = _route.swap_count()
	_route = null
	_move_remaining_ms = 0
	if swaps == 0:
		if _remaining_ms > 0:
			_state = State.IDLE
		else:
			_state = State.SESSION_OVER
			_expiry_handled = true
		return
	_resolve_after_release(_remaining_ms == 0)


func _resolve_after_release(force_session_over: bool) -> SessionMoveResult:
	_state = State.RESOLVING
	_move_remaining_ms = 0
	var cascade := CascadeResolver.resolve(_board, _generator, _max_cascade_steps)
	if not cascade.is_stable():
		_state = State.ERROR
		return SessionMoveResult.failed(_score)

	var cleared := cascade.cleared_cell_count_per_step_snapshot()
	var scored := compute_move_score(cleared)
	if not bool(scored["ok"]):
		_state = State.ERROR
		return SessionMoveResult.failed(_score)

	var move_score: int = scored["value"]
	var committed := checked_add(_score, move_score)
	if not bool(committed["ok"]):
		_state = State.ERROR
		return SessionMoveResult.failed(_score)

	_score = committed["value"]
	var session_over := force_session_over or _remaining_ms == 0
	if session_over:
		_state = State.SESSION_OVER
		_expiry_handled = true
	else:
		_state = State.IDLE
	return SessionMoveResult.resolved(
		cascade.step_count(),
		cleared,
		move_score,
		_score,
		session_over
	)


# --- Checked score arithmetic (testable; single Score formula) ---


## Non-negative multiply with overflow detection. Returns {ok: bool, value: int}.
static func checked_mul(a: int, b: int) -> Dictionary:
	if a < 0 or b < 0:
		return {"ok": false, "value": 0}
	if a == 0 or b == 0:
		return {"ok": true, "value": 0}
	if a > SCORE_MAX / b:
		return {"ok": false, "value": 0}
	return {"ok": true, "value": a * b}


## Non-negative add with overflow detection. Returns {ok: bool, value: int}.
static func checked_add(a: int, b: int) -> Dictionary:
	if a < 0 or b < 0:
		return {"ok": false, "value": 0}
	if a > SCORE_MAX - b:
		return {"ok": false, "value": 0}
	return {"ok": true, "value": a + b}


## Provisional Score from per-step cleared counts. Returns {ok: bool, value: int}.
## Does not mutate session score — caller commits once.
static func compute_move_score(cleared_per_step: Array) -> Dictionary:
	var total := 0
	for i in range(cleared_per_step.size()):
		var item: Variant = cleared_per_step[i]
		if typeof(item) != TYPE_INT:
			return {"ok": false, "value": 0}
		var cleared: int = item
		if cleared < 0:
			return {"ok": false, "value": 0}
		var step_index := i + 1
		var base := checked_mul(cleared, 100)
		if not bool(base["ok"]):
			return {"ok": false, "value": 0}
		var depth := step_index - 1
		var part := checked_mul(cleared, 25)
		if not bool(part["ok"]):
			return {"ok": false, "value": 0}
		var bonus := checked_mul(part["value"], depth)
		if not bool(bonus["ok"]):
			return {"ok": false, "value": 0}
		var step_score := checked_add(base["value"], bonus["value"])
		if not bool(step_score["ok"]):
			return {"ok": false, "value": 0}
		var next := checked_add(total, step_score["value"])
		if not bool(next["ok"]):
			return {"ok": false, "value": 0}
		total = next["value"]
	return {"ok": true, "value": total}
