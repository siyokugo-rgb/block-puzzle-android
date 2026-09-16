class_name MatchResolver
extends RefCounted

## Phase R-C: orthogonal ≥3 match detection and simultaneous clear.
## Match geometry SoT — not PuzzleBoard. No gravity / refill / cascade / score.

const MATCH_MIN_LENGTH := 3


## Read-only detect. Never mutates the board.
static func detect(board: PuzzleBoard) -> MatchResult:
	if board == null or not board.is_valid():
		return MatchResult.invalid()
	var matched: Array[Vector2i] = []
	_collect_horizontal(board, matched)
	_collect_vertical(board, matched)
	return MatchResult.from_cells(matched)


## Detect current matches on board, then clear their union in one pass.
## Re-detects from the live board (no stale MatchResult input).
static func clear_current_matches(board: PuzzleBoard) -> MatchResult:
	if board == null or not board.is_valid():
		return MatchResult.invalid()
	var result := detect(board)
	if not result.is_valid():
		return result
	if not result.has_matches():
		return result
	for cell in result.matched_cells_snapshot():
		if not board.in_bounds(cell):
			# Detected position should always be in-bounds; fail closed.
			return MatchResult.invalid()
		if not board.clear_orb(cell):
			return MatchResult.invalid()
	return result


static func _collect_horizontal(board: PuzzleBoard, out: Array[Vector2i]) -> void:
	var w := board.width()
	var h := board.height()
	for y in range(h):
		var run_id := -1
		var run_start := 0
		var run_len := 0
		for x in range(w):
			var id := board.orb_at(Vector2i(x, y))
			if id >= 0 and id == run_id:
				run_len += 1
			else:
				_flush_run_horizontal(out, y, run_start, run_len, run_id)
				run_id = id
				run_start = x
				run_len = 1 if id >= 0 else 0
		_flush_run_horizontal(out, y, run_start, run_len, run_id)


static func _flush_run_horizontal(
	out: Array[Vector2i],
	y: int,
	start_x: int,
	run_len: int,
	run_id: int
) -> void:
	if run_id < 0 or run_len < MATCH_MIN_LENGTH:
		return
	for x in range(start_x, start_x + run_len):
		out.append(Vector2i(x, y))


static func _collect_vertical(board: PuzzleBoard, out: Array[Vector2i]) -> void:
	var w := board.width()
	var h := board.height()
	for x in range(w):
		var run_id := -1
		var run_start := 0
		var run_len := 0
		for y in range(h):
			var id := board.orb_at(Vector2i(x, y))
			if id >= 0 and id == run_id:
				run_len += 1
			else:
				_flush_run_vertical(out, x, run_start, run_len, run_id)
				run_id = id
				run_start = y
				run_len = 1 if id >= 0 else 0
		_flush_run_vertical(out, x, run_start, run_len, run_id)


static func _flush_run_vertical(
	out: Array[Vector2i],
	x: int,
	start_y: int,
	run_len: int,
	run_id: int
) -> void:
	if run_id < 0 or run_len < MATCH_MIN_LENGTH:
		return
	for y in range(start_y, start_y + run_len):
		out.append(Vector2i(x, y))
