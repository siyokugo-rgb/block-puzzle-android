class_name PieceTray
extends RefCounted

## Phase 1-B: fixed 3-slot piece tray (data only).
## No automatic refill — Session lifecycle owns refill in a later phase.

const SLOT_COUNT := 3

var _slots: Array = [] # Array length SLOT_COUNT; PieceShape or null
var _valid: bool = false
var _validation_error: String = "uninitialized"


## Build a tray from exactly three valid PieceShape instances (stored as copies).
static func create(pieces: Array) -> PieceTray:
	var tray := PieceTray.new()
	tray._build(pieces)
	return tray


func is_valid() -> bool:
	return _valid


func validation_error() -> String:
	return _validation_error


func slot_count() -> int:
	return SLOT_COUNT


func piece_at(index: int) -> PieceShape:
	if not _valid or not _index_ok(index):
		return null
	var piece: Variant = _slots[index]
	if piece == null:
		return null
	return PieceCatalog._copy_piece(piece)


func has_piece(index: int) -> bool:
	if not _valid or not _index_ok(index):
		return false
	return _slots[index] != null


## Remove the piece at index. Returns false for invalid index / already empty.
## Failed calls leave every slot unchanged.
func consume(index: int) -> bool:
	if not _valid or not _index_ok(index):
		return false
	if _slots[index] == null:
		return false
	_slots[index] = null
	return true


func remaining_count() -> int:
	if not _valid:
		return 0
	var count := 0
	for i in range(SLOT_COUNT):
		if _slots[i] != null:
			count += 1
	return count


func is_empty() -> bool:
	return remaining_count() == 0


func _index_ok(index: int) -> bool:
	return index >= 0 and index < SLOT_COUNT


func _build(pieces: Array) -> void:
	_slots.clear()
	_valid = false
	_validation_error = ""

	if pieces.size() != SLOT_COUNT:
		_validation_error = "tray requires exactly %d pieces" % SLOT_COUNT
		_slots.resize(SLOT_COUNT)
		return

	var stored: Array = []
	stored.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		var item: Variant = pieces[i]
		if item == null:
			_validation_error = "tray rejects null piece"
			_slots.resize(SLOT_COUNT)
			return
		if not (item is PieceShape):
			_validation_error = "tray entries must be PieceShape"
			_slots.resize(SLOT_COUNT)
			return
		var piece: PieceShape = item
		if not piece.is_valid():
			_validation_error = "tray rejects invalid piece"
			_slots.resize(SLOT_COUNT)
			return
		stored[i] = PieceCatalog._copy_piece(piece)

	_slots = stored
	_valid = true
