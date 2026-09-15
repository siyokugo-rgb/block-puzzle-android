extends GutTest

## Phase 1-D: playable slice helpers — can_place query, coords, drag, sync.


func _mono_session(w: int = 3, h: int = 3, seed_value: int = 1) -> GameSession:
	var catalog := PieceCatalog.create([PieceShape.create_single_cell()])
	var generator := PieceGenerator.create(catalog)
	generator.set_seed(seed_value)
	return GameSession.create(w, h, generator)


func _snapshot(session: GameSession) -> Dictionary:
	return {
		"cells": session.occupied_cells(),
		"remaining": session.remaining_piece_count(),
		"tray": _tray_snap(session),
		"status": session.status(),
	}


func _tray_snap(session: GameSession) -> Array:
	var out: Array = []
	for i in range(PieceTray.SLOT_COUNT):
		if session.has_piece(i):
			out.append(session.piece_at(i).cells())
		else:
			out.append(null)
	return out


func _assert_same(session: GameSession, before: Dictionary) -> void:
	assert_eq(session.occupied_cells(), before["cells"])
	assert_eq(session.remaining_piece_count(), before["remaining"])
	assert_eq(_tray_snap(session), before["tray"])
	assert_eq(session.status(), before["status"])


# --- A. can_place_from_slot ---

func test_can_place_valid_and_immutable() -> void:
	var session := _mono_session()
	var before := _snapshot(session)
	assert_true(session.can_place_from_slot(0, Vector2i(0, 0)))
	_assert_same(session, before)


func test_can_place_invalid_slot() -> void:
	var session := _mono_session()
	assert_false(session.can_place_from_slot(-1, Vector2i(0, 0)))
	assert_false(session.can_place_from_slot(3, Vector2i(0, 0)))


func test_can_place_consumed_slot() -> void:
	var session := _mono_session(4, 4)
	assert_true(session.place_from_slot(0, Vector2i(0, 0)).success)
	assert_false(session.has_piece(0))
	var before := _snapshot(session)
	assert_false(session.can_place_from_slot(0, Vector2i(1, 0)))
	_assert_same(session, before)


func test_can_place_out_of_bounds() -> void:
	var session := _mono_session(2, 2)
	assert_false(session.can_place_from_slot(0, Vector2i(-1, 0)))
	assert_false(session.can_place_from_slot(0, Vector2i(0, -1)))
	assert_false(session.can_place_from_slot(0, Vector2i(2, 0)))
	assert_false(session.can_place_from_slot(0, Vector2i(0, 2)))


func test_can_place_overlap() -> void:
	var session := _mono_session(3, 3)
	assert_true(session.place_from_slot(0, Vector2i(1, 1)).success)
	assert_false(session.can_place_from_slot(1, Vector2i(1, 1)))


func test_can_place_game_over_is_false_and_immutable() -> void:
	var diagonal := PieceShape.create([Vector2i(0, 0), Vector2i(1, 1)])
	var catalog := PieceCatalog.create([diagonal])
	var generator := PieceGenerator.create(catalog)
	generator.set_seed(1)
	var session := GameSession.create(2, 2, generator)
	assert_true(session.place_from_slot(0, Vector2i(0, 0)).success)
	assert_true(session.is_game_over())
	var before := _snapshot(session)
	assert_false(session.can_place_from_slot(1, Vector2i(0, 0)))
	_assert_same(session, before)


# --- B. BoardCoords ---

func test_coords_corners_and_edges() -> void:
	var coords := BoardCoords.create(Vector2(100, 200), 10.0, 8, 6)
	assert_eq(coords.local_to_cell(Vector2(100, 200)), Vector2i(0, 0)) # top-left
	assert_eq(coords.local_to_cell(Vector2(139, 229)), Vector2i(3, 2)) # center-ish
	assert_eq(coords.local_to_cell(Vector2(179.9, 200)), Vector2i(7, 0)) # right edge
	assert_eq(coords.local_to_cell(Vector2(100, 259.9)), Vector2i(0, 5)) # bottom edge
	assert_true(coords.is_cell_in_bounds(Vector2i(0, 0)))
	assert_true(coords.is_cell_in_bounds(Vector2i(7, 5)))


func test_coords_outside_bounds() -> void:
	var coords := BoardCoords.create(Vector2(50, 50), 20.0, 4, 4)
	assert_eq(coords.local_to_cell(Vector2(49.9, 60)), Vector2i(-1, 0)) # outside left
	assert_eq(coords.local_to_cell(Vector2(130, 60)), Vector2i(4, 0)) # outside right
	assert_eq(coords.local_to_cell(Vector2(60, 49.9)), Vector2i(0, -1)) # outside top
	assert_eq(coords.local_to_cell(Vector2(60, 130)), Vector2i(0, 4)) # outside bottom
	assert_false(coords.is_cell_in_bounds(Vector2i(-1, 0)))
	assert_false(coords.is_cell_in_bounds(Vector2i(4, 0)))
	assert_false(coords.is_cell_in_bounds(Vector2i(0, -1)))
	assert_false(coords.is_cell_in_bounds(Vector2i(0, 4)))
	assert_false(coords.contains_local(Vector2(40, 60)))
	assert_true(coords.contains_local(Vector2(50, 50)))


