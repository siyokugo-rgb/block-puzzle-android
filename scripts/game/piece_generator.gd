class_name PieceGenerator
extends RefCounted

## Phase 1-B: uniform random piece supply from a PieceCatalog.
## Uses an injected RandomNumberGenerator (seedable). Not production weighting.

var _catalog: PieceCatalog
var _rng: RandomNumberGenerator
var _valid: bool = false
var _validation_error: String = "uninitialized"


static func create(catalog: PieceCatalog, rng: RandomNumberGenerator = null) -> PieceGenerator:
	var generator := PieceGenerator.new()
	generator._build(catalog, rng)
	return generator


func is_valid() -> bool:
	return _valid


func validation_error() -> String:
	return _validation_error


func set_seed(seed_value: int) -> void:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value


## Returns a catalog piece copy, or null if generator/catalog is invalid.
func generate_piece() -> PieceShape:
	if not _valid:
		return null
	var index := _rng.randi() % _catalog.size()
	return _catalog.piece_at(index)


## Returns exactly three piece copies, or an empty array on failure.
func generate_three() -> Array[PieceShape]:
	var out: Array[PieceShape] = []
	if not _valid:
		return out
	for _i in range(3):
		var piece := generate_piece()
		if piece == null or not piece.is_valid():
			out.clear()
			return out
		out.append(piece)
	return out


func _build(catalog: PieceCatalog, rng: RandomNumberGenerator) -> void:
	_catalog = null
	_rng = null
	_valid = false
	_validation_error = ""

	if catalog == null or not catalog.is_valid():
		_validation_error = "generator requires a valid catalog"
		return

	_catalog = catalog
	_rng = rng if rng != null else RandomNumberGenerator.new()
	_valid = true
