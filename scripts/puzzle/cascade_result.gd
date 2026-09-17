class_name CascadeResult
extends RefCounted

## Phase R-D / R-G: cascade resolution outcome.
## Neutral metrics only — no Score / combo formula fields.


var _valid: bool = false
var _stable: bool = false
var _guard_exceeded: bool = false
var _step_count: int = 0
var _cleared_per_step: Array[int] = []
var _rocks_destroyed_per_step: Array[int] = []


static func invalid() -> CascadeResult:
	var result := CascadeResult.new()
	result._valid = false
	result._stable = false
	result._guard_exceeded = false
	result._step_count = 0
	result._cleared_per_step.clear()
	result._rocks_destroyed_per_step.clear()
	return result


static func guard_exceeded(
	step_count: int,
	cleared_per_step: Array,
	rocks_destroyed_per_step: Array = []
) -> CascadeResult:
	var result := CascadeResult.new()
	result._valid = false
	result._stable = false
	result._guard_exceeded = true
	result._step_count = maxi(step_count, 0)
	result._cleared_per_step = _copy_ints(cleared_per_step)
	result._rocks_destroyed_per_step = _copy_ints(rocks_destroyed_per_step)
	return result


static func stable_success(
	step_count: int,
	cleared_per_step: Array,
	rocks_destroyed_per_step: Array = []
) -> CascadeResult:
	var result := CascadeResult.new()
	result._valid = true
	result._stable = true
	result._guard_exceeded = false
	result._step_count = maxi(step_count, 0)
	result._cleared_per_step = _copy_ints(cleared_per_step)
	result._rocks_destroyed_per_step = _copy_ints(rocks_destroyed_per_step)
	return result


func is_valid() -> bool:
	return _valid


func is_stable() -> bool:
	return _valid and _stable


func is_guard_exceeded() -> bool:
	return _guard_exceeded


func step_count() -> int:
	return _step_count


func total_cleared_cells() -> int:
	var total := 0
	for n in _cleared_per_step:
		total += n
	return total


func total_rocks_destroyed() -> int:
	var total := 0
	for n in _rocks_destroyed_per_step:
		total += n
	return total


## Defensive copy of per-step unique cleared cell counts (e.g. [6, 3, 8]).
func cleared_cell_count_per_step_snapshot() -> Array[int]:
	return _copy_ints(_cleared_per_step)


func rocks_destroyed_per_step_snapshot() -> Array[int]:
	return _copy_ints(_rocks_destroyed_per_step)


static func _copy_ints(src: Array) -> Array[int]:
	var out: Array[int] = []
	for item in src:
		if typeof(item) == TYPE_INT:
			out.append(item)
	return out
