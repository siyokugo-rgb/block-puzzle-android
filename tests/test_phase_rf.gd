extends GutTest

## Phase R-F: BoardGeometry / GridInputMapper (UI-free helpers).


func test_pixel_to_cell_corners_edges_outside() -> void:
	var g := BoardGeometry.create(Vector2(10, 20), 10.0, 4, 3)
	# top-left inside
	assert_eq(g.pixel_to_cell(Vector2(10.1, 20.1)), Vector2i(0, 0))
	# bottom-right cell interior
	assert_eq(g.pixel_to_cell(Vector2(49.5, 49.5)), Vector2i(3, 2))
	# edges of first cell
	assert_eq(g.pixel_to_cell(Vector2(10.0, 20.0)), Vector2i(0, 0))
	assert_eq(g.pixel_to_cell(Vector2(19.9, 29.9)), Vector2i(0, 0))
	# outside
	assert_eq(g.pixel_to_cell(Vector2(9.9, 25.0)), Vector2i(-1, -1))
	assert_eq(g.pixel_to_cell(Vector2(50.1, 25.0)), Vector2i(-1, -1))
	assert_eq(g.pixel_to_cell(Vector2(20.0, 19.9)), Vector2i(-1, -1))
	assert_eq(g.pixel_to_cell(Vector2(20.0, 50.1)), Vector2i(-1, -1))
	assert_false(g.contains_pixel(Vector2(0, 0)))
	assert_true(g.contains_pixel(Vector2(10.5, 20.5)))


func test_interpolate_orthogonal_cases() -> void:
	# adjacent
	assert_eq(GridInputMapper.interpolate_orthogonal(Vector2i(0, 0), Vector2i(1, 0)), [Vector2i(1, 0)])
	# horizontal jump
	assert_eq(
		GridInputMapper.interpolate_orthogonal(Vector2i(0, 0), Vector2i(3, 0)),
		[Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	)
	# vertical jump
	assert_eq(
		GridInputMapper.interpolate_orthogonal(Vector2i(1, 0), Vector2i(1, 3)),
		[Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)]
	)
	# diagonal target — tie prefers X first: (0,0)→(2,2) => (1,0)(1,1)(2,1)(2,2)
	assert_eq(
		GridInputMapper.interpolate_orthogonal(Vector2i(0, 0), Vector2i(2, 2)),
		[Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)]
	)
	# reverse
	assert_eq(
		GridInputMapper.interpolate_orthogonal(Vector2i(2, 0), Vector2i(0, 0)),
		[Vector2i(1, 0), Vector2i(0, 0)]
	)
	# same cell
	assert_eq(GridInputMapper.interpolate_orthogonal(Vector2i(1, 1), Vector2i(1, 1)).size(), 0)
	# |dy| > |dx| prefers Y first initially: (0,0)→(1,3)
	# (0,1)(0,2) then |dx|>=|dy| → (1,2) then (1,3)
	assert_eq(
		GridInputMapper.interpolate_orthogonal(Vector2i(0, 0), Vector2i(1, 3)),
		[Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 3)]
	)


func test_pointer_ownership_touch_blocks_mouse() -> void:
	var m := GridInputMapper.new()
	assert_true(m.begin_touch(0))
	assert_false(m.begin_mouse())
	assert_false(m.begin_touch(1))
	assert_true(m.accepts_touch(0))
	assert_false(m.accepts_touch(1))
	assert_false(m.accepts_mouse())
	m.clear()
	assert_true(m.begin_mouse())
	assert_true(m.accepts_mouse())
	assert_false(m.begin_touch(0))


func test_session_press_step_release_integration() -> void:
	var session := PuzzleSession.create_score_attack(6, 6, 42, 60000)
	assert_true(session.is_valid())
	# Find matching swap offline then drive session.
	var snap: Array = session.board_snapshot()
	var board := PuzzleBoard.create(6, 6)
	for y in range(6):
		var row: Array = snap[y]
		for x in range(6):
			var id: int = row[x]
			if id >= 0:
				assert_true(board.set_orb(Vector2i(x, y), id))
	var found := false
	var from_cell := Vector2i.ZERO
	var to_cell := Vector2i.ZERO
	for y in range(6):
		for x in range(6):
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var a := Vector2i(x, y)
				var b: Vector2i = a + d
				if not board.in_bounds(b) or not board.has_orb(a) or not board.has_orb(b):
					continue
				assert_true(board.swap(a, b))
				var has := MatchResolver.detect(board).has_matches()
				assert_true(board.swap(a, b))
				if has:
					from_cell = a
					to_cell = b
					found = true
					break
			if found:
				break
		if found:
			break
	assert_true(found)
	assert_true(session.begin_drag(from_cell))
	var steps := GridInputMapper.interpolate_orthogonal(from_cell, to_cell)
	assert_eq(steps.size(), 1)
	assert_eq(session.step_drag(steps[0]), DragRoute.StepResult.SWAPPED)
	var result := session.release_drag()
	assert_true(result.is_success())
	assert_gt(session.score(), 0)

	# Non-matching: begin + release without swap → 0 score.
	var s2 := PuzzleSession.create_score_attack(6, 6, 42, 60000)
	var before := s2.score()
	assert_true(s2.begin_drag(Vector2i(0, 0)))
	var r0 := s2.release_drag()
	assert_true(r0.is_success())
	assert_eq(s2.score(), before)

	# Timer expiry blocks input.
	s2.advance_time(60000)
	assert_eq(s2.state(), PuzzleSession.State.SESSION_OVER)
	assert_false(s2.begin_drag(Vector2i(0, 0)))


func test_interpolate_then_session_skips_no_cells() -> void:
	## Fast jump (0,0)→(3,0) must produce 3 adjacent session steps.
	var session := PuzzleSession.create_score_attack(6, 6, 7, 60000)
	assert_true(session.begin_drag(Vector2i(0, 0)))
	var steps := GridInputMapper.interpolate_orthogonal(Vector2i(0, 0), Vector2i(3, 0))
	assert_eq(steps, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])
	for c in steps:
		var r := session.step_drag(c)
		assert_true(r == DragRoute.StepResult.SWAPPED or r == DragRoute.StepResult.REJECTED)
		if r == DragRoute.StepResult.REJECTED:
			break
	assert_eq(session.active_drag_current_cell(), Vector2i(3, 0))
	assert_eq(session.active_drag_swap_count(), 3)