# --- C. PlacementDrag ---

func test_drag_begin_valid_and_empty_slot() -> void:
	var session := _mono_session(4, 4)
	var drag := PlacementDrag.new()
	assert_true(drag.begin(session, 0, Vector2(10, 10)))
	assert_true(drag.is_dragging())
	assert_eq(drag.slot_index(), 0)
	drag.cancel()
	assert_true(session.place_from_slot(0, Vector2i(0, 0)).success)
	assert_false(drag.begin(session, 0, Vector2(10, 10)))
	assert_false(drag.is_dragging())


func test_drag_cancel_leaves_session_unchanged() -> void:
	var session := _mono_session(4, 4)
	var before := _snapshot(session)
	var drag := PlacementDrag.new()
	var coords := BoardCoords.create(Vector2.ZERO, 10.0, 4, 4)
	assert_true(drag.begin(session, 0, Vector2(5, 5)))
	drag.update(session, coords, Vector2(15, 15), Vector2(0, -10))
	drag.cancel()
	_assert_same(session, before)
	assert_false(drag.is_dragging())


func test_drag_invalid_drop_does_not_mutate_session() -> void:
	var session := _mono_session(3, 3)
	assert_true(session.place_from_slot(0, Vector2i(1, 1)).success)
	var before := _snapshot(session)
	var drag := PlacementDrag.new()
	var coords := BoardCoords.create(Vector2.ZERO, 10.0, 3, 3)
	assert_true(drag.begin(session, 1, Vector2(5, 5)))
	# Point at occupied cell with zero finger offset.
	drag.update(session, coords, Vector2(15, 15), Vector2.ZERO)
	assert_true(drag.has_preview_origin())
	assert_false(drag.preview_valid())
	var result := drag.release(session)
	assert_eq(result, null)
	_assert_same(session, before)


func test_drag_valid_drop_places_once() -> void:
	var session := _mono_session(4, 4)
	var drag := PlacementDrag.new()
	var coords := BoardCoords.create(Vector2.ZERO, 10.0, 4, 4)
	assert_true(drag.begin(session, 0, Vector2(5, 5)))
	drag.update(session, coords, Vector2(5, 5), Vector2.ZERO)
	assert_true(drag.preview_valid())
	var result := drag.release(session)
	assert_ne(result, null)
	assert_true(result.success)
	assert_eq(session.remaining_piece_count(), 2)
	assert_false(session.has_piece(0))
	# Duplicate release must not place again.
	var cells := session.occupied_cells()
	var second := drag.release(session)
	assert_eq(second, null)
	assert_eq(session.occupied_cells(), cells)


func test_drag_outside_board_does_not_place() -> void:
	var session := _mono_session(3, 3)
	var before := _snapshot(session)
	var drag := PlacementDrag.new()
	var coords := BoardCoords.create(Vector2.ZERO, 10.0, 3, 3)
	assert_true(drag.begin(session, 0, Vector2(5, 5)))
	drag.update(session, coords, Vector2(-20, 5), Vector2.ZERO)
	assert_false(drag.preview_valid())
	assert_eq(drag.release(session), null)
	_assert_same(session, before)


# --- D. UI/domain sync via session after drag ---

func test_sync_after_successful_place_and_refill() -> void:
	var session := _mono_session(5, 5)
	var drag := PlacementDrag.new()
	var coords := BoardCoords.create(Vector2.ZERO, 8.0, 5, 5)
	var origins: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	for i in range(3):
		assert_true(drag.begin(session, i, Vector2(4, 4)))
		var px := Vector2(float(origins[i].x) * 8.0 + 4.0, 4.0)
		drag.update(session, coords, px, Vector2.ZERO)
		var result := drag.release(session)
		assert_ne(result, null)
		assert_true(result.success)
	# After third consume, tray refilled to 3.
	assert_eq(session.remaining_piece_count(), 3)
	for i in range(3):
		assert_true(session.has_piece(i))
	assert_eq(session.occupied_cells().size(), 3)


func test_game_over_disables_further_drag_begin() -> void:
	var diagonal := PieceShape.create([Vector2i(0, 0), Vector2i(1, 1)])
	var catalog := PieceCatalog.create([diagonal])
	var generator := PieceGenerator.create(catalog)
	generator.set_seed(1)
	var session := GameSession.create(2, 2, generator)
	assert_true(session.place_from_slot(0, Vector2i(0, 0)).success)
	assert_true(session.is_game_over())
	var drag := PlacementDrag.new()
	assert_false(drag.begin(session, 1, Vector2(1, 1)))
	assert_false(drag.is_dragging())


func test_dev_play_config_is_not_empty_catalog() -> void:
	var catalog := DevPlayConfig.create_dev_catalog()
	assert_true(catalog.is_valid())
	assert_gte(catalog.size(), 5)
	var session := DevPlayConfig.create_dev_session(7)
	assert_true(session.is_valid())
	assert_eq(session.board_width(), DevPlayConfig.DEV_BOARD_WIDTH)
	assert_eq(session.board_height(), DevPlayConfig.DEV_BOARD_HEIGHT)
	assert_eq(session.remaining_piece_count(), 3)
