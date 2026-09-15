class_name PieceShape
extends RefCounted

## Phase 1-A: pure cell-offset piece shape (no board ownership, no rotation).
## Cells are offsets from a placement origin in board cell coordinates.
## Coordinate system matches BoardState: x rightward, y downward.

var _cells: Array[Vector2i] = []
var _valid: bool = false
var _validation_error: String = "uninitialized"


## Build a piece from origin-relative cell offsets.
## Invalid input yields an invalid PieceShape (is_valid() == false); never silently accepted.
static func create(offsets: Array) -> PieceShape:
	var piece := PieceShape.new()
	piece._build(offsets)
	return piece


static func create_single_cell() -> PieceShape:
	return create([Vector2i(0, 0)])


func is_valid() -> bool:
	return _valid


func validation_error() -> String:
	return _validation_error


## Sorted unique offsets; empty when invalid.
func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _valid:
		return out
	out.assign(_cells)
	return out


func cell_count() -> int:
	return _cells.size() if _valid else 0


func _build(offsets: Array) -> void:
	_cells.clear()
	_valid = false
	_validation_error = ""

	if offsets.is_empty():
		_validation_error = "piece must contain at least one cell"
		return

	var seen: Dictionary = {}
	var normalized: Array[Vector2i] = []
	for item in offsets:
		if typeof(item) != TYPE_VECTOR2I:
			_validation_error = "piece offsets must be Vector2i"
			return
		var cell: Vector2i = item
		var key := "%d,%d" % [cell.x, cell.y]
		if seen.has(key):
			_validation_error = "duplicate cell offset: %s" % key
			return
		seen[key] = true
		normalized.append(cell)

	normalized.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	_cells = normalized
	_valid = true
	_validation_error = ""
