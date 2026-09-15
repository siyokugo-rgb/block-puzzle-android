extends GutTest

## Phase 1-A: pure game-core tests (Board / Piece / place / line clear).
## No UI, ads, score, or tray coverage.


func test_piece_single_cell_valid() -> void:
	var piece := PieceShape.create([Vector2i(0, 0)])
	assert_true(piece.is_valid())
	assert_eq(piece.cell_count(), 1)
	assert_eq(piece.cells(), [Vector2i(0, 0)])


func test_piece_multi_cell_shapes_valid() -> void:
	var horizontal := PieceShape.create([Vector2i(0, 0), Vector2i(1, 0)])
	assert_true(horizontal.is_valid())
	assert_eq(horizontal.cell_count(), 2)

	var l_shape := PieceShape.create([Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)])
	assert_true(l_shape.is_valid())
	assert_eq(l_shape.cell_count(), 3)

	# Order of input must not matter; cells() is normalized.
	var shuffled := PieceShape.create([Vector2i(1, 1), Vector2i(0, 0), Vector2i(0, 1)])
	assert_true(shuffled.is_valid())
	assert_eq(shuffled.cells(), l_shape.cells())


func test_piece_rejects_duplicate_offset() -> void:
	var piece := PieceShape.create([Vector2i(0, 0), Vector2i(0, 0)])
	assert_false(piece.is_valid())
	assert_eq(piece.cell_count(), 0)
	assert_true(piece.validation_error().find("duplicate") >= 0)


func test_piece_rejects_empty() -> void:
	var piece := PieceShape.create([])
	assert_false(piece.is_valid())
	assert_eq(piece.cell_count(), 0)
	assert_true(piece.validation_error().find("at least one") >= 0)


func test_piece_rejects_non_vector2i() -> void:
	var piece := PieceShape.create([Vector2i(0, 0), "bad"])
	assert_false(piece.is_valid())
	assert_true(piece.validation_error().find("Vector2i") >= 0)


func test_board_create_valid_sizes() -> void:
	var board := BoardState.create(3, 2)
	assert_true(board.is_valid())
	assert_eq(board.width(), 3)
	assert_eq(board.height(), 2)
	assert_eq(board.occupied_count(), 0)

	var minimal := BoardState.create(1, 1)
	assert_true(minimal.is_valid())
	assert_eq(minimal.width(), 1)
	assert_eq(minimal.height(), 1)


func test_board_rejects_non_positive_sizes() -> void:
	for size_pair in [[0, 3], [3, 0], [-1, 2], [2, -1], [0, 0]]:
		var board := BoardState.create(size_pair[0], size_pair[1])
		assert_false(board.is_valid(), "expected invalid for %s" % str(size_pair))
		assert_true(board.validation_error().find("positive") >= 0)


func test_can_place_empty_board_positions() -> void:
	var board := BoardState.create(4, 4)
	var mono := PieceShape.create_single_cell()
	var bar := PieceShape.create([Vector2i(0, 0), Vector2i(1, 0)])

	assert_true(board.can_place(mono, Vector2i(0, 0))) # top-left
	assert_true(board.can_place(mono, Vector2i(2, 2))) # center
	assert_true(board.can_place(mono, Vector2i(3, 3))) # bottom-right
	assert_true(board.can_place(bar, Vector2i(2, 0))) # fits at right edge


func test_can_place_rejects_out_of_bounds() -> void:
	var board := BoardState.create(3, 3)
	var bar := PieceShape.create([Vector2i(0, 0), Vector2i(1, 0)])
	var tall := PieceShape.create([Vector2i(0, 0), Vector2i(0, 1)])

	assert_false(board.can_place(bar, Vector2i(2, 0))) # overflows right
	assert_false(board.can_place(tall, Vector2i(0, 2))) # overflows bottom
	assert_false(board.can_place(bar, Vector2i(-1, 0))) # negative x
	assert_false(board.can_place(tall, Vector2i(0, -1))) # negative y
	assert_false(board.can_place(PieceShape.create_single_cell(), Vector2i(3, 0)))
	assert_false(board.can_place(PieceShape.create_single_cell(), Vector2i(0, 3)))


