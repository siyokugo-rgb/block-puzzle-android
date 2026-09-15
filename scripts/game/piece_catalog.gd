class_name PieceCatalog
extends RefCounted

## Phase 1-B: immutable list of valid PieceShape entries for generation.
## Not a production catalog — callers supply the shapes (tests use small sets).

var _pieces: Array[PieceShape] = []
var _valid: bool = false
var _validation_error: String = "uninitialized"


## Build from an array of PieceShape. Rejects empty / null / invalid entries.
## Stores independent copies so later mutation of the input array cannot corrupt the catalog.
static func create(pieces: Array) -> PieceCatalog:
	var catalog := PieceCatalog.new()
	catalog._build(pieces)
	return catalog


func is_valid() -> bool:
	return _valid


func validation_error() -> String:
	return _validation_error


func size() -> int:
	return _pieces.size() if _valid else 0


## Defensive copy of the piece at index, or null if out of range / invalid catalog.
func piece_at(index: int) -> PieceShape:
	if not _valid or index < 0 or index >= _pieces.size():
		return null
	return _copy_piece(_pieces[index])


## Defensive copies of all pieces (empty when invalid).
func pieces() -> Array[PieceShape]:
	var out: Array[PieceShape] = []
	if not _valid:
		return out
	for piece in _pieces:
		out.append(_copy_piece(piece))
	return out


func _build(pieces: Array) -> void:
	_pieces.clear()
	_valid = false
	_validation_error = ""

	if pieces.is_empty():
		_validation_error = "catalog must contain at least one piece"
		return

	var stored: Array[PieceShape] = []
	for item in pieces:
		if item == null:
			_validation_error = "catalog rejects null piece"
			return
		if not (item is PieceShape):
			_validation_error = "catalog entries must be PieceShape"
			return
		var piece: PieceShape = item
		if not piece.is_valid():
			_validation_error = "catalog rejects invalid piece"
			return
		stored.append(_copy_piece(piece))

	_pieces = stored
	_valid = true


static func _copy_piece(piece: PieceShape) -> PieceShape:
	return PieceShape.create(piece.cells())
