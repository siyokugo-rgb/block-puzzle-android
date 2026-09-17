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


# --- Dual Timer (Session + Move) ---


func _board_from_snapshot(snap: Array) -> PuzzleBoard:
	var h: int = snap.size()
	assert_gt(h, 0)
	var w: int = (snap[0] as Array).size()
	var board := PuzzleBoard.create(w, h)
	for y in range(h):
		var row: Array = snap[y]
		for x in range(w):
			var id: int = row[x]
			if id >= 0:
				assert_true(board.set_orb(Vector2i(x, y), id))
	return board


func _find_matching_swap(session: PuzzleSession) -> Array:
	var snap: Array = session.board_snapshot()
	var board := _board_from_snapshot(snap)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	for y in range(board.height()):
		for x in range(board.width()):
			var a := Vector2i(x, y)
			if not board.has_orb(a):
				continue
			for d in dirs:
				var b: Vector2i = a + d
				if not board.in_bounds(b) or not board.has_orb(b):
					continue
				assert_true(board.swap(a, b))
				var has := MatchResolver.detect(board).has_matches()
				assert_true(board.swap(a, b))
				if has:
					return [a, b]
	return []


func test_dual_begin_drag_sets_move_remaining_2000() -> void:
	var s := PuzzleSession.create_score_attack(6, 6, 42, 60000)
	assert_false(s.has_active_move_timer())
	assert_eq(s.move_remaining_ms(), 0)
	assert_true(s.begin_drag(Vector2i(0, 0)))
	assert_eq(s.state(), PuzzleSession.State.ROUTE_DRAG)
	assert_true(s.has_active_move_timer())
	assert_eq(s.move_remaining_ms(), PuzzleSession.MOVE_DURATION_MS)
	assert_eq(s.move_remaining_ms(), 2000)


func test_dual_idle_session_ticks_move_inactive() -> void:
	var s := PuzzleSession.create_score_attack(6, 6, 1, 5000)
	assert_eq(s.state(), PuzzleSession.State.IDLE)
	assert_false(s.has_active_move_timer())
	assert_eq(s.move_remaining_ms(), 0)
	s.advance_time(1000)
	assert_eq(s.remaining_ms(), 4000)
	assert_eq(s.state(), PuzzleSession.State.IDLE)
	assert_false(s.has_active_move_timer())
	assert_eq(s.move_remaining_ms(), 0)


func test_dual_route_drag_ticks_both_timers() -> void:
	var s := PuzzleSession.create_score_attack(6, 6, 42, 60000)
	assert_true(s.begin_drag(Vector2i(0, 0)))
	assert_eq(s.move_remaining_ms(), 2000)
	s.advance_time(500)
	assert_eq(s.remaining_ms(), 59500)
	assert_eq(s.move_remaining_ms(), 1500)
	s.advance_time(500)
	assert_eq(s.remaining_ms(), 59000)
	assert_eq(s.move_remaining_ms(), 1000)
	assert_eq(s.state(), PuzzleSession.State.ROUTE_DRAG)


func test_dual_hold_same_cell_still_decrements_and_expires() -> void:
	var s := PuzzleSession.create_score_attack(6, 6, 42, 60000)
	assert_true(s.begin_drag(Vector2i(0, 0)))
	assert_eq(s.active_drag_swap_count(), 0)
	# Same-cell hold: no step_drag, Move Timer still ticks.
	s.advance_time(500)
	assert_eq(s.active_drag_swap_count(), 0)
	assert_eq(s.active_drag_current_cell(), Vector2i(0, 0))
	assert_eq(s.move_remaining_ms(), 1500)
	assert_eq(s.remaining_ms(), 59500)
	# Full 2000ms hold with zero swaps → expiry without cascade.
	s.advance_time(1500)
	assert_eq(s.last_end_reason(), "move_expiry")
	assert_eq(s.state(), PuzzleSession.State.IDLE)
	assert_eq(s.score(), 0)
	assert_false(s.has_active_drag())
	assert_false(s.has_active_move_timer())