func test_can_place_rejects_overlap_and_invalid_piece() -> void:
	var board := BoardState.create(3, 3)
	var mono := PieceShape.create_single_cell()
	assert_true(board.place(mono, Vector2i(1, 1)))
	assert_false(board.can_place(mono, Vector2i(1, 1)))

	var invalid := PieceShape.create([])
	assert_false(board.can_place(invalid, Vector2i(0, 0)))
	assert_false(board.can_place(null, Vector2i(0, 0)))


func test_place_atomic_success_and_failure() -> void:
	var board := BoardState.create(3, 3)
	var l_shape := PieceShape.create([Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)])

	assert_true(board.place(l_shape, Vector2i(0, 0)))
	assert_eq(board.occupied_count(), 3)
	assert_true(board.is_occupied(Vector2i(0, 0)))
	assert_true(board.is_occupied(Vector2i(0, 1)))
	assert_true(board.is_occupied(Vector2i(1, 1)))
	assert_true(board.is_empty(Vector2i(1, 0)))

	var before := board.occupied_cells().duplicate()
	# Overlaps existing cells — must not partially apply.
	assert_false(board.place(l_shape, Vector2i(0, 0)))
	assert_eq(board.occupied_cells(), before)

	# Out of bounds — board unchanged.
	assert_false(board.place(l_shape, Vector2i(2, 2)))
	assert_eq(board.occupied_cells(), before)


func test_place_rejects_invalid_piece_without_mutation() -> void:
	var board := BoardState.create(2, 2)
	assert_false(board.place(PieceShape.create([]), Vector2i(0, 0)))
	assert_false(board.place(PieceShape.create([Vector2i(0, 0), Vector2i(0, 0)]), Vector2i(0, 0)))
	assert_eq(board.occupied_count(), 0)


func test_horizontal_clear_only_completed_rows() -> void:
	var board := BoardState.create(3, 3)
	# Fill row y=1 completely; leave others incomplete.
	assert_true(board.place(PieceShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]), Vector2i(0, 1)))
	assert_true(board.place(PieceShape.create_single_cell(), Vector2i(0, 0)))

	var result := board.clear_completed_lines()
	assert_eq(result.cleared_rows, [1])
	assert_eq(result.cleared_columns, [])
	assert_eq(result.cleared_cell_count, 3)
	assert_true(board.is_empty(Vector2i(0, 1)))
	assert_true(board.is_empty(Vector2i(1, 1)))
	assert_true(board.is_empty(Vector2i(2, 1)))
	assert_true(board.is_occupied(Vector2i(0, 0))) # untouched incomplete row


func test_vertical_clear_only_completed_columns() -> void:
	var board := BoardState.create(3, 3)
	assert_true(board.place(PieceShape.create([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]), Vector2i(1, 0)))
	assert_true(board.place(PieceShape.create_single_cell(), Vector2i(0, 2)))

	var result := board.clear_completed_lines()
	assert_eq(result.cleared_rows, [])
	assert_eq(result.cleared_columns, [1])
	assert_eq(result.cleared_cell_count, 3)
	assert_true(board.is_empty(Vector2i(1, 0)))
	assert_true(board.is_empty(Vector2i(1, 1)))
	assert_true(board.is_empty(Vector2i(1, 2)))
	assert_true(board.is_occupied(Vector2i(0, 2)))


func test_simultaneous_row_and_column_clear_counts_intersection_once() -> void:
	var board := BoardState.create(3, 3)
	# Fill row 1 and column 1 completely (intersection at 1,1).
	for x in range(3):
		assert_true(board.place(PieceShape.create_single_cell(), Vector2i(x, 1)))
	# Column 1 still needs (1,0) and (1,2); (1,1) already filled.
	assert_true(board.place(PieceShape.create_single_cell(), Vector2i(1, 0)))
	assert_true(board.place(PieceShape.create_single_cell(), Vector2i(1, 2)))

	assert_eq(board.occupied_count(), 5) # 3 row + 2 extra column cells

	var result := board.clear_completed_lines()
	assert_eq(result.cleared_rows, [1])
	assert_eq(result.cleared_columns, [1])
	# 3 (row) + 3 (col) - 1 intersection = 5 unique cells
	assert_eq(result.cleared_cell_count, 5)
	assert_eq(board.occupied_count(), 0)


