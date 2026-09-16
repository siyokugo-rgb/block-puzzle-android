extends GutTest

## Phase R-C: MatchResolver / orthogonal ≥3 / simultaneous clear.


func _place(board: PuzzleBoard, x: int, y: int, orb: int) -> void:
	assert_true(board.set_orb(Vector2i(x, y), orb))


func _ids(cells: Array[Vector2i]) -> Array:
	var out: Array = []
	for c in cells:
		out.append(c)
	return out


func test_detect_no_match_on_stable_and_manual() -> void:
	var stable := OrbGenerator.create_match_stable_board(6, 6, 42)
	assert_ne(stable, null)
	var before := stable.snapshot_orb_ids()
	var result := MatchResolver.detect(stable)
	assert_true(result.is_valid())
	assert_false(result.has_matches())
	assert_eq(result.matched_cell_count(), 0)
	assert_eq(stable.snapshot_orb_ids(), before)

	var board := PuzzleBoard.create(3, 3)
	_place(board, 0, 0, OrbType.Id.ORB_0)
	_place(board, 1, 0, OrbType.Id.ORB_1)
	_place(board, 2, 0, OrbType.Id.ORB_0)
	var r2 := MatchResolver.detect(board)
	assert_true(r2.is_valid())
	assert_false(r2.has_matches())


func test_horizontal_runs_3_4_5_and_edges() -> void:
	# exactly 3 mid-row
	var b3 := PuzzleBoard.create(5, 1)
	_place(b3, 1, 0, OrbType.Id.ORB_0)
	_place(b3, 2, 0, OrbType.Id.ORB_0)
	_place(b3, 3, 0, OrbType.Id.ORB_0)
	var r3 := MatchResolver.detect(b3)
	assert_true(r3.has_matches())
	assert_eq(r3.matched_cell_count(), 3)
	assert_eq(_ids(r3.matched_cells_snapshot()), [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])

	# 4 at start of row
	var b4 := PuzzleBoard.create(5, 1)
	for x in range(4):
		_place(b4, x, 0, OrbType.Id.ORB_1)
	_place(b4, 4, 0, OrbType.Id.ORB_2)
	var r4 := MatchResolver.detect(b4)
	assert_eq(r4.matched_cell_count(), 4)

	# 5 entire row (end flush)
	var b5 := PuzzleBoard.create(5, 1)
	for x in range(5):
		_place(b5, x, 0, OrbType.Id.ORB_2)
	var r5 := MatchResolver.detect(b5)
	assert_eq(r5.matched_cell_count(), 5)


func test_vertical_runs_3_4_5_and_bottom_flush() -> void:
	var b3 := PuzzleBoard.create(1, 5)
	_place(b3, 0, 1, OrbType.Id.ORB_0)
	_place(b3, 0, 2, OrbType.Id.ORB_0)
	_place(b3, 0, 3, OrbType.Id.ORB_0)
	assert_eq(MatchResolver.detect(b3).matched_cell_count(), 3)

	var b4 := PuzzleBoard.create(1, 5)
	for y in range(4):
		_place(b4, 0, y, OrbType.Id.ORB_1)
	assert_eq(MatchResolver.detect(b4).matched_cell_count(), 4)

	var b5 := PuzzleBoard.create(1, 5)
	for y in range(5):
		_place(b5, 0, y, OrbType.Id.ORB_2)
	assert_eq(MatchResolver.detect(b5).matched_cell_count(), 5)


func test_break_semantics_empty_and_different_type() -> void:
	# A A . A A A → only last three
	var board := PuzzleBoard.create(6, 1)
	_place(board, 0, 0, OrbType.Id.ORB_0)
	_place(board, 1, 0, OrbType.Id.ORB_0)
	# (2,0) empty
	_place(board, 3, 0, OrbType.Id.ORB_0)
	_place(board, 4, 0, OrbType.Id.ORB_0)
	_place(board, 5, 0, OrbType.Id.ORB_0)
	var result := MatchResolver.detect(board)
	assert_eq(result.matched_cell_count(), 3)
	assert_eq(_ids(result.matched_cells_snapshot()), [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)])

	# A A B A A → no match
	var board2 := PuzzleBoard.create(5, 1)
	_place(board2, 0, 0, OrbType.Id.ORB_0)
	_place(board2, 1, 0, OrbType.Id.ORB_0)
	_place(board2, 2, 0, OrbType.Id.ORB_1)
	_place(board2, 3, 0, OrbType.Id.ORB_0)
	_place(board2, 4, 0, OrbType.Id.ORB_0)
	assert_false(MatchResolver.detect(board2).has_matches())


func test_diagonal_does_not_match() -> void:
	var board := PuzzleBoard.create(3, 3)
	_place(board, 0, 0, OrbType.Id.ORB_0)
	_place(board, 1, 1, OrbType.Id.ORB_0)
	_place(board, 2, 2, OrbType.Id.ORB_0)
	var result := MatchResolver.detect(board)
	assert_true(result.is_valid())
	assert_false(result.has_matches())


func test_simultaneous_disjoint_horizontal_and_vertical() -> void:
	var board := PuzzleBoard.create(5, 5)
	# horizontal on row 0
	_place(board, 0, 0, OrbType.Id.ORB_0)
	_place(board, 1, 0, OrbType.Id.ORB_0)
	_place(board, 2, 0, OrbType.Id.ORB_0)
	# vertical on col 4
	_place(board, 4, 2, OrbType.Id.ORB_1)
	_place(board, 4, 3, OrbType.Id.ORB_1)
	_place(board, 4, 4, OrbType.Id.ORB_1)
	var result := MatchResolver.detect(board)
	assert_eq(result.matched_cell_count(), 6)
	var cells := _ids(result.matched_cells_snapshot())
	assert_true(cells.has(Vector2i(0, 0)))
	assert_true(cells.has(Vector2i(4, 4)))


