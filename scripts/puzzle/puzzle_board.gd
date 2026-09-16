class_name PuzzleBoard
extends RefCounted

## Phase R-A: width×height orb grid (no pixels, no cascade, no obstacles).
## Coordinates: x right, y down, origin top-left (0,0).

var _width: int = 0
var _height: int = 0
var _cells: Array = [] # Array of Array[PuzzleCell] rows
var _valid: bool = false
var _validation_error: String = "uninitialized"


static func create(width: int, height: int) -> PuzzleBoard:
	var board := PuzzleBoard.new()
	board._build(width, height)
	return board


func is_valid() -> bool:
	return _valid


func validation_error() -> String:
	return _validation_error


func width() -> int:
	return _width


func height() -> int:
	return _height


func in_bounds(pos: Vector2i) -> bool:
	if not _valid:
		return false
	return pos.x >= 0 and pos.y >= 0 and pos.x < _width and pos.y < _height


func is_empty(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return false
	return (_cells[pos.y][pos.x] as PuzzleCell).is_empty()


func has_orb(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return false
	return (_cells[pos.y][pos.x] as PuzzleCell).has_orb()


## OrbType.Id or -1 if empty / OOB / invalid board.
func orb_at(pos: Vector2i) -> int:
	if not in_bounds(pos):
		return -1
	return (_cells[pos.y][pos.x] as PuzzleCell).orb_id()


func set_orb(pos: Vector2i, orb_id: int) -> bool:
	if not in_bounds(pos):
		return false
	return (_cells[pos.y][pos.x] as PuzzleCell).set_orb(orb_id)


func clear_orb(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return false
	(_cells[pos.y][pos.x] as PuzzleCell).clear_orb()
	return true


## Orthogonal 4-dir adjacent swap only. Failure leaves board unchanged.
func swap(a: Vector2i, b: Vector2i) -> bool:
	if not _valid:
		return false
	if a == b:
		return false
	if not in_bounds(a) or not in_bounds(b):
		return false
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	# Exactly one step orthogonal (Manhattan 1); rejects diagonal and farther.
	if dx + dy != 1:
		return false
	var cell_a: PuzzleCell = _cells[a.y][a.x]
	var cell_b: PuzzleCell = _cells[b.y][b.x]
	var id_a := cell_a.orb_id()
	var id_b := cell_b.orb_id()
	# R-A: both cells must hold orbs to swap.
	if id_a < 0 or id_b < 0:
		return false
	cell_a.set_orb(id_b)
	cell_b.set_orb(id_a)
	return true


## Defensive row-major snapshot: Array[Array[int]] of orb ids (-1 empty).
## Mutating the returned arrays cannot affect board internals.
func snapshot_orb_ids() -> Array:
	var out: Array = []
	if not _valid:
		return out
	for y in range(_height):
		var row: Array = []
		for x in range(_width):
			row.append((_cells[y][x] as PuzzleCell).orb_id())
		out.append(row)
	return out


func _build(width: int, height: int) -> void:
	_width = 0
	_height = 0
	_cells.clear()
	_valid = false
	_validation_error = ""
	if width <= 0 or height <= 0:
		_validation_error = "board width and height must be positive"
		return
	_width = width
	_height = height
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(PuzzleCell.empty())
		_cells.append(row)
	_valid = true
