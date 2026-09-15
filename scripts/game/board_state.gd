class_name BoardState
extends RefCounted

## Phase 1-A: pure logical board (no UI / pixels).
## Coordinates: x left→right, y top→bottom, origin top-left (0, 0).
## Occupied representation: bool grid, true = occupied.

var _width: int = 0
var _height: int = 0
var _occupied: Array = [] # Array of PackedByteArray rows; 0 empty, 1 occupied
var _valid: bool = false
var _validation_error: String = "uninitialized"


static func create(width: int, height: int) -> BoardState:
	var board := BoardState.new()
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


func is_occupied(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return false
	return _occupied[pos.y][pos.x] == 1


func is_empty(pos: Vector2i) -> bool:
	return in_bounds(pos) and _occupied[pos.y][pos.x] == 0


## Snapshot of occupied cells for tests / debugging (board cell coords).
func occupied_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _valid:
		return out
	for y in range(_height):
		for x in range(_width):
			if _occupied[y][x] == 1:
				out.append(Vector2i(x, y))
	return out


func occupied_count() -> int:
	return occupied_cells().size()


func can_place(piece: PieceShape, origin: Vector2i) -> bool:
	if not _valid:
		return false
	if piece == null or not piece.is_valid():
		return false
	for offset in piece.cells():
		var pos: Vector2i = origin + offset
		if not in_bounds(pos):
			return false
		if _occupied[pos.y][pos.x] == 1:
			return false
	return true


## Atomic placement: validate all cells, then commit. On failure board is unchanged.
func place(piece: PieceShape, origin: Vector2i) -> bool:
	if not can_place(piece, origin):
		return false
	for offset in piece.cells():
		var pos: Vector2i = origin + offset
		_occupied[pos.y][pos.x] = 1
	return true


## Detect fully occupied rows and columns from the current board state.
## Returns sorted unique row/column indices (no clearing).
func detect_completed_lines() -> Dictionary:
	var rows: Array[int] = []
	var cols: Array[int] = []
	if not _valid:
		return {"rows": rows, "columns": cols}

	for y in range(_height):
		var full := true
		for x in range(_width):
			if _occupied[y][x] == 0:
				full = false
				break
		if full:
			rows.append(y)

	for x in range(_width):
		var full := true
		for y in range(_height):
			if _occupied[y][x] == 0:
				full = false
				break
		if full:
			cols.append(x)

	return {"rows": rows, "columns": cols}


## Detect all completed rows/columns from the post-placement board, then clear
## the union of their cells once (intersection counted once).
func clear_completed_lines() -> LineClearResult:
	var result := LineClearResult.new()
	if not _valid:
		return result

	var detected := detect_completed_lines()
	var rows: Array[int] = detected["rows"]
	var cols: Array[int] = detected["columns"]
	if rows.is_empty() and cols.is_empty():
		return result

	var cleared: Dictionary = {}
	for y in rows:
		for x in range(_width):
			var key := "%d,%d" % [x, y]
			cleared[key] = Vector2i(x, y)
	for x in cols:
		for y in range(_height):
			var key := "%d,%d" % [x, y]
			cleared[key] = Vector2i(x, y)

	for key in cleared.keys():
		var pos: Vector2i = cleared[key]
		_occupied[pos.y][pos.x] = 0

	result.cleared_rows = rows.duplicate()
	result.cleared_columns = cols.duplicate()
	result.cleared_cell_count = cleared.size()
	return result


func _build(width: int, height: int) -> void:
	_width = 0
	_height = 0
	_occupied.clear()
	_valid = false
	_validation_error = ""

	if width <= 0 or height <= 0:
		_validation_error = "board width and height must be positive"
		return

	_width = width
	_height = height
	_occupied.resize(height)
	for y in range(height):
		var row := PackedByteArray()
		row.resize(width)
		row.fill(0)
		_occupied[y] = row
	_valid = true