func test_dual_move_expiry_with_swaps_resolves_to_idle() -> void:
	var s := PuzzleSession.create_score_attack(6, 6, 42, 60000)
	var pair: Array = _find_matching_swap(s)
	assert_eq(pair.size(), 2)
	assert_true(s.begin_drag(pair[0]))
	assert_eq(s.step_drag(pair[1]), DragRoute.StepResult.SWAPPED)
	assert_eq(s.active_drag_swap_count(), 1)
	var before_score := s.score()
	s.advance_time(PuzzleSession.MOVE_DURATION_MS)
	assert_eq(s.last_end_reason(), "move_expiry")
	assert_eq(s.state(), PuzzleSession.State.IDLE)
	assert_gt(s.score(), before_score)
	assert_false(s.has_active_drag())
	assert_false(s.has_active_move_timer())
	assert_eq(s.move_remaining_ms(), 0)
	assert_eq(s.remaining_ms(), 60000 - PuzzleSession.MOVE_DURATION_MS)


func test_dual_move_expiry_zero_swaps_no_cascade() -> void:
	var s := PuzzleSession.create_score_attack(6, 6, 42, 60000)
	var before := s.board_snapshot()
	var before_score := s.score()
	assert_true(s.begin_drag(Vector2i(0, 0)))
	s.advance_time(PuzzleSession.MOVE_DURATION_MS)
	assert_eq(s.last_end_reason(), "move_expiry")
	assert_eq(s.state(), PuzzleSession.State.IDLE)
	assert_eq(s.score(), before_score)
	assert_eq(s.board_snapshot(), before)
	assert_false(s.has_active_drag())
	assert_false(s.has_active_move_timer())


func test_dual_session_expiry_first_forced_final_move() -> void:
	## Session 1000ms < Move 2000ms → Session expiry wins during drag with swaps.
	var s := PuzzleSession.create_score_attack(6, 6, 42, 1000)
	var pair: Array = _find_matching_swap(s)
	assert_eq(pair.size(), 2)
	assert_true(s.begin_drag(pair[0]))
	assert_eq(s.step_drag(pair[1]), DragRoute.StepResult.SWAPPED)
	s.advance_time(1000)
	assert_eq(s.remaining_ms(), 0)
	assert_eq(s.last_end_reason(), "session_expiry")
	assert_eq(s.state(), PuzzleSession.State.SESSION_OVER)
	assert_gt(s.score(), 0)
	assert_false(s.has_active_drag())
	assert_false(s.has_active_move_timer())


func test_dual_simultaneous_session_and_move_expiry() -> void:
	## Same tick hits both 0 (2000/2000) → Session expiry is final; one forced release only.
	var s := PuzzleSession.create_score_attack(6, 6, 42, 2000)
	var pair: Array = _find_matching_swap(s)
	assert_eq(pair.size(), 2)
	assert_true(s.begin_drag(pair[0]))
	assert_eq(s.step_drag(pair[1]), DragRoute.StepResult.SWAPPED)
	var score_before := s.score()
	s.advance_time(2000)
	assert_eq(s.remaining_ms(), 0)
	assert_eq(s.move_remaining_ms(), 0)
	assert_eq(s.last_end_reason(), "session_expiry")
	assert_eq(s.state(), PuzzleSession.State.SESSION_OVER)
	assert_gt(s.score(), score_before)
	# Idempotent: further ticks do not re-resolve.
	var score_after := s.score()
	s.advance_time(100)
	assert_eq(s.score(), score_after)
	assert_eq(s.state(), PuzzleSession.State.SESSION_OVER)


func test_dual_resolving_pauses_both_timers() -> void:
	var s := PuzzleSession.create_score_attack(6, 6, 42, 60000)
	assert_true(s.begin_drag(Vector2i(0, 0)))
	s.advance_time(500)
	assert_eq(s.remaining_ms(), 59500)
	assert_eq(s.move_remaining_ms(), 1500)
	# Sync RESOLVING is not sticky; force state to assert pause contract.
	s._state = PuzzleSession.State.RESOLVING
	s.advance_time(2000)
	assert_eq(s.remaining_ms(), 59500)
	assert_eq(s._move_remaining_ms, 1500)
	assert_eq(s.state(), PuzzleSession.State.RESOLVING)

	# Normal matching release also must not consume Session during resolve.
	var s2 := PuzzleSession.create_score_attack(6, 6, 42, 60000)
	var pair: Array = _find_matching_swap(s2)
	assert_eq(pair.size(), 2)
	assert_true(s2.begin_drag(pair[0]))
	assert_eq(s2.step_drag(pair[1]), DragRoute.StepResult.SWAPPED)
	var rem := s2.remaining_ms()
	var result := s2.release_drag()
	assert_true(result.is_success())
	assert_eq(s2.remaining_ms(), rem)
	assert_eq(s2.state(), PuzzleSession.State.IDLE)
	assert_false(s2.has_active_move_timer())


