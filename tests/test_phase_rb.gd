extends GutTest

## Phase R-B: DragRoute / 4-direction route swap (no match resolve).


func _fill_row3(board: PuzzleBoard, y: int, a: int, b: int, c: int) -> void:
	assert_true(board.set_orb(Vector2i(0, y), a))
	assert_true(board.set_orb(Vector2i(1, y), b))
	assert_true(board.set_orb(Vector2i(2, y), c))


func _snap(board: PuzzleBoard) -> Array:
	return board.snapshot_orb_ids()


func _assert_route_unchanged(
	route: DragRoute,
	board: PuzzleBoard,
	board_before: Array,
	path_before: Array,
	current_before: Vector2i,
	count_before: int
) -> void:
	assert_eq(_snap(board), board_before)
	assert_eq(route.path_snapshot(), path_before)
	assert_eq(route.current_cell(), current_before)
	assert_eq(route.swap_count(), count_before)


func test_begin_valid_and_failures() -> void:
	var board := PuzzleBoard.create(3, 3)
	_fill_row3(board, 0, OrbType.Id.ORB_0, OrbType.Id.ORB_1, OrbType.Id.ORB_2)
	var before := _snap(board)
	var route := DragRoute.begin(board, Vector2i(0, 0))
	assert_ne(route, null)
	assert_true(route.is_active())
	assert_eq(route.start_cell(), Vector2i(0, 0))
	assert_eq(route.current_cell(), Vector2i(0, 0))
	assert_eq(route.swap_count(), 0)
	assert_false(route.has_swaps())
	assert_eq(route.path_snapshot(), [Vector2i(0, 0)])
	assert_eq(_snap(board), before)

	assert_eq(DragRoute.begin(null, Vector2i(0, 0)), null)
	assert_eq(DragRoute.begin(PuzzleBoard.create(0, 3), Vector2i(0, 0)), null)
	assert_eq(DragRoute.begin(board, Vector2i(9, 0)), null)
	assert_eq(DragRoute.begin(board, Vector2i(1, 1)), null) # empty
	assert_eq(_snap(board), before)


func test_four_directions_swap() -> void:
	# Center cell with four neighbors.
	var board := PuzzleBoard.create(3, 3)
	assert_true(board.set_orb(Vector2i(1, 1), OrbType.Id.ORB_0)) # center carried
	assert_true(board.set_orb(Vector2i(2, 1), OrbType.Id.ORB_1)) # right
	assert_true(board.set_orb(Vector2i(0, 1), OrbType.Id.ORB_2)) # left
	assert_true(board.set_orb(Vector2i(1, 0), OrbType.Id.ORB_3)) # up
	assert_true(board.set_orb(Vector2i(1, 2), OrbType.Id.ORB_4)) # down

	# Right
	var r := DragRoute.begin(board, Vector2i(1, 1))
	assert_eq(r.try_step(Vector2i(2, 1)), DragRoute.StepResult.SWAPPED)
	assert_eq(board.orb_at(Vector2i(1, 1)), OrbType.Id.ORB_1)
	assert_eq(board.orb_at(Vector2i(2, 1)), OrbType.Id.ORB_0)
	assert_eq(r.current_cell(), Vector2i(2, 1))
	assert_eq(r.swap_count(), 1)
	assert_eq(r.path_snapshot(), [Vector2i(1, 1), Vector2i(2, 1)])
	# restore by swapping back for next direction isolation via fresh boards below