func test_simultaneous_multiple_rows_and_columns() -> void:
	var board := BoardState.create(3, 3)
	# Fill entire board → all 3 rows and 3 columns complete.
	for y in range(3):
		for x in range(3):
			assert_true(board.place(PieceShape.create_single_cell(), Vector2i(x, y)))

	var result := board.clear_completed_lines()
	assert_eq(result.cleared_rows, [0, 1, 2])
	assert_eq(result.cleared_columns, [0, 1, 2])
	assert_eq(result.cleared_cell_count, 9)
	assert_eq(board.occupied_count(), 0)


func test_simultaneous_two_rows_no_columns() -> void:
	# Height 4 so two full rows cannot complete any column without extra cells.
	var board := BoardState.create(2, 4)
	for x in range(2):
		assert_true(board.place(PieceShape.create_single_cell(), Vector2i(x, 0)))
		assert_true(board.place(PieceShape.create_single_cell(), Vector2i(x, 2)))
	assert_true(board.place(PieceShape.create_single_cell(), Vector2i(0, 1))) # survivor

	var result := board.clear_completed_lines()
	assert_eq(result.cleared_rows, [0, 2])
	assert_eq(result.cleared_columns, [])
	assert_eq(result.cleared_cell_count, 4)
	assert_true(board.is_occupied(Vector2i(0, 1)))
	assert_true(board.is_empty(Vector2i(0, 0)))
	assert_true(board.is_empty(Vector2i(1, 2)))


func test_simultaneous_two_columns_no_rows() -> void:
	# Width 4 so two full columns cannot complete any row without extra cells.
	var board := BoardState.create(4, 2)
	for y in range(2):
		assert_true(board.place(PieceShape.create_single_cell(), Vector2i(0, y)))
		assert_true(board.place(PieceShape.create_single_cell(), Vector2i(2, y)))
	assert_true(board.place(PieceShape.create_single_cell(), Vector2i(1, 0))) # survivor

	var result := board.clear_completed_lines()
	assert_eq(result.cleared_rows, [])
	assert_eq(result.cleared_columns, [0, 2])
	assert_eq(result.cleared_cell_count, 4)
	assert_true(board.is_occupied(Vector2i(1, 0)))
	assert_true(board.is_empty(Vector2i(0, 0)))
	assert_true(board.is_empty(Vector2i(2, 1)))


func test_post_clear_allows_new_placement() -> void:
	var board := BoardState.create(2, 2)
	assert_true(board.place(PieceShape.create([Vector2i(0, 0), Vector2i(1, 0)]), Vector2i(0, 0)))
	assert_true(board.place(PieceShape.create([Vector2i(0, 0), Vector2i(1, 0)]), Vector2i(0, 1)))
	var result := board.clear_completed_lines()
	assert_true(result.has_clears())
	assert_eq(board.occupied_count(), 0)

	var bar := PieceShape.create([Vector2i(0, 0), Vector2i(0, 1)])
	assert_true(board.can_place(bar, Vector2i(1, 0)))
	assert_true(board.place(bar, Vector2i(1, 0)))
	assert_eq(board.occupied_count(), 2)


func test_no_clear_when_no_line_complete() -> void:
	var board := BoardState.create(3, 3)
	assert_true(board.place(PieceShape.create([Vector2i(0, 0), Vector2i(1, 0)]), Vector2i(0, 0)))
	var result := board.clear_completed_lines()
	assert_false(result.has_clears())
	assert_eq(result.cleared_cell_count, 0)
	assert_eq(board.occupied_count(), 2)


func test_invalid_board_rejects_placement_and_clear() -> void:
	var board := BoardState.create(0, 5)
	assert_false(board.is_valid())
	assert_false(board.can_place(PieceShape.create_single_cell(), Vector2i(0, 0)))
	assert_false(board.place(PieceShape.create_single_cell(), Vector2i(0, 0)))
	var result := board.clear_completed_lines()
	assert_false(result.has_clears())
	assert_eq(result.cleared_cell_count, 0)


func test_coordinate_contract_top_left_origin() -> void:
	## Documents board contract: (0,0) is top-left; +x right; +y down.
	var board := BoardState.create(2, 2)
	assert_true(board.place(PieceShape.create_single_cell(), Vector2i(0, 0)))
	assert_true(board.is_occupied(Vector2i(0, 0)))
	assert_true(board.is_empty(Vector2i(1, 0)))
	assert_true(board.is_empty(Vector2i(0, 1)))
	assert_true(board.is_empty(Vector2i(1, 1)))
