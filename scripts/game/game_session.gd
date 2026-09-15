class_name GameSession
extends RefCounted

## Phase 1-C: UI-free session integrating board, tray, refill, and Game Over.
## Contract: refill only after all 3 tray pieces are consumed.
## Game Over uses PlacementSearch.has_any_placeable_piece after place+clear (+ refill).

enum Status {
	INVALID,
	ACTIVE,
	GAME_OVER,
}

var _status: Status = Status.INVALID
var _validation_error: String = "uninitialized"
var _board: BoardState
var _tray: PieceTray
var _generator: PieceGenerator


static func create(width: int, height: int, generator: PieceGenerator) -> GameSession:
	var session := GameSession.new()
	session._build(width, height, generator)
	return session


func is_valid() -> bool:
	return _status != Status.INVALID


func validation_error() -> String:
	return _validation_error


func status() -> Status:
	return _status


func is_game_over() -> bool:
	return _status == Status.GAME_OVER


func board_width() -> int:
	return _board.width() if _board != null and _board.is_valid() else 0


func board_height() -> int:
	return _board.height() if _board != null and _board.is_valid() else 0


func is_occupied(pos: Vector2i) -> bool:
	if _board == null or not _board.is_valid():
		return false
	return _board.is_occupied(pos)


func occupied_cells() -> Array[Vector2i]:
	if _board == null or not _board.is_valid():
		var empty: Array[Vector2i] = []
		return empty
	return _board.occupied_cells()


func piece_at(slot_index: int) -> PieceShape:
	if _tray == null or not _tray.is_valid():
		return null
	return _tray.piece_at(slot_index)


func has_piece(slot_index: int) -> bool:
	if _tray == null or not _tray.is_valid():
		return false
	return _tray.has_piece(slot_index)


func remaining_piece_count() -> int:
	if _tray == null or not _tray.is_valid():
		return 0
	return _tray.remaining_count()


## Read-only placement query. Never mutates board, tray, status, or generator consumption.
func can_place_from_slot(slot_index: int, origin: Vector2i) -> bool:
	if _status != Status.ACTIVE:
		return false
	if slot_index < 0 or slot_index >= PieceTray.SLOT_COUNT:
		return false
	if _tray == null or not _tray.is_valid() or not _tray.has_piece(slot_index):
		return false
	var piece := _tray.piece_at(slot_index)
	if piece == null or not piece.is_valid():
		return false
	if _board == null or not _board.is_valid():
		return false
	return _board.can_place(piece, origin)


## Atomic move: validate all preconditions, then place → clear → consume → maybe refill → GO check.
func place_from_slot(slot_index: int, origin: Vector2i) -> MoveResult:
	if _status == Status.INVALID:
		return MoveResult.fail(MoveResult.FailureReason.INVALID_SESSION, slot_index, origin)
	if _status == Status.GAME_OVER:
		return MoveResult.fail(MoveResult.FailureReason.GAME_OVER, slot_index, origin)

	if slot_index < 0 or slot_index >= PieceTray.SLOT_COUNT:
		return MoveResult.fail(MoveResult.FailureReason.INVALID_SLOT, slot_index, origin)
	if not _tray.has_piece(slot_index):
		return MoveResult.fail(MoveResult.FailureReason.EMPTY_SLOT, slot_index, origin)

	var piece := _tray.piece_at(slot_index)
	if piece == null or not piece.is_valid():
		return MoveResult.fail(MoveResult.FailureReason.EMPTY_SLOT, slot_index, origin)
	if not _board.can_place(piece, origin):
		return MoveResult.fail(MoveResult.FailureReason.INVALID_PLACEMENT, slot_index, origin)

	# --- commit (preconditions confirmed) ---
	if not _board.place(piece, origin):
		return MoveResult.fail(MoveResult.FailureReason.INTERNAL_ERROR, slot_index, origin)

	var clear_result := _board.clear_completed_lines()
	if not _tray.consume(slot_index):
		# Board already mutated — fail-fast rather than pretend success.
		_status = Status.INVALID
		_validation_error = "internal: tray consume failed after board place"
		return MoveResult.fail(MoveResult.FailureReason.INTERNAL_ERROR, slot_index, origin)

	var refilled := false
	if _tray.is_empty():
		if not _refill_tray():
			_status = Status.INVALID
			_validation_error = "internal: tray refill failed after empty"
			return MoveResult.fail(MoveResult.FailureReason.INTERNAL_ERROR, slot_index, origin)
		refilled = true

	_refresh_game_over_state()

	var result := MoveResult.new()
	result.success = true
	result.failure_reason = MoveResult.FailureReason.NONE
	result.slot_index = slot_index
	result.origin = origin
	result.placed_cell_count = piece.cell_count()
	result.cleared_rows = clear_result.cleared_rows.duplicate()
	result.cleared_columns = clear_result.cleared_columns.duplicate()
	result.cleared_cell_count = clear_result.cleared_cell_count
	result.tray_refilled = refilled
	result.game_over_after_move = (_status == Status.GAME_OVER)
	return result


func _build(width: int, height: int, generator: PieceGenerator) -> void:
	_status = Status.INVALID
	_validation_error = ""
	_board = null
	_tray = null
	_generator = null

	if width <= 0 or height <= 0:
		_validation_error = "session board width and height must be positive"
		return
	if generator == null or not generator.is_valid():
		_validation_error = "session requires a valid generator"
		return

	var board := BoardState.create(width, height)
	if not board.is_valid():
		_validation_error = "session board creation failed"
		return

	_generator = generator
	_board = board
	if not _refill_tray():
		_validation_error = "session initial tray generation failed"
		_board = null
		_tray = null
		return

	_status = Status.ACTIVE
	_refresh_game_over_state()


func _refill_tray() -> bool:
	var pieces := _generator.generate_three()
	if pieces.size() != PieceTray.SLOT_COUNT:
		return false
	for piece in pieces:
		if piece == null or not piece.is_valid():
			return false
	var tray := PieceTray.create(pieces)
	if not tray.is_valid():
		return false
	_tray = tray
	return true


func _refresh_game_over_state() -> void:
	if _status == Status.INVALID:
		return
	if PlacementSearch.has_any_placeable_piece(_board, _tray):
		_status = Status.ACTIVE
	else:
		_status = Status.GAME_OVER
