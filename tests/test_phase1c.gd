extends GutTest

## Phase 1-C: GameSession transaction / refill / Game Over.


func _mono_generator(seed_value: int = 1) -> PieceGenerator:
	var catalog := PieceCatalog.create([PieceShape.create_single_cell()])
	var generator := PieceGenerator.create(catalog)
	generator.set_seed(seed_value)
	return generator


func _catalog_generator(pieces: Array, seed_value: int = 1) -> PieceGenerator:
	var catalog := PieceCatalog.create(pieces)
	var generator := PieceGenerator.create(catalog)
	generator.set_seed(seed_value)
	return generator


func _snapshot_tray(session: GameSession) -> Array:
	var out: Array = []
	for i in range(PieceTray.SLOT_COUNT):
		if session.has_piece(i):
			out.append(session.piece_at(i).cells())
		else:
			out.append(null)
	return out


func _assert_unchanged(session: GameSession, cells_before: Array, remaining_before: int, tray_before: Array) -> void:
	assert_eq(session.occupied_cells(), cells_before)
	assert_eq(session.remaining_piece_count(), remaining_before)
	assert_eq(_snapshot_tray(session), tray_before)


func test_session_init_valid_and_invalid() -> void:
	var ok := GameSession.create(3, 3, _mono_generator())
	assert_true(ok.is_valid())
	assert_eq(ok.status(), GameSession.Status.ACTIVE)
	assert_eq(ok.board_width(), 3)
	assert_eq(ok.board_height(), 3)
	assert_eq(ok.remaining_piece_count(), 3)
	assert_false(ok.is_game_over())
	for i in range(3):
		assert_true(ok.has_piece(i))

	assert_false(GameSession.create(0, 3, _mono_generator()).is_valid())
	assert_false(GameSession.create(3, 0, _mono_generator()).is_valid())
	assert_false(GameSession.create(3, 3, null).is_valid())
	assert_false(GameSession.create(3, 3, PieceGenerator.create(PieceCatalog.create([]))).is_valid())


func test_session_initial_tray_all_unplaceable_is_game_over() -> void:
	## 3-wide bar cannot fit on a 2x2 board.
	var bar3 := PieceShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	var session := GameSession.create(2, 2, _catalog_generator([bar3]))
	assert_true(session.is_valid())
	assert_eq(session.status(), GameSession.Status.GAME_OVER)
	assert_true(session.is_game_over())
	assert_eq(session.remaining_piece_count(), 3)


func test_successful_move_consumes_slot_and_updates_board() -> void:
	var session := GameSession.create(3, 3, _mono_generator())
	var other0 := session.piece_at(1).cells()
	var other1 := session.piece_at(2).cells()

	var result := session.place_from_slot(0, Vector2i(1, 1))
	assert_true(result.success)
	assert_eq(result.failure_reason, MoveResult.FailureReason.NONE)
	assert_eq(result.slot_index, 0)
	assert_eq(result.origin, Vector2i(1, 1))
	assert_eq(result.placed_cell_count, 1)
	assert_eq(result.cleared_cell_count, 0)
	assert_false(result.tray_refilled)
	assert_false(result.game_over_after_move)

	assert_true(session.is_occupied(Vector2i(1, 1)))
	assert_eq(session.occupied_cells().size(), 1)
	assert_false(session.has_piece(0))
	assert_true(session.has_piece(1))
	assert_true(session.has_piece(2))
	assert_eq(session.piece_at(1).cells(), other0)
	assert_eq(session.piece_at(2).cells(), other1)
	assert_eq(session.remaining_piece_count(), 2)
	assert_eq(session.status(), GameSession.Status.ACTIVE)


func test_invalid_moves_are_fully_immutable() -> void:
	var session := GameSession.create(3, 3, _mono_generator())
	assert_true(session.place_from_slot(0, Vector2i(0, 0)).success)

	var cases: Array = [
		[-1, Vector2i(1, 1), MoveResult.FailureReason.INVALID_SLOT],
		[3, Vector2i(1, 1), MoveResult.FailureReason.INVALID_SLOT],
		[0, Vector2i(1, 1), MoveResult.FailureReason.EMPTY_SLOT], # already consumed
		[1, Vector2i(-1, 0), MoveResult.FailureReason.INVALID_PLACEMENT],
		[1, Vector2i(0, 0), MoveResult.FailureReason.INVALID_PLACEMENT], # overlap
	]
	for case in cases:
		var cells_before := session.occupied_cells()
		var remaining_before := session.remaining_piece_count()
		var tray_before := _snapshot_tray(session)
		var result := session.place_from_slot(case[0], case[1])
		assert_false(result.success, "expected fail for %s" % str(case))
		assert_eq(result.failure_reason, case[2])
		assert_false(result.tray_refilled)
		_assert_unchanged(session, cells_before, remaining_before, tray_before)


