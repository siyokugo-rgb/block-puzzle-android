class_name PuzzleBoard
extends RefCounted

## Phase R-A / R-G: width×height grid with orbs + ROCK obstacles.
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


## Empty = no orb AND no obstacle.
func is_empty(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return false
	return (_cells[pos.y][pos.x] as PuzzleCell).is_empty()


func has_orb(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return false
	return (_cells[pos.y][pos.x] as PuzzleCell).has_orb()


func has_obstacle(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return false
	return (_cells[pos.y][pos.x] as PuzzleCell).has_obstacle()


func is_rock(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return false
	return (_cells[pos.y][pos.x] as PuzzleCell).is_rock()


## OrbType.Id or -1 if empty orb / OOB / invalid board.
func orb_at(pos: Vector2i) -> int:
	if not in_bounds(pos):
		return -1
	return (_cells[pos.y][pos.x] as PuzzleCell).orb_id()


## ObstacleType.Id or NONE if OOB / invalid.
func obstacle_at(pos: Vector2i) -> int:
	if not in_bounds(pos):
		return ObstacleType.Id.NONE
	return (_cells[pos.y][pos.x] as PuzzleCell).obstacle_id()


## Fails on OOB, invalid orb id, or ROCK cell.
func set_orb(pos: Vector2i, orb_id: int) -> bool:
	if not in_bounds(pos):
		return false
	return (_cells[pos.y][pos.x] as PuzzleCell).set_orb(orb_id)


func clear_orb(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return false
	(_cells[pos.y][pos.x] as PuzzleCell).clear_orb()
	return true


## Places ROCK at HP=2 and clears any orb. Fails OOB / invalid / already ROCK.
func set_rock(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return false
	return (_cells[pos.y][pos.x] as PuzzleCell).set_rock()


func clear_obstacle(pos: Vector2i) -> bool:
	if not in_bounds(pos):
		return false
	(_cells[pos.y][pos.x] as PuzzleCell).clear_obstacle()
	return true


## ROCK HP at pos (1 or 2), or 0 if not ROCK / OOB / invalid.
func rock_hp_at(pos: Vector2i) -> int:
	if not in_bounds(pos):
		return 0
	var cell: PuzzleCell = _cells[pos.y][pos.x]
	if not cell.is_rock():
		return 0
	return cell.obstacle_hp()


## One cascade-step hit. Returns remaining HP (1 or 0), or -1 if not ROCK / OOB / invalid.
func damage_rock(pos: Vector2i) -> int:
	if not in_bounds(pos):
		return -1
	return (_cells[pos.y][pos.x] as PuzzleCell).damage_rock()


## Place ROCK with explicit HP (1 or 2). Clears any orb. Destination must be empty.
## Does not use set_rock() — preserves HP for gravity moves (no silent HP=2 reset).
func place_rock_with_hp(pos: Vector2i, hp: int) -> bool:
	if not in_bounds(pos):
		return false
	if hp != 1 and hp != 2:
		return false
	var cell: PuzzleCell = _cells[pos.y][pos.x]
	if not cell.is_empty():
		return false
	return cell.place_rock_with_hp(hp)


## Move orb or ROCK from→to. Destination must be empty. Preserves ROCK HP.
## Failure leaves board unchanged. Same-cell is a no-op success.
func move_occupant(from: Vector2i, to: Vector2i) -> bool:
	if not in_bounds(from) or not in_bounds(to):
		return false
	if from == to:
		return true
	var src: PuzzleCell = _cells[from.y][from.x]
	var dst: PuzzleCell = _cells[to.y][to.x]
	if src.is_empty():
		return false
	if not dst.is_empty():
		return false
	# Capture then clear then place (atomic for this board).
	var had_rock := src.is_rock()
	var hp := src.obstacle_hp()
	var orb := src.orb_id()
	if had_rock:
		src.clear_obstacle()
		if not dst.place_rock_with_hp(hp):
			# Restore source on failure.
			src.place_rock_with_hp(hp)
			return false
		return true
	if orb < 0:
		return false
	src.clear_orb()
	if not dst.set_orb(orb):
		src.set_orb(orb)
		return false
	return true


## Count of ROCK cells currently on the board (HP1 and HP2 both count).
func rock_count() -> int:
	if not _valid:
		return 0
	var n := 0
	for y in range(_height):
		for x in range(_width):
			if (_cells[y][x] as PuzzleCell).is_rock():
				n += 1
	return n


## Orthogonal 4-dir adjacent swap only. Failure leaves board unchanged.
## ROCK / empty cells cannot participate (swap SoT for impassable ROCK).
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
	if cell_a.has_obstacle() or cell_b.has_obstacle():
		return false
	var id_a := cell_a.orb_id()
	var id_b := cell_b.orb_id()
	# Both cells must hold orbs to swap.
	if id_a < 0 or id_b < 0:
		return false
	cell_a.set_orb(id_b)
	cell_b.set_orb(id_a)
	return true


## Defensive row-major snapshot: Array[Array[int]] of orb ids (-1 empty).
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


## Defensive row-major snapshot: Array[Array[int]] of ObstacleType.Id.
func snapshot_obstacle_types() -> Array:
	var out: Array = []
	if not _valid:
		return out
	for y in range(_height):
		var row: Array = []
		for x in range(_width):
			row.append((_cells[y][x] as PuzzleCell).obstacle_id())
		out.append(row)
	return out


## Defensive row-major snapshot: Array[Array[int]] of obstacle HP (0 if none).
func snapshot_obstacle_hp() -> Array:
	var out: Array = []
	if not _valid:
		return out
	for y in range(_height):
		var row: Array = []
		for x in range(_width):
			row.append((_cells[y][x] as PuzzleCell).obstacle_hp())
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