func test_four_directions_left_up_down() -> void:
	# Left
	var left_board := PuzzleBoard.create(3, 3)
	assert_true(left_board.set_orb(Vector2i(1, 1), OrbType.Id.ORB_0))
	assert_true(left_board.set_orb(Vector2i(0, 1), OrbType.Id.ORB_2))
	var left := DragRoute.begin(left_board, Vector2i(1, 1))
	assert_eq(left.try_step(Vector2i(0, 1)), DragRoute.StepResult.SWAPPED)
	assert_eq(left_board.orb_at(Vector2i(1, 1)), OrbType.Id.ORB_2)
	assert_eq(left_board.orb_at(Vector2i(0, 1)), OrbType.Id.ORB_0)
	assert_eq(left.current_cell(), Vector2i(0, 1))
	assert_eq(left.path_snapshot(), [Vector2i(1, 1), Vector2i(0, 1)])
	assert_eq(left.swap_count(), 1)

	# Up
	var up_board := PuzzleBoard.create(3, 3)
	assert_true(up_board.set_orb(Vector2i(1, 1), OrbType.Id.ORB_0))
	assert_true(up_board.set_orb(Vector2i(1, 0), OrbType.Id.ORB_3))
	var up := DragRoute.begin(up_board, Vector2i(1, 1))
	assert_eq(up.try_step(Vector2i(1, 0)), DragRoute.StepResult.SWAPPED)
	assert_eq(up_board.orb_at(Vector2i(1, 1)), OrbType.Id.ORB_3)
	assert_eq(up_board.orb_at(Vector2i(1, 0)), OrbType.Id.ORB_0)
	assert_eq(up.current_cell(), Vector2i(1, 0))
	assert_eq(up.path_snapshot(), [Vector2i(1, 1), Vector2i(1, 0)])
	assert_eq(up.swap_count(), 1)

	# Down
	var down_board := PuzzleBoard.create(3, 3)
	assert_true(down_board.set_orb(Vector2i(1, 1), OrbType.Id.ORB_0))
	assert_true(down_board.set_orb(Vector2i(1, 2), OrbType.Id.ORB_4))
	var down := DragRoute.begin(down_board, Vector2i(1, 1))
	assert_eq(down.try_step(Vector2i(1, 2)), DragRoute.StepResult.SWAPPED)
	assert_eq(down_board.orb_at(Vector2i(1, 1)), OrbType.Id.ORB_4)
	assert_eq(down_board.orb_at(Vector2i(1, 2)), OrbType.Id.ORB_0)
	assert_eq(down.current_cell(), Vector2i(1, 2))
	assert_eq(down.path_snapshot(), [Vector2i(1, 1), Vector2i(1, 2)])
	assert_eq(down.swap_count(), 1)


func test_invalid_steps_are_atomic() -> void:
	var board := PuzzleBoard.create(3, 3)
	_fill_row3(board, 1, OrbType.Id.ORB_0, OrbType.Id.ORB_1, OrbType.Id.ORB_2)
	var route := DragRoute.begin(board, Vector2i(1, 1))
	assert_eq(route.try_step(Vector2i(2, 1)), DragRoute.StepResult.SWAPPED)
	var board_before := _snap(board)
	var path_before := route.path_snapshot()
	var current_before := route.current_cell()
	var count_before := route.swap_count()

	# same cell jitter
	assert_eq(route.try_step(Vector2i(2, 1)), DragRoute.StepResult.NO_CHANGE_SAME_CELL)
	_assert_route_unchanged(route, board, board_before, path_before, current_before, count_before)

	# diagonal
	assert_eq(route.try_step(Vector2i(1, 0)), DragRoute.StepResult.REJECTED) # from (2,1) to (1,0) is diagonal
	_assert_route_unchanged(route, board, board_before, path_before, current_before, count_before)

	# distance > 1
	assert_eq(route.try_step(Vector2i(0, 1)), DragRoute.StepResult.REJECTED)
	_assert_route_unchanged(route, board, board_before, path_before, current_before, count_before)

	# OOB
	assert_eq(route.try_step(Vector2i(3, 1)), DragRoute.StepResult.REJECTED)
	_assert_route_unchanged(route, board, board_before, path_before, current_before, count_before)

	# empty destination (up from current is empty)
	assert_eq(route.try_step(Vector2i(2, 0)), DragRoute.StepResult.REJECTED)
	_assert_route_unchanged(route, board, board_before, path_before, current_before, count_before)


func test_carried_orb_along_route() -> void:
	## A=a, B=b, C=c → after A→B→C: b,c,a with carried `a` at head C.
	var board := PuzzleBoard.create(3, 1)
	_fill_row3(board, 0, OrbType.Id.ORB_0, OrbType.Id.ORB_1, OrbType.Id.ORB_2)
	var a := Vector2i(0, 0)
	var b := Vector2i(1, 0)
	var c := Vector2i(2, 0)
	var route := DragRoute.begin(board, a)
	assert_eq(route.try_step(b), DragRoute.StepResult.SWAPPED)
	assert_eq(board.orb_at(a), OrbType.Id.ORB_1)
	assert_eq(board.orb_at(b), OrbType.Id.ORB_0)
	assert_eq(board.orb_at(c), OrbType.Id.ORB_2)
	assert_eq(route.try_step(c), DragRoute.StepResult.SWAPPED)
	assert_eq(board.orb_at(a), OrbType.Id.ORB_1)
	assert_eq(board.orb_at(b), OrbType.Id.ORB_2)
	assert_eq(board.orb_at(c), OrbType.Id.ORB_0)
	assert_eq(route.current_cell(), c)
	assert_eq(route.swap_count(), 2)
	assert_eq(route.path_snapshot(), [a, b, c])
	assert_true(route.has_swaps())


