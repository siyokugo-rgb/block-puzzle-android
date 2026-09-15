class_name MoveResult
extends RefCounted

## Phase 1-C: outcome of one GameSession.place_from_slot attempt.
## No score values — clear fields are reserved for later scoring.

enum FailureReason {
	NONE,
	INVALID_SESSION,
	GAME_OVER,
	INVALID_SLOT,
	EMPTY_SLOT,
	INVALID_PLACEMENT,
	INTERNAL_ERROR,
}

var success: bool = false
var failure_reason: FailureReason = FailureReason.NONE
var slot_index: int = -1
var origin: Vector2i = Vector2i.ZERO
var placed_cell_count: int = 0
var cleared_rows: Array[int] = []
var cleared_columns: Array[int] = []
var cleared_cell_count: int = 0
var tray_refilled: bool = false
var game_over_after_move: bool = false


static func fail(reason: FailureReason, slot: int = -1, origin_pos: Vector2i = Vector2i.ZERO) -> MoveResult:
	var result := MoveResult.new()
	result.success = false
	result.failure_reason = reason
	result.slot_index = slot
	result.origin = origin_pos
	return result


static func failure_reason_name(reason: FailureReason) -> String:
	return FailureReason.keys()[reason]