func test_game_over_blocks_further_moves_without_mutation() -> void:
	var bar3 := PieceShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	var session := GameSession.create(2, 2, _catalog_generator([bar3]))
	assert_true(session.is_game_over())
	var cells_before := session.occupied_cells()
	var remaining_before := session.remaining_piece_count()
	var tray_before := _snapshot_tray(session)
	var result := session.place_from_slot(0, Vector2i(0, 0))
	assert_false(result.success)
	assert_eq(result.failure_reason, MoveResult.FailureReason.GAME_OVER)
	_assert_unchanged(session, cells_before, remaining_before, tray_before)


func test_invalid_session_move_fails() -> void:
	var session := GameSession.create(0, 3, _mono_generator())
	assert_false(session.is_valid())
	var result := session.place_from_slot(0, Vector2i(0, 0))
	assert_false(result.success)
	assert_eq(result.failure_reason, MoveResult.FailureReason.INVALID_SESSION)


func test_row_clear_via_session_move() -> void:
	var session := GameSession.create(3, 3, _mono_generator())
	assert_true(session.place_from_slot(0, Vector2i(0, 1)).success)
	assert_true(session.place_from_slot(1, Vector2i(1, 1)).success)
	var result := session.place_from_slot(2, Vector2i(2, 1))
	assert_true(result.success)
	assert_eq(result.cleared_rows, [1])
	assert_eq(result.cleared_columns, [])
	assert_eq(result.cleared_cell_count, 3)
	assert_true(result.tray_refilled) # third consume → refill
	assert_eq(session.remaining_piece_count(), 3)
	assert_eq(session.occupied_cells().size(), 0)


func test_column_clear_via_session_move() -> void:
	var session := GameSession.create(3, 3, _mono_generator())
	assert_true(session.place_from_slot(0, Vector2i(2, 0)).success)
	assert_true(session.place_from_slot(1, Vector2i(2, 1)).success)
	var result := session.place_from_slot(2, Vector2i(2, 2))
	assert_true(result.success)
	assert_eq(result.cleared_rows, [])
	assert_eq(result.cleared_columns, [2])
	assert_eq(result.cleared_cell_count, 3)
	assert_true(result.tray_refilled)
	assert_eq(session.occupied_cells().size(), 0)


func test_simultaneous_row_and_column_clear_via_session() -> void:
	## Build row1 + col1 incomplete, then the final cell completes both at once.
	var session := GameSession.create(3, 3, _mono_generator())
	assert_true(session.place_from_slot(0, Vector2i(0, 1)).success)
	assert_true(session.place_from_slot(1, Vector2i(2, 1)).success)
	assert_true(session.place_from_slot(2, Vector2i(1, 0)).success) # refill
	assert_eq(session.remaining_piece_count(), 3)
	assert_true(session.place_from_slot(0, Vector2i(1, 2)).success)
	var result := session.place_from_slot(1, Vector2i(1, 1))
	assert_true(result.success)
	assert_eq(result.cleared_rows, [1])
	assert_eq(result.cleared_columns, [1])
	assert_eq(result.cleared_cell_count, 5)
	assert_eq(session.occupied_cells().size(), 0)


func test_refill_only_after_third_consume() -> void:
	var session := GameSession.create(4, 4, _mono_generator(11))
	var r1 := session.place_from_slot(0, Vector2i(0, 0))
	assert_true(r1.success)
	assert_false(r1.tray_refilled)
	assert_eq(session.remaining_piece_count(), 2)

	var r2 := session.place_from_slot(1, Vector2i(1, 0))
	assert_true(r2.success)
	assert_false(r2.tray_refilled)
	assert_eq(session.remaining_piece_count(), 1)

	var r3 := session.place_from_slot(2, Vector2i(2, 0))
	assert_true(r3.success)
	assert_true(r3.tray_refilled)
	assert_eq(session.remaining_piece_count(), 3)
	for i in range(3):
		assert_true(session.has_piece(i))
		assert_true(session.piece_at(i).is_valid())


func test_refill_sequence_is_seed_reproducible() -> void:
	## Multi-piece catalog so seed actually affects which shapes appear (not mono-only).
	var catalog_pieces: Array = [
		PieceShape.create_single_cell(),
		PieceShape.create([Vector2i(0, 0), Vector2i(1, 0)]),
		PieceShape.create([Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]),
	]
	var a := GameSession.create(8, 8, _catalog_generator(catalog_pieces, 99))
	var b := GameSession.create(8, 8, _catalog_generator(catalog_pieces, 99))
	assert_eq(_snapshot_tray(a), _snapshot_tray(b))
	# Same legal mono-safe origins far apart; works for any of the small test shapes.
	var origins: Array[Vector2i] = [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 4)]
	for slot in [0, 1, 2]:
		assert_true(a.place_from_slot(slot, origins[slot]).success)
		assert_true(b.place_from_slot(slot, origins[slot]).success)
	assert_eq(a.remaining_piece_count(), 3)
	assert_eq(b.remaining_piece_count(), 3)
	assert_eq(_snapshot_tray(a), _snapshot_tray(b))
	assert_eq(a.occupied_cells(), b.occupied_cells())


