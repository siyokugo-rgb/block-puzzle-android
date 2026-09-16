class_name GravityResolver
extends RefCounted

## Phase R-D: per-column downward compact (y=0 top, y=height-1 bottom).
## Preserves relative orb order within each column. No cross-column moves.
## Obstacles / ROCK segment gravity are out of scope.


## Compact orbs toward the bottom of each column.
## Returns true on success. Null / invalid board → false, no mutation.
static func apply(board: PuzzleBoard) -> bool:
	if board == null or not board.is_valid():
		return false
	var w := board.width()
	var h := board.height()
	for x in range(w):
		if not _compact_column(board, x, h):
			return false
	return true


static func _compact_column(board: PuzzleBoard, x: int, h: int) -> bool:
	# Bottom → top scan with write_y: place each orb at the next free bottom slot.
	var write_y := h - 1
	for y in range(h - 1, -1, -1):
		var id := board.orb_at(Vector2i(x, y))
		if id < 0:
			continue
		if y != write_y:
			# Move orb down. write_y is always empty or equal to y (already scanned).
			if not board.clear_orb(Vector2i(x, y)):
				return false
			if not board.set_orb(Vector2i(x, write_y), id):
				return false
		write_y -= 1
	# Anything still above the last written slot must be empty.
	for y in range(write_y + 1):
		if board.has_orb(Vector2i(x, y)):
			if not board.clear_orb(Vector2i(x, y)):
				return false
	return true
