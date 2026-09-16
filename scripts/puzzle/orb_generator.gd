class_name OrbGenerator
extends RefCounted

## Phase R-A: seeded orb supply for DEV OrbType catalog.
## Uses injected RandomNumberGenerator; never global randi().
## Bounded pick via randi_range — no `randi() % n` modulo bias path.

var _rng: RandomNumberGenerator
var _valid: bool = false
var _validation_error: String = "uninitialized"


static func create(rng: RandomNumberGenerator = null) -> OrbGenerator:
	var generator := OrbGenerator.new()
	generator._build(rng)
	return generator


func is_valid() -> bool:
	return _valid


func validation_error() -> String:
	return _validation_error


func set_seed(seed_value: int) -> void:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value


## Uniform pick among DEV OrbType ids using randi_range(0, count-1).
func generate_orb() -> int:
	if not _valid:
		return -1
	var index := _rng.randi_range(0, OrbType.DEV_TYPE_COUNT - 1)
	return index


## Pick uniformly among a non-empty candidate id list (defensive copy of choice).
## Returns -1 if generator invalid or candidates empty.
func generate_from_candidates(candidates: Array) -> int:
	if not _valid:
		return -1
	if candidates.is_empty():
		return -1
	var index := _rng.randi_range(0, candidates.size() - 1)
	var picked: Variant = candidates[index]
	if typeof(picked) != TYPE_INT:
		return -1
	var id: int = picked
	if not OrbType.is_dev_id(id):
		return -1
	return id


## Match-stable initial fill for an existing empty valid board.
## Scan order (RNG consumption order): y outer 0..h-1, x inner 0..w-1 (row-major).
## At each cell, exclude types that would complete a ≥3 run with the two cells
## immediately left and/or the two cells immediately above; then pick among rest.
## Fail-closed if any cell has zero legal candidates (no unbounded whole-board retry).
## Does not run cascade and does not award score.
func fill_match_stable(board: PuzzleBoard) -> bool:
	if not _valid:
		return false
	if board == null or not board.is_valid():
		return false
	var w := board.width()
	var h := board.height()
	for y in range(h):
		for x in range(w):
			var candidates := _stable_candidates(board, Vector2i(x, y))
			if candidates.is_empty():
				return false
			var picked := generate_from_candidates(candidates)
			if picked < 0:
				return false
			if not board.set_orb(Vector2i(x, y), picked):
				return false
	return true


## Create a new board and fill it match-stable. Null on failure.
static func create_match_stable_board(
	width: int,
	height: int,
	seed_value: int
) -> PuzzleBoard:
	var board := PuzzleBoard.create(width, height)
	if not board.is_valid():
		return null
	var generator := OrbGenerator.create()
	generator.set_seed(seed_value)
	if not generator.fill_match_stable(board):
		return null
	return board


func _stable_candidates(board: PuzzleBoard, pos: Vector2i) -> Array:
	var blocked: Dictionary = {}
	# Left two same → exclude that type.
	if pos.x >= 2:
		var a := board.orb_at(Vector2i(pos.x - 1, pos.y))
		var b := board.orb_at(Vector2i(pos.x - 2, pos.y))
		if a >= 0 and a == b:
			blocked[a] = true
	# Upper two same → exclude that type.
	if pos.y >= 2:
		var a := board.orb_at(Vector2i(pos.x, pos.y - 1))
		var b := board.orb_at(Vector2i(pos.x, pos.y - 2))
		if a >= 0 and a == b:
			blocked[a] = true
	var out: Array = []
	for id in OrbType.all_dev_ids():
		if not blocked.has(id):
			out.append(id)
	return out


func _build(rng: RandomNumberGenerator) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	_valid = true
	_validation_error = ""
