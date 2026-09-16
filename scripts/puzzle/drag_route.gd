class_name DragRoute
extends RefCounted

## Phase R-B: route-drag path over a privately bound PuzzleBoard.
## Owns a private board reference from begin(); try_step does not take a board.
## Swap SoT is PuzzleBoard.swap(). No match / resolve / release / timer here.

enum StepResult {
	SWAPPED,
	NO_CHANGE_SAME_CELL,
	REJECTED,
}

var _board: PuzzleBoard = null
var _path: Array[Vector2i] = []
var _start: Vector2i = Vector2i.ZERO
var _current: Vector2i = Vector2i.ZERO
var _swap_count: int = 0
var _active: bool = false


## Bind board + start cell. Returns null on failure. Does not mutate the board.
static func begin(board: PuzzleBoard, start_cell: Vector2i) -> DragRoute:
	if board == null or not board.is_valid():
		return null
	if not board.in_bounds(start_cell):
		return null
	if not board.has_orb(start_cell):
		return null
	var route := DragRoute.new()
	route._board = board
	route._start = start_cell
	route._current = start_cell
	route._path = [start_cell]
	route._swap_count = 0
	route._active = true
	return route


func is_active() -> bool:
	return _active


func start_cell() -> Vector2i:
	return _start


func current_cell() -> Vector2i:
	return _current


func swap_count() -> int:
	return _swap_count


func has_swaps() -> bool:
	return _swap_count > 0


## Defensive copy of the path (includes revisits). External edits do not affect route.
func path_snapshot() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_path)
	return out


## Attempt one step toward next_cell. Commits route state only after Board.swap succeeds.
func try_step(next_cell: Vector2i) -> StepResult:
	if not _active or _board == null or not _board.is_valid():
		return StepResult.REJECTED
	if next_cell == _current:
		return StepResult.NO_CHANGE_SAME_CELL
	if not _board.in_bounds(next_cell):
		return StepResult.REJECTED
	var dx := absi(next_cell.x - _current.x)
	var dy := absi(next_cell.y - _current.y)
	if dx + dy != 1:
		return StepResult.REJECTED
	# PuzzleBoard.swap is SoT (also rejects empty destination / empty current).
	if not _board.swap(_current, next_cell):
		return StepResult.REJECTED
	_path.append(next_cell)
	_current = next_cell
	_swap_count += 1
	return StepResult.SWAPPED
