class_name GravityResolver
extends RefCounted

## Phase R-D / R-G: per-column downward compact with ROCK vertical barriers.
## Living ROCK cells split each column into segments; orbs never cross ROCK.
## Preserves relative orb order within each segment. No cross-column moves.


## Compact orbs toward the bottom of each ROCK-bounded segment.
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
	var barriers: Array[int] = []
	for y in range(h):
		if board.is_rock(Vector2i(x, y)):
			barriers.append(y)
	# Sentinels: segment bounds are exclusive rock rows / board edges.
	var edges: Array[int] = [-1]
	edges.append_array(barriers)
	edges.append(h)
	for i in range(edges.size() - 1):
		var top: int = edges[i] + 1
		var bottom: int = edges[i + 1] - 1
		if top > bottom:
			continue
		if not _compact_segment(board, x, top, bottom):
			return false
	return true


## Compact orbs in inclusive [top, bottom] toward bottom. ROCK must not be inside.
static func _compact_segment(board: PuzzleBoard, x: int, top: int, bottom: int) -> bool:
	var write_y := bottom
	for y in range(bottom, top - 1, -1):
		var pos := Vector2i(x, y)
		if board.is_rock(pos):
			return false
		var id := board.orb_at(pos)
		if id < 0:
			continue
		if y != write_y:
			if not board.clear_orb(pos):
				return false
			if not board.set_orb(Vector2i(x, write_y), id):
				return false
		write_y -= 1
	for y in range(top, write_y + 1):
		var clear_pos := Vector2i(x, y)
		if board.has_orb(clear_pos):
			if not board.clear_orb(clear_pos):
				return false
	return true