func test_revisit_path_and_board() -> void:
	## A→B→C→B : three swaps; path includes revisit; board ends with carried orb at B.
	var board := PuzzleBoard.create(3, 1)
	_fill_row3(board, 0, OrbType.Id.ORB_0, OrbType.Id.ORB_1, OrbType.Id.ORB_2)
	var a := Vector2i(0, 0)
	var b := Vector2i(1, 0)
	var c := Vector2i(2, 0)
	var route := DragRoute.begin(board, a)
	assert_eq(route.try_step(b), DragRoute.StepResult.SWAPPED)
	assert_eq(route.try_step(c), DragRoute.StepResult.SWAPPED)
	assert_eq(route.try_step(b), DragRoute.StepResult.SWAPPED)
	assert_eq(route.swap_count(), 3)
	assert_eq(route.current_cell(), b)
	assert_eq(route.path_snapshot(), [a, b, c, b])
	# After A→B→C→B from a,b,c:
	# A→B: b,a,c ; B→C: b,c,a ; C→B: b,a,c
	assert_eq(board.orb_at(a), OrbType.Id.ORB_1)
	assert_eq(board.orb_at(b), OrbType.Id.ORB_0)
	assert_eq(board.orb_at(c), OrbType.Id.ORB_2)


func test_immediate_backtrack_restores_board() -> void:
	var board := PuzzleBoard.create(3, 1)
	_fill_row3(board, 0, OrbType.Id.ORB_0, OrbType.Id.ORB_1, OrbType.Id.ORB_2)
	var initial := _snap(board)
	var a := Vector2i(0, 0)
	var b := Vector2i(1, 0)
	var route := DragRoute.begin(board, a)
	assert_eq(route.try_step(b), DragRoute.StepResult.SWAPPED)
	assert_eq(route.try_step(a), DragRoute.StepResult.SWAPPED)
	assert_eq(route.swap_count(), 2)
	assert_eq(route.path_snapshot(), [a, b, a])
	assert_eq(route.current_cell(), a)
	assert_eq(_snap(board), initial)


func test_same_cell_jitter_no_op() -> void:
	var board := PuzzleBoard.create(3, 1)
	_fill_row3(board, 0, OrbType.Id.ORB_0, OrbType.Id.ORB_1, OrbType.Id.ORB_2)
	var route := DragRoute.begin(board, Vector2i(0, 0))
	assert_eq(route.try_step(Vector2i(1, 0)), DragRoute.StepResult.SWAPPED)
	var board_before := _snap(board)
	var path_before := route.path_snapshot()
	var count_before := route.swap_count()
	for _i in range(3):
		assert_eq(route.try_step(Vector2i(1, 0)), DragRoute.StepResult.NO_CHANGE_SAME_CELL)
	assert_eq(_snap(board), board_before)
	assert_eq(route.path_snapshot(), path_before)
	assert_eq(route.swap_count(), count_before)
	assert_eq(route.current_cell(), Vector2i(1, 0))


func test_path_snapshot_is_defensive() -> void:
	var board := PuzzleBoard.create(3, 1)
	_fill_row3(board, 0, OrbType.Id.ORB_0, OrbType.Id.ORB_1, OrbType.Id.ORB_2)
	var route := DragRoute.begin(board, Vector2i(0, 0))
	assert_eq(route.try_step(Vector2i(1, 0)), DragRoute.StepResult.SWAPPED)
	var snap := route.path_snapshot()
	assert_eq(snap.size(), 2)
	snap[0] = Vector2i(9, 9)
	snap.append(Vector2i(8, 8))
	assert_eq(route.path_snapshot(), [Vector2i(0, 0), Vector2i(1, 0)])
	assert_eq(route.current_cell(), Vector2i(1, 0))