func test_intersection_unique_count_is_five() -> void:
	## Cross of A only; B/C fillers prevent other matches.
	# B A B
	# A A A
	# C A C
	var board := PuzzleBoard.create(3, 3)
	_place(board, 0, 0, OrbType.Id.ORB_1)
	_place(board, 1, 0, OrbType.Id.ORB_0)
	_place(board, 2, 0, OrbType.Id.ORB_1)
	_place(board, 0, 1, OrbType.Id.ORB_0)
	_place(board, 1, 1, OrbType.Id.ORB_0)
	_place(board, 2, 1, OrbType.Id.ORB_0)
	_place(board, 0, 2, OrbType.Id.ORB_2)
	_place(board, 1, 2, OrbType.Id.ORB_0)
	_place(board, 2, 2, OrbType.Id.ORB_2)
	var result := MatchResolver.detect(board)
	assert_eq(result.matched_cell_count(), 5)
	assert_eq(
		_ids(result.matched_cells_snapshot()),
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]
	)


func test_detect_is_read_only() -> void:
	var board := PuzzleBoard.create(3, 1)
	_place(board, 0, 0, OrbType.Id.ORB_0)
	_place(board, 1, 0, OrbType.Id.ORB_0)
	_place(board, 2, 0, OrbType.Id.ORB_0)
	var before := board.snapshot_orb_ids()
	var _r := MatchResolver.detect(board)
	assert_eq(board.snapshot_orb_ids(), before)


func test_result_snapshot_defensive_and_row_major() -> void:
	var board := PuzzleBoard.create(3, 3)
	_place(board, 0, 0, OrbType.Id.ORB_1)
	_place(board, 1, 0, OrbType.Id.ORB_0)
	_place(board, 2, 0, OrbType.Id.ORB_1)
	_place(board, 0, 1, OrbType.Id.ORB_0)
	_place(board, 1, 1, OrbType.Id.ORB_0)
	_place(board, 2, 1, OrbType.Id.ORB_0)
	_place(board, 0, 2, OrbType.Id.ORB_2)
	_place(board, 1, 2, OrbType.Id.ORB_0)
	_place(board, 2, 2, OrbType.Id.ORB_2)
	var result := MatchResolver.detect(board)
	var snap := result.matched_cells_snapshot()
	assert_eq(snap.size(), 5)
	snap[0] = Vector2i(9, 9)
	snap.clear()
	assert_eq(result.matched_cell_count(), 5)
	assert_eq(result.matched_cells_snapshot()[0], Vector2i(1, 0))


func test_clear_current_matches_union_and_preserves_others() -> void:
	var board := PuzzleBoard.create(3, 3)
	_place(board, 0, 0, OrbType.Id.ORB_1)
	_place(board, 1, 0, OrbType.Id.ORB_0)
	_place(board, 2, 0, OrbType.Id.ORB_1)
	_place(board, 0, 1, OrbType.Id.ORB_0)
	_place(board, 1, 1, OrbType.Id.ORB_0)
	_place(board, 2, 1, OrbType.Id.ORB_0)
	_place(board, 0, 2, OrbType.Id.ORB_2)
	_place(board, 1, 2, OrbType.Id.ORB_0)
	_place(board, 2, 2, OrbType.Id.ORB_2)
	var result := MatchResolver.clear_current_matches(board)
	assert_true(result.is_valid())
	assert_eq(result.matched_cell_count(), 5)
	assert_true(board.is_empty(Vector2i(1, 0)))
	assert_true(board.is_empty(Vector2i(0, 1)))
	assert_true(board.is_empty(Vector2i(1, 1)))
	assert_true(board.is_empty(Vector2i(2, 1)))
	assert_true(board.is_empty(Vector2i(1, 2)))
	assert_eq(board.orb_at(Vector2i(0, 0)), OrbType.Id.ORB_1)
	assert_eq(board.orb_at(Vector2i(2, 0)), OrbType.Id.ORB_1)
	assert_eq(board.orb_at(Vector2i(0, 2)), OrbType.Id.ORB_2)
	assert_eq(board.orb_at(Vector2i(2, 2)), OrbType.Id.ORB_2)


func test_clear_with_no_matches_leaves_board_unchanged() -> void:
	var board := PuzzleBoard.create(2, 2)
	_place(board, 0, 0, OrbType.Id.ORB_0)
	_place(board, 1, 0, OrbType.Id.ORB_1)
	var before := board.snapshot_orb_ids()
	var result := MatchResolver.clear_current_matches(board)
	assert_true(result.is_valid())
	assert_false(result.has_matches())
	assert_eq(board.snapshot_orb_ids(), before)


func test_invalid_inputs_do_not_crash_or_mutate() -> void:
	var invalid_board := PuzzleBoard.create(0, 3)
	assert_false(invalid_board.is_valid())
	var r1 := MatchResolver.detect(null)
	assert_false(r1.is_valid())
	var r2 := MatchResolver.detect(invalid_board)
	assert_false(r2.is_valid())
	var r3 := MatchResolver.clear_current_matches(null)
	assert_false(r3.is_valid())
	var r4 := MatchResolver.clear_current_matches(invalid_board)
	assert_false(r4.is_valid())
