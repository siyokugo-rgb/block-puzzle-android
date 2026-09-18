class_name GravityResolver
extends RefCounted

## Phase R-D / R-G: per-column downward compact of mixed occupants (Orb + ROCK).
## ROCK is a falling solid token — not a fixed barrier.
## Relative top→bottom order of occupants is preserved. No cross-column moves.


static func apply(board: PuzzleBoard) -> bool:
	return bool(apply_traced(board).get("ok", false))


## Returns {ok: bool, moves: Array[GravityMoveTrace]}.
static func apply_traced(board: PuzzleBoard) -> Dictionary:
	var out := {"ok": false, "moves": []}
	if board == null or not board.is_valid():
		return out
	var moves: Array = []
	var w := board.width()
	var h := board.height()
	for x in range(w):
		if not _compact_column(board, x, h, moves):
			return out
	out["ok"] = true
	out["moves"] = moves
	return out


static func _compact_column(board: PuzzleBoard, x: int, h: int, moves: Array) -> bool:
	# Collect occupants top → bottom (relative order to preserve).
	var tokens: Array = []
	for y in range(h):
		var pos := Vector2i(x, y)
		if board.is_rock(pos):
			tokens.append({
				"from": pos,
				"kind": GravityMoveTrace.Kind.ROCK,
				"orb_id": -1,
				"rock_hp": board.rock_hp_at(pos),
			})
		elif board.has_orb(pos):
			tokens.append({
				"from": pos,
				"kind": GravityMoveTrace.Kind.ORB,
				"orb_id": board.orb_at(pos),
				"rock_hp": 0,
			})
	if tokens.is_empty():
		return true

	# Clear sources first so destination writes cannot collide mid-column.
	for token in tokens:
		var from: Vector2i = token["from"]
		if int(token["kind"]) == GravityMoveTrace.Kind.ROCK:
			if not board.clear_obstacle(from):
				return false
		else:
			if not board.clear_orb(from):
				return false

	var n := tokens.size()
	for i in range(n):
		var dest_y := h - n + i
		var dest := Vector2i(x, dest_y)
		var from: Vector2i = tokens[i]["from"]
		if int(tokens[i]["kind"]) == GravityMoveTrace.Kind.ROCK:
			var hp: int = tokens[i]["rock_hp"]
			if not board.place_rock_with_hp(dest, hp):
				return false
			if from.y != dest_y:
				# Contract: downward only, same column.
				if dest.x != from.x or dest.y <= from.y:
					return false
				moves.append(GravityMoveTrace.create_rock(from, dest, hp))
		else:
			var orb_id: int = tokens[i]["orb_id"]
			if not board.set_orb(dest, orb_id):
				return false
			if from.y != dest_y:
				if dest.x != from.x or dest.y <= from.y:
					return false
				moves.append(GravityMoveTrace.create_orb(from, dest, orb_id))
	return true
