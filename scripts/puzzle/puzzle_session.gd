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

## Gate 2 DEV: Obstacle OFF keeps R-F baseline; ROCK uses fixed 3-rock layout.
enum ObstacleMode {
	OFF,
	ROCK,
}

## Fixed DEV ROCK positions — top row only (falling-token Gate 2 DEV).
## Columns x=1,3,4 at y=0. Not production layout.
const DEV_ROCK_LAYOUT: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(3, 0),
	Vector2i(4, 0),
]

## Gate 2 DEV target live ROCK count (respawn toward this).
const TARGET_ROCK_COUNT := 3

## Obstacle RNG seed derivation (independent of OrbGenerator stream).
## Fixed: obstacle_seed = session_seed XOR OBSTACLE_RNG_SEED_XOR
## Documented in IMPLEMENTATION_NOTES — do not change without test updates.
const OBSTACLE_RNG_SEED_XOR := 0x524F434B # ASCII 'ROCK'

var _state: State = State.INVALID
var _board: PuzzleBoard = null
var _generator: OrbGenerator = null
var _obstacle_rng: RandomNumberGenerator = null
var _route: DragRoute = null
var _remaining_ms: int = 0
var _move_remaining_ms: int = 0
var _score: int = 0
var _max_cascade_steps: int = CascadeResolver.MAX_CASCADE_STEPS
var _expiry_handled: bool = false
var _last_end_reason: String = ""
var _obstacle_mode: ObstacleMode = ObstacleMode.OFF
var _pending_rock_respawns: int = 0
var _respawn_armed: bool = false
var _session_seed: int = 0
var _last_move_result: SessionMoveResult = null


## Create a Score Attack session. Uses one OrbGenerator for fill + later cascade refill.
## Optional max_cascade_steps is an internal safety seam (default 128); not a gameplay flag.
## obstacle_mode: OFF = R-F baseline; ROCK = apply DEV_ROCK_LAYOUT after stable fill.
static func create_score_attack(
	width: int,
	height: int,
	seed_value: int,
	duration_ms: int,
	max_cascade_steps: int = CascadeResolver.MAX_CASCADE_STEPS,
	obstacle_mode: int = ObstacleMode.OFF
) -> PuzzleSession:
	var session := PuzzleSession.new()
	session._build(width, height, seed_value, duration_ms, max_cascade_steps, obstacle_mode)
	return session


func _build(
	width: int,
	height: int,
	seed_value: int,
	duration_ms: int,
	max_cascade_steps: int,
	obstacle_mode: int
) -> void:
	_state = State.INVALID
	_board = null
	_generator = null
	_obstacle_rng = null
	_route = null
	_remaining_ms = 0
	_move_remaining_ms = 0
	_score = 0
	_max_cascade_steps = max_cascade_steps
	_expiry_handled = false
	_last_end_reason = ""
	_obstacle_mode = ObstacleMode.OFF
	_pending_rock_respawns = 0
	_respawn_armed = false
	_session_seed = seed_value
	_last_move_result = null

	if width <= 0 or height <= 0:
		return
	if duration_ms <= 0:
		return
	if max_cascade_steps < 0:
		return
	if obstacle_mode != ObstacleMode.OFF and obstacle_mode != ObstacleMode.ROCK:
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

	if obstacle_mode == ObstacleMode.ROCK:
		if not _apply_dev_rock_layout(board):
			return
		# Replacing orbs with ROCK cannot create matches (ROCK has no orb).
		var after_rocks := MatchResolver.detect(board)
		if not after_rocks.is_valid() or after_rocks.has_matches():
			return

	_board = board
	_generator = generator
	_remaining_ms = duration_ms
	_move_remaining_ms = 0
	_score = 0
	_obstacle_mode = obstacle_mode as ObstacleMode
	_pending_rock_respawns = 0
	_respawn_armed = false
	_obstacle_rng = RandomNumberGenerator.new()
	_obstacle_rng.seed = derive_obstacle_rng_seed(seed_value)
	_state = State.IDLE


## Fixed XOR derivation — must stay stable for deterministic ROCK spawn sequences.
static func derive_obstacle_rng_seed(session_seed: int) -> int:
	return session_seed ^ OBSTACLE_RNG_SEED_XOR


static func _apply_dev_rock_layout(board: PuzzleBoard) -> bool:
	for pos in DEV_ROCK_LAYOUT:
		if not board.in_bounds(pos):
			return false
		if not board.set_rock(pos):
			return false
	return true


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


func obstacle_snapshot() -> Array:
	if _board == null or not _board.is_valid():
		return []
	return _board.snapshot_obstacle_types()


func obstacle_mode() -> ObstacleMode:
	return _obstacle_mode


func rock_count() -> int:
	if _board == null or not _board.is_valid():
		return 0
	return _board.rock_count()


func is_rock_at(pos: Vector2i) -> bool:
	if _board == null or not _board.is_valid():
		return false
	return _board.is_rock(pos)


## ROCK HP at pos (1 or 2), or 0 if not ROCK / invalid.
func rock_hp_at(pos: Vector2i) -> int:
	if _board == null or not _board.is_valid():
		return 0
	return _board.rock_hp_at(pos)