func test_dual_next_drag_resets_move_timer_to_2000() -> void:
	var s := PuzzleSession.create_score_attack(6, 6, 42, 60000)
	assert_true(s.begin_drag(Vector2i(0, 0)))
	s.advance_time(500)
	assert_eq(s.move_remaining_ms(), 1500)
	assert_true(s.release_drag().is_success())
	assert_eq(s.state(), PuzzleSession.State.IDLE)
	assert_false(s.has_active_move_timer())
	assert_true(s.begin_drag(Vector2i(1, 0)))
	assert_eq(s.move_remaining_ms(), 2000)
	assert_eq(s.last_end_reason(), "")


func test_dual_negative_and_zero_elapsed_noop() -> void:
	var s := PuzzleSession.create_score_attack(6, 6, 42, 60000)
	assert_true(s.begin_drag(Vector2i(0, 0)))
	s.advance_time(-5)
	assert_eq(s.remaining_ms(), 60000)
	assert_eq(s.move_remaining_ms(), 2000)
	s.advance_time(0)
	assert_eq(s.remaining_ms(), 60000)
	assert_eq(s.move_remaining_ms(), 2000)
	s.advance_time(100)
	assert_eq(s.remaining_ms(), 59900)
	assert_eq(s.move_remaining_ms(), 1900)


# --- Pre-session READY / START helpers (UI-only; no domain READY state) ---


func test_ready_launch_helpers_and_start_flow() -> void:
	var view := PuzzleGameView.new()
	add_child_autofree(view)
	# _ready → awaiting start, no session, default 60s.
	assert_true(view.is_awaiting_start())
	assert_false(view.has_playable_session())
	assert_false(view.board_input_enabled())
	assert_eq(view.selected_duration_ms(), 60000)
	assert_eq(view.selected_duration_ms(), PuzzleGameView.DEFAULT_DURATION_MS)
	assert_null(view._session)

	# Duration selection alone does not start.
	view.select_duration(45000)
	assert_eq(view.selected_duration_ms(), 45000)
	assert_true(view.is_awaiting_start())
	assert_null(view._session)
	assert_false(view.board_input_enabled())

	view.select_duration(90000)
	assert_eq(view.selected_duration_ms(), 90000)
	assert_true(view.is_awaiting_start())

	# START creates session; timer full; Move inactive; board input enabled in IDLE.
	# R-F baseline uses Obstacle OFF (ROCK default would play opening drop).
	view.select_obstacle_mode(PuzzleSession.ObstacleMode.OFF)
	view.select_duration(60000)
	view.start_selected_session()
	assert_false(view.is_awaiting_start())
	assert_true(view.has_playable_session())
	assert_true(view.board_input_enabled())
	assert_eq(view._session.state(), PuzzleSession.State.IDLE)
	assert_eq(view._session.remaining_ms(), 60000)
	assert_eq(view._session.score(), 0)
	assert_false(view._session.has_active_move_timer())

	# After START, Session ticks; Move still inactive while IDLE.
	view._session.advance_time(1000)
	assert_eq(view._session.remaining_ms(), 59000)
	assert_false(view._session.has_active_move_timer())

	# Restart with selected duration resets score / Move / timer.
	view.select_duration(45000)
	assert_eq(view.selected_duration_ms(), 45000)
	# Selection alone still does not replace session.
	assert_eq(view._session.remaining_ms(), 59000)
	view.restart_selected_session()
	assert_true(view.has_playable_session())
	assert_eq(view._session.remaining_ms(), 45000)
	assert_eq(view._session.score(), 0)
	assert_false(view._session.has_active_move_timer())
	assert_eq(view._session.state(), PuzzleSession.State.IDLE)
	assert_true(view.board_input_enabled())


func test_ready_rejects_invalid_duration_selection() -> void:
	var view := PuzzleGameView.new()
	add_child_autofree(view)
	assert_eq(view.selected_duration_ms(), 60000)
	view.select_duration(12345)
	assert_eq(view.selected_duration_ms(), 60000)
	assert_true(view.is_awaiting_start())

