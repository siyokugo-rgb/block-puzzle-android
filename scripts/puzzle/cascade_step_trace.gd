class_name CascadeStepTrace
extends RefCounted

## One cascade step's presentation-neutral domain trace.
## Defensive snapshots — mutating returned arrays does not affect stored state.

var _step_index: int = 0
var _matched_cells: Array[Vector2i] = []
var _rock_hits: Array = [] # Array[RockHitTrace]
var _gravity_moves: Array = [] # Array[GravityMoveTrace]
var _refills: Array = [] # Array[RefillTrace]


static func create(
	step_index: int,
	matched_cells: Array,
	rock_hits: Array,
	gravity_moves: Array,
	refills: Array
) -> CascadeStepTrace:
	var t := CascadeStepTrace.new()
	t._step_index = step_index
	t._matched_cells = _copy_cells(matched_cells)
	t._rock_hits = _copy_hits(rock_hits)
	t._gravity_moves = _copy_moves(gravity_moves)
	t._refills = _copy_refills(refills)
	return t


func step_index() -> int:
	return _step_index


func matched_cells_snapshot() -> Array[Vector2i]:
	return _copy_cells(_matched_cells)


func rock_hits_snapshot() -> Array:
	return _copy_hits(_rock_hits)


func gravity_moves_snapshot() -> Array:
	return _copy_moves(_gravity_moves)


func refills_snapshot() -> Array:
	return _copy_refills(_refills)


func duplicate_trace() -> CascadeStepTrace:
	return create(_step_index, _matched_cells, _rock_hits, _gravity_moves, _refills)


static func _copy_cells(src: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for item in src:
		if typeof(item) == TYPE_VECTOR2I:
			out.append(item)
	return out


static func _copy_hits(src: Array) -> Array:
	var out: Array = []
	for item in src:
		if item is RockHitTrace:
			out.append((item as RockHitTrace).duplicate_trace())
	return out


static func _copy_moves(src: Array) -> Array:
	var out: Array = []
	for item in src:
		if item is GravityMoveTrace:
			out.append((item as GravityMoveTrace).duplicate_trace())
	return out


static func _copy_refills(src: Array) -> Array:
	var out: Array = []
	for item in src:
		if item is RefillTrace:
			out.append((item as RefillTrace).duplicate_trace())
	return out
