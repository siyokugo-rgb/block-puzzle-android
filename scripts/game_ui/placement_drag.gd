class_name PlacementDrag
extends RefCounted

## Pure drag / drop interaction state for Phase 1-D.
## Preview queries use can_place_from_slot; commit uses place_from_slot once.

enum Phase {
	IDLE,
	DRAGGING,
}


var _phase: Phase = Phase.IDLE
var _slot_index: int = -1
var _pointer_local: Vector2 = Vector2.ZERO
var _preview_origin: Vector2i = Vector2i.ZERO
var _preview_valid: bool = false
var _has_preview_origin: bool = false
var _committed: bool = false


func phase() -> Phase:
	return _phase


func is_dragging() -> bool:
	return _phase == Phase.DRAGGING


func slot_index() -> int:
	return _slot_index


func pointer_local() -> Vector2:
	return _pointer_local


func has_preview_origin() -> bool:
	return _has_preview_origin


func preview_origin() -> Vector2i:
	return _preview_origin


func preview_valid() -> bool:
	return _preview_valid


func was_committed() -> bool:
	return _committed


## Start drag from a tray slot. Empty / game-over / invalid session → false.
func begin(session: GameSession, slot_index: int, pointer_local: Vector2) -> bool:
	cancel()
	if session == null or not session.is_valid() or session.is_game_over():
		return false
	if slot_index < 0 or slot_index >= PieceTray.SLOT_COUNT:
		return false
	if not session.has_piece(slot_index):
		return false
	_phase = Phase.DRAGGING
	_slot_index = slot_index
	_pointer_local = pointer_local
	_committed = false
	_clear_preview()
	return true


## Update pointer and refresh preview against session query (no mutation).
func update(
	session: GameSession,
	coords: BoardCoords,
	pointer_local: Vector2,
	finger_offset: Vector2
) -> void:
	if _phase != Phase.DRAGGING:
		return
	_pointer_local = pointer_local
	if session == null or coords == null:
		_clear_preview()
		return
	var preview_point := pointer_local + finger_offset
	var cell := coords.local_to_cell(preview_point)
	if not coords.is_cell_in_bounds(cell):
		_clear_preview()
		_preview_origin = cell
		_has_preview_origin = true
		_preview_valid = false
		return
	_preview_origin = cell
	_has_preview_origin = true
	_preview_valid = session.can_place_from_slot(_slot_index, cell)


## Cancel drag without placing. Session unchanged.
func cancel() -> void:
	_phase = Phase.IDLE
	_slot_index = -1
	_pointer_local = Vector2.ZERO
	_committed = false
	_clear_preview()


## Release once. Invalid / already committed → null and no place call.
## Valid attempt calls place_from_slot exactly once; MoveResult is SoT.
func release(session: GameSession) -> MoveResult:
	if _phase != Phase.DRAGGING:
		return null
	if _committed:
		return null
	var slot := _slot_index
	var origin := _preview_origin
	var had_origin := _has_preview_origin
	var looked_valid := _preview_valid
	# End drag before place so a re-entrant release cannot double-place.
	_phase = Phase.IDLE
	_slot_index = -1
	_clear_preview()
	if session == null or not had_origin or not looked_valid:
		return null
	_committed = true
	return session.place_from_slot(slot, origin)


func _clear_preview() -> void:
	_preview_origin = Vector2i.ZERO
	_preview_valid = false
	_has_preview_origin = false