func test_game_over_when_exactly_one_remaining_piece_cannot_place() -> void:
	## 3x2 + diagonal: two successful places leave remaining_count==1 unplaceable (no refill).
	var diagonal := PieceShape.create([Vector2i(0, 0), Vector2i(1, 1)])
	var session := GameSession.create(3, 2, _catalog_generator([diagonal]))
	assert_eq(session.status(), GameSession.Status.ACTIVE)
	assert_eq(session.remaining_piece_count(), 3)

	var first := session.place_from_slot(0, Vector2i(0, 0))
	assert_true(first.success)
	assert_false(first.tray_refilled)
	assert_false(first.game_over_after_move)
	assert_eq(session.status(), GameSession.Status.ACTIVE)
	assert_eq(session.remaining_piece_count(), 2)

	var second := session.place_from_slot(1, Vector2i(1, 0))
	assert_true(second.success)
	assert_false(second.tray_refilled)
	assert_true(second.game_over_after_move)
	assert_eq(session.status(), GameSession.Status.GAME_OVER)
	assert_eq(session.remaining_piece_count(), 1)
	assert_true(session.has_piece(2))
	assert_false(session.has_piece(0))
	assert_false(session.has_piece(1))


func test_game_over_when_remaining_pieces_cannot_place() -> void:
	## Diagonal domino only fits at origin (0,0) on 2x2; second cannot place.
	var diagonal := PieceShape.create([Vector2i(0, 0), Vector2i(1, 1)])
	var session := GameSession.create(2, 2, _catalog_generator([diagonal]))
	assert_eq(session.status(), GameSession.Status.ACTIVE)
	var result := session.place_from_slot(0, Vector2i(0, 0))
	assert_true(result.success)
	assert_false(result.tray_refilled)
	assert_true(result.game_over_after_move)
	assert_eq(session.status(), GameSession.Status.GAME_OVER)
	assert_eq(session.remaining_piece_count(), 2)
	assert_true(session.has_piece(1))
	assert_true(session.has_piece(2))
	# Further moves rejected without mutation.
	var cells_before := session.occupied_cells()
	var tray_before := _snapshot_tray(session)
	var blocked := session.place_from_slot(1, Vector2i(0, 0))
	assert_false(blocked.success)
	assert_eq(blocked.failure_reason, MoveResult.FailureReason.GAME_OVER)
	assert_eq(session.occupied_cells(), cells_before)
	assert_eq(_snapshot_tray(session), tray_before)


func test_active_when_at_least_one_remaining_piece_fits() -> void:
	var session := GameSession.create(3, 3, _mono_generator())
	assert_true(session.place_from_slot(0, Vector2i(0, 0)).success)
	assert_eq(session.status(), GameSession.Status.ACTIVE)
	assert_false(session.is_game_over())
	assert_eq(session.remaining_piece_count(), 2)


func test_refill_then_game_over_when_new_tray_unplaceable() -> void:
	## 4x4 + 2x2 squares: third move places center block, refills, then no square fits.
	var square := PieceShape.create([
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
	])
	var session := GameSession.create(4, 4, _catalog_generator([square]))
	assert_true(session.place_from_slot(0, Vector2i(0, 0)).success)
	assert_true(session.place_from_slot(1, Vector2i(2, 0)).success) # clears top rows
	var result := session.place_from_slot(2, Vector2i(1, 1))
	assert_true(result.success)
	assert_true(result.tray_refilled)
	assert_true(result.game_over_after_move)
	assert_eq(session.status(), GameSession.Status.GAME_OVER)
	assert_eq(session.remaining_piece_count(), 3)
	assert_eq(session.occupied_cells().size(), 4)


func test_clear_can_keep_session_active() -> void:
	## L on 2x2 clears to empty board; remaining L pieces remain placeable.
	var l_shape := PieceShape.create([Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)])
	var session := GameSession.create(2, 2, _catalog_generator([l_shape]))
	assert_eq(session.status(), GameSession.Status.ACTIVE)
	var result := session.place_from_slot(0, Vector2i(0, 0))
	assert_true(result.success)
	assert_true(result.cleared_cell_count > 0)
	assert_eq(session.occupied_cells().size(), 0)
	assert_eq(session.status(), GameSession.Status.ACTIVE)
	assert_eq(session.remaining_piece_count(), 2)
	assert_false(result.game_over_after_move)


func test_empty_tray_is_not_instant_game_over_because_refill_runs_first() -> void:
	var session := GameSession.create(3, 3, _mono_generator())
	assert_true(session.place_from_slot(0, Vector2i(0, 0)).success)
	assert_true(session.place_from_slot(1, Vector2i(1, 0)).success)
	var result := session.place_from_slot(2, Vector2i(2, 0))
	assert_true(result.success)
	assert_true(result.tray_refilled)
	assert_eq(session.remaining_piece_count(), 3)
	assert_eq(session.status(), GameSession.Status.ACTIVE)
	assert_false(session.is_game_over())
