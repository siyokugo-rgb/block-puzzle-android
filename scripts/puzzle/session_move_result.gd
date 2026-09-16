class_name SessionMoveResult
extends RefCounted

## Phase R-E: release / resolve outcome for UI later. No second Score formula.


var _success: bool = false
var _error: bool = false
var _session_over: bool = false
var _cascade_step_count: int = 0
var _cleared_per_step: Array[int] = []
var _move_score: int = 0
var _score_after: int = 0


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
	return r


static func resolved(
	cascade_step_count: int,
	cleared_per_step: Array,
	move_score: int,
	score_after: int,
	session_over: bool
) -> SessionMoveResult:
	var r := SessionMoveResult.new()
	r._success = true
	r._error = false
	r._session_over = session_over
	r._cascade_step_count = cascade_step_count
	r._cleared_per_step = _copy_ints(cleared_per_step)
	r._move_score = move_score
	r._score_after = score_after
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


static func _copy_ints(src: Array) -> Array[int]:
	var out: Array[int] = []
	for item in src:
		if typeof(item) == TYPE_INT:
			out.append(item)
	return out
