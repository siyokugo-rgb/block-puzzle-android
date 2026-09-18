class_name SessionMoveResult
extends RefCounted

## Phase R-E / R-G: release / resolve outcome for UI. No second Score formula.
## Optional presentation snapshots/traces — defensive copies only.


var _success: bool = false
var _error: bool = false
var _session_over: bool = false
var _cascade_step_count: int = 0
var _cleared_per_step: Array[int] = []
var _move_score: int = 0
var _score_after: int = 0
var _board_before_orbs: Array = []
var _board_before_obstacles: Array = []
var _board_before_hp: Array = []
var _cascade_steps: Array = [] # Array[CascadeStepTrace]
var _rock_spawns: Array = [] # Array[RockSpawnTrace]
var _had_swaps: bool = false


static func ignored() -> SessionMoveResult:
	var r := SessionMoveResult.new()
	r._success = false
	r._error = false
	return r


static func no_resolve(score_after: int, session_over: bool) -> SessionMoveResult:
	var r := SessionMoveResult.new()
	r._success = true
	r._error = false
	r._session_over = session_over
	r._cascade_step_count = 0
	r._cleared_per_step.clear()
	r._move_score = 0
	r._score_after = score_after
	r._had_swaps = false
	return r


static func resolved(
	cascade_step_count: int,
	cleared_per_step: Array,
	move_score: int,
	score_after: int,
	session_over: bool,
	board_before_orbs: Array = [],
	board_before_obstacles: Array = [],
	board_before_hp: Array = [],
	cascade_steps: Array = [],
	rock_spawns: Array = []
) -> SessionMoveResult:
	var r := SessionMoveResult.new()
	r._success = true
	r._error = false
	r._session_over = session_over
	r._cascade_step_count = cascade_step_count
	r._cleared_per_step = _copy_ints(cleared_per_step)
	r._move_score = move_score
	r._score_after = score_after
	r._board_before_orbs = _copy_grid(board_before_orbs)
	r._board_before_obstacles = _copy_grid(board_before_obstacles)
	r._board_before_hp = _copy_grid(board_before_hp)
	r._cascade_steps = _copy_steps(cascade_steps)
	r._rock_spawns = _copy_spawns(rock_spawns)
	r._had_swaps = true
	return r


static func failed(score_after: int) -> SessionMoveResult:
	var r := SessionMoveResult.new()
	r._success = false
	r._error = true
	r._session_over = false
	r._score_after = score_after
	return r


func is_success() -> bool:
	return _success


func is_error() -> bool:
	return _error


func is_session_over() -> bool:
	return _session_over


func cascade_step_count() -> int:
	return _cascade_step_count


func cleared_per_step_snapshot() -> Array[int]:
	return _copy_ints(_cleared_per_step)


func move_score() -> int:
	return _move_score


func score_after() -> int:
	return _score_after


func had_swaps() -> bool:
	return _had_swaps


func board_before_orbs_snapshot() -> Array:
	return _copy_grid(_board_before_orbs)


func board_before_obstacles_snapshot() -> Array:
	return _copy_grid(_board_before_obstacles)


func board_before_hp_snapshot() -> Array:
	return _copy_grid(_board_before_hp)


func cascade_steps_snapshot() -> Array:
	return _copy_steps(_cascade_steps)


func rock_spawns_snapshot() -> Array:
	return _copy_spawns(_rock_spawns)


func has_presentation() -> bool:
	return not _cascade_steps.is_empty() or not _rock_spawns.is_empty()


static func _copy_ints(src: Array) -> Array[int]:
	var out: Array[int] = []
	for item in src:
		if typeof(item) == TYPE_INT:
			out.append(item)
	return out


static func _copy_grid(src: Array) -> Array:
	var out: Array = []
	for row_v in src:
		if typeof(row_v) != TYPE_ARRAY:
			continue
		var row: Array = []
		for cell in row_v:
			if typeof(cell) == TYPE_INT:
				row.append(cell)
		out.append(row)
	return out


static func _copy_steps(src: Array) -> Array:
	var out: Array = []
	for item in src:
		if item is CascadeStepTrace:
			out.append((item as CascadeStepTrace).duplicate_trace())
	return out


static func _copy_spawns(src: Array) -> Array:
	var out: Array = []
	for item in src:
		if item is RockSpawnTrace:
			out.append((item as RockSpawnTrace).duplicate_trace())
	return out
