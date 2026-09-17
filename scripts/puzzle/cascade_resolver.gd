class_name CascadeResolver
extends RefCounted

## Phase R-D / R-G: match → adjacent ROCK break → clear → gravity → refill.
## Uses MatchResolver + GravityResolver + existing OrbGenerator instance.
## No PuzzleSession / Timer / Score / UI.

const MAX_CASCADE_STEPS := 128


## Resolve until match-stable or fail-closed.
## Optional max_steps is an internal safety seam (default MAX_CASCADE_STEPS).
## Invalid inputs → ERROR result, no board mutation, no RNG consumption.
static func resolve(
	board: PuzzleBoard,
	generator: OrbGenerator,
	max_steps: int = MAX_CASCADE_STEPS
) -> CascadeResult:
	if board == null or not board.is_valid():
		return CascadeResult.invalid()
	if generator == null or not generator.is_valid():
		return CascadeResult.invalid()
	if max_steps < 0:
		return CascadeResult.invalid()

	var cleared_per_step: Array[int] = []
	var rocks_per_step: Array[int] = []
	var steps := 0

	while true:
		var match_result := MatchResolver.detect(board)
		if not match_result.is_valid():
			return CascadeResult.invalid()
		if not match_result.has_matches():
			return CascadeResult.stable_success(steps, cleared_per_step, rocks_per_step)

		# Already completed max_steps resolve cycles and matches remain → guard.
		if steps >= max_steps:
			return CascadeResult.guard_exceeded(steps, cleared_per_step, rocks_per_step)

		var matched := match_result.matched_cells_snapshot()
		var rocks := collect_adjacent_rocks(board, matched)
		# 1-hit ROCK destruction (simultaneous), before orb clear so gravity sees empties.
		for rock_pos in rocks:
			if not board.clear_obstacle(rock_pos):
				return CascadeResult.invalid()
		rocks_per_step.append(rocks.size())

		var cleared := MatchResolver.clear_current_matches(board)
		if not cleared.is_valid() or not cleared.has_matches():
			return CascadeResult.invalid()
		cleared_per_step.append(cleared.matched_cell_count())

		if not GravityResolver.apply(board):
			return CascadeResult.invalid()

		if not _refill_empties(board, generator):
			return CascadeResult.invalid()

		steps += 1

	# Unreachable: loop always returns.
	return CascadeResult.invalid()


## Orthogonal adjacency only. Same ROCK listed once even if multiple matches touch it.
static func collect_adjacent_rocks(board: PuzzleBoard, matched: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if board == null or not board.is_valid():
		return out
	var seen: Dictionary = {}
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for item in matched:
		if typeof(item) != TYPE_VECTOR2I:
			continue
		var cell: Vector2i = item
		for d in dirs:
			var n: Vector2i = cell + d
			if not board.is_rock(n):
				continue
			var key := "%d,%d" % [n.x, n.y]
			if seen.has(key):
				continue
			seen[key] = true
			out.append(n)
	return out


## Refill order (FIXED): x outer left→right, y inner top→bottom.
## ROCK cells are not empty (is_empty false) → skipped, no RNG consumption.
static func _refill_empties(board: PuzzleBoard, generator: OrbGenerator) -> bool:
	var w := board.width()
	var h := board.height()
	for x in range(w):
		for y in range(h):
			var pos := Vector2i(x, y)
			if not board.is_empty(pos):
				continue
			var orb_id := generator.generate_orb()
			if orb_id < 0:
				return false
			if not board.set_orb(pos, orb_id):
				return false
	return true