func pending_rock_respawns() -> int:
	return _pending_rock_respawns


func respawn_armed() -> bool:
	return _respawn_armed


## Last resolve/no-resolve move packet (presentation). Null until first release.
func last_move_result() -> SessionMoveResult:
	return _last_move_result


func consume_last_move_result() -> SessionMoveResult:
	var r := _last_move_result
	_last_move_result = null
	return r


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
		var nores := SessionMoveResult.no_resolve(_score, _state == State.SESSION_OVER)
		_last_move_result = nores
		return nores
	var resolved := _resolve_after_release(_remaining_ms == 0)
	_last_move_result = resolved
	return resolved


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
	var res := _resolve_after_release(true)
	_last_move_result = res


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
		_last_move_result = SessionMoveResult.no_resolve(_score, _state == State.SESSION_OVER)
		return
	var res := _resolve_after_release(_remaining_ms == 0)
	_last_move_result = res


func _resolve_after_release(force_session_over: bool) -> SessionMoveResult:
	_state = State.RESOLVING
	_move_remaining_ms = 0
	var before_orbs := _board.snapshot_orb_ids()
	var before_obs := _board.snapshot_obstacle_types()
	var before_hp := _board.snapshot_obstacle_hp()
	var cascade := CascadeResolver.resolve(_board, _generator, _max_cascade_steps)
	if not cascade.is_stable():
		_state = State.ERROR
		_pending_rock_respawns = 0
		_respawn_armed = false
		return SessionMoveResult.failed(_score)

	var cleared := cascade.cleared_cell_count_per_step_snapshot()
	var scored := compute_move_score(cleared)
	if not bool(scored["ok"]):
		_state = State.ERROR
		_pending_rock_respawns = 0
		_respawn_armed = false
		return SessionMoveResult.failed(_score)

	var move_score: int = scored["value"]
	var committed := checked_add(_score, move_score)
	if not bool(committed["ok"]):
		_state = State.ERROR
		_pending_rock_respawns = 0
		_respawn_armed = false
		return SessionMoveResult.failed(_score)

	_score = committed["value"]
	var session_over := force_session_over or _remaining_ms == 0
	var spawns: Array = []
	if not session_over and _obstacle_mode == ObstacleMode.ROCK:
		spawns = _apply_rock_respawn_after_resolve(cascade.total_rocks_destroyed())
	elif session_over:
		# No spawn after final move; keep pending for QA read but do not mutate board.
		var destroyed := cascade.total_rocks_destroyed()
		if destroyed > 0:
			_pending_rock_respawns += destroyed
		_respawn_armed = false
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
		session_over,
		before_orbs,
		before_obs,
		before_hp,
		cascade.steps_snapshot(),
		spawns
	)


## After a successful ROCK-mode resolve: maybe spawn 1 (if armed), then queue new destroys.
## Returns Array[RockSpawnTrace] (0 or 1 entries). Never errors on empty candidates.
func _apply_rock_respawn_after_resolve(destroyed_this_move: int) -> Array:
	var spawns: Array = []
	if _obstacle_mode != ObstacleMode.ROCK:
		_pending_rock_respawns = 0
		_respawn_armed = false
		return spawns
	if _respawn_armed and _pending_rock_respawns > 0 and rock_count() < TARGET_ROCK_COUNT:
		var spawned := _try_spawn_one_rock()
		if spawned != null:
			spawns.append(spawned)
			_pending_rock_respawns = maxi(0, _pending_rock_respawns - 1)
	if destroyed_this_move > 0:
		_pending_rock_respawns += destroyed_this_move
	# Cap pending so we never plan more than needed to reach TARGET.
	var deficit := maxi(0, TARGET_ROCK_COUNT - rock_count())
	if _pending_rock_respawns > deficit:
		_pending_rock_respawns = deficit
	_respawn_armed = _pending_rock_respawns > 0
	return spawns


## Pick one top-row eligible cell via obstacle RNG; place R2. Null if none.
## Mid-board spawn is forbidden — only y == 0.
func _try_spawn_one_rock() -> RockSpawnTrace:
	if _board == null or not _board.is_valid():
		return null
	if _obstacle_rng == null:
		return null
	if rock_count() >= TARGET_ROCK_COUNT:
		return null
	var candidates: Array[Vector2i] = []
	var y := 0
	for x in range(_board.width()):
		var pos := Vector2i(x, y)
		if _board.has_obstacle(pos):
			continue
		# Orb may be present — spawn replaces it with ROCK HP=2.
		candidates.append(pos)
	if candidates.is_empty():
		return null
	var idx := _obstacle_rng.randi_range(0, candidates.size() - 1)
	var chosen: Vector2i = candidates[idx]
	# Clear orb if present, then place fresh R2.
	if _board.has_orb(chosen):
		if not _board.clear_orb(chosen):
			return null
	if not _board.set_rock(chosen):
		return null
	return RockSpawnTrace.create(chosen, PuzzleCell.ROCK_INITIAL_HP)


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
