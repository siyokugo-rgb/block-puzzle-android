class_name CascadeResolver
extends RefCounted

## Phase R-D / R-G: match → adjacent ROCK damage → clear → gravity → refill.
## Records CascadeStepTrace for presentation. No PuzzleSession / Timer / Score / UI.
##
## ROCK damage unit: at most 1 hit per ROCK per cascade step.

const MAX_CASCADE_STEPS := 128


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
	var rocks_destroyed_per_step: Array[int] = []
	var rock_hits_per_step: Array[int] = []
	var step_traces: Array = []
	var steps := 0

	while true:
		var match_result := MatchResolver.detect(board)
		if not match_result.is_valid():
			return CascadeResult.invalid()
		if not match_result.has_matches():
			return CascadeResult.stable_success(
				steps, cleared_per_step, rocks_destroyed_per_step, rock_hits_per_step, step_traces
			)

		if steps >= max_steps:
			return CascadeResult.guard_exceeded(
				steps, cleared_per_step, rocks_destroyed_per_step, rock_hits_per_step, step_traces
			)

		var matched := match_result.matched_cells_snapshot()
		var rocks := collect_adjacent_rocks(board, matched)
		var hit_stats := apply_rock_hits(board, rocks)
		if hit_stats.get("ok", false) != true:
			return CascadeResult.invalid()
		var hit_traces: Array = hit_stats.get("hits_detail", [])
		rock_hits_per_step.append(int(hit_stats.get("hits", 0)))
		rocks_destroyed_per_step.append(int(hit_stats.get("destroyed", 0)))

		var cleared := MatchResolver.clear_current_matches(board)
		if not cleared.is_valid() or not cleared.has_matches():
			return CascadeResult.invalid()
		cleared_per_step.append(cleared.matched_cell_count())

		var grav := GravityResolver.apply_traced(board)
		if not bool(grav.get("ok", false)):
			return CascadeResult.invalid()
		var gravity_moves: Array = grav.get("moves", [])

		var refill_stats := _refill_empties_traced(board, generator)
		if not bool(refill_stats.get("ok", false)):
			return CascadeResult.invalid()
		var refill_traces: Array = refill_stats.get("refills", [])

		step_traces.append(
			CascadeStepTrace.create(steps, matched, hit_traces, gravity_moves, refill_traces)
		)
		steps += 1

	return CascadeResult.invalid()


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


## Returns {ok, hits, destroyed, hits_detail: Array[RockHitTrace]}.
static func apply_rock_hits(board: PuzzleBoard, rocks: Array) -> Dictionary:
	var out := {"ok": false, "hits": 0, "destroyed": 0, "hits_detail": []}
	if board == null or not board.is_valid():
		return out
	var hits := 0
	var destroyed := 0
	var details: Array = []
	for item in rocks:
		if typeof(item) != TYPE_VECTOR2I:
			return out
		var pos: Vector2i = item
		var hp_before := board.rock_hp_at(pos)
		if hp_before <= 0:
			return out
		var remaining := board.damage_rock(pos)
		if remaining < 0:
			return out
		hits += 1
		var was_destroyed := remaining == 0
		if was_destroyed:
			destroyed += 1
		details.append(RockHitTrace.create(pos, hp_before, remaining, was_destroyed))
	out["ok"] = true
	out["hits"] = hits
	out["destroyed"] = destroyed
	out["hits_detail"] = details
	return out


static func _refill_empties(board: PuzzleBoard, generator: OrbGenerator) -> bool:
	return bool(_refill_empties_traced(board, generator).get("ok", false))


static func _refill_empties_traced(board: PuzzleBoard, generator: OrbGenerator) -> Dictionary:
	var out := {"ok": false, "refills": []}
	var refills: Array = []
	var w := board.width()
	var h := board.height()
	for x in range(w):
		for y in range(h):
			var pos := Vector2i(x, y)
			if not board.is_empty(pos):
				continue
			var orb_id := generator.generate_orb()
			if orb_id < 0:
				return out
			if not board.set_orb(pos, orb_id):
				return out
			refills.append(RefillTrace.create(pos, orb_id))
	out["ok"] = true
	out["refills"] = refills
	return out
