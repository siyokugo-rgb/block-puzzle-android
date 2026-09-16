extends GutTest

## Phase R-E: PuzzleSession / timer / provisional Score integration.


func _session(
	width: int = 6,
	height: int = 6,
	seed_value: int = 42,
	duration_ms: int = 60000,
	max_cascade_steps: int = CascadeResolver.MAX_CASCADE_STEPS
) -> PuzzleSession:
	return PuzzleSession.create_score_attack(
		width, height, seed_value, duration_ms, max_cascade_steps
	)


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


## Find one orthogonal swap that creates a match. Returns [from, to] or empty.
func _find_matching_swap(session: PuzzleSession) -> Array:
	var snap: Array = session.board_snapshot()
	var board := _board_from_snapshot(snap)
	var w := board.width()
	var h := board.height()
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	for y in range(h):
		for x in range(w):
			var a := Vector2i(x, y)
			if not board.has_orb(a):
				continue
			for d in dirs:
				var b: Vector2i = a + d
				if not board.in_bounds(b) or not board.has_orb(b):
					continue
				assert_true(board.swap(a, b))
				var match_result := MatchResolver.detect(board)
				assert_true(board.swap(a, b)) # restore
				if match_result.has_matches():
					return [a, b]
	return []


func _play_matching_move(session: PuzzleSession) -> SessionMoveResult:
	var pair: Array = _find_matching_swap(session)
	assert_eq(pair.size(), 2, "expected a matching swap on stable board")
	var a: Vector2i = pair[0]
	var b: Vector2i = pair[1]
	assert_true(session.begin_drag(a))
	assert_eq(session.step_drag(b), DragRoute.StepResult.SWAPPED)
	return session.release_drag()


# --- A. construction ---


func test_construction_valid_and_invalid() -> void:
	var s := _session(6, 6, 42, 60000)
	assert_true(s.is_valid())
	assert_eq(s.state(), PuzzleSession.State.IDLE)
	assert_eq(s.score(), 0)
	assert_eq(s.remaining_ms(), 60000)
	assert_eq(s.board_width(), 6)
	assert_eq(s.board_height(), 6)
	var opening := MatchResolver.detect(_board_from_snapshot(s.board_snapshot()))
	assert_true(opening.is_valid())
	assert_false(opening.has_matches())

	assert_false(_session(0, 6, 1, 1000).is_valid())
	assert_eq(_session(0, 6, 1, 1000).state(), PuzzleSession.State.INVALID)
	assert_false(_session(6, 0, 1, 1000).is_valid())
	assert_false(_session(6, 6, 1, 0).is_valid())
	assert_false(_session(6, 6, 1, -5).is_valid())

	var a := _session(6, 6, 99, 45000)
	var b := _session(6, 6, 99, 45000)
	assert_eq(a.board_snapshot(), b.board_snapshot())
	assert_eq(a.remaining_ms(), 45000)


# --- B. begin drag ---


func test_begin_drag_success_and_failures() -> void:
	var s := _session()
	var before := s.board_snapshot()
	var start := Vector2i(0, 0)
	assert_true(s.orb_at(start) >= 0)
	assert_true(s.begin_drag(start))
	assert_eq(s.state(), PuzzleSession.State.ROUTE_DRAG)
	assert_eq(s.board_snapshot(), before)
	assert_eq(s.active_drag_current_cell(), start)
	assert_eq(s.active_drag_swap_count(), 0)

	var s2 := _session()
	var snap2 := s2.board_snapshot()
	assert_false(s2.begin_drag(Vector2i(99, 0)))
	assert_eq(s2.state(), PuzzleSession.State.IDLE)
	assert_eq(s2.board_snapshot(), snap2)

	# Empty cell: use a board position that is empty — stable fill has no empties.
	# OOB already covered. Terminal reject:
	s2.advance_time(60000)
	assert_eq(s2.state(), PuzzleSession.State.SESSION_OVER)
	assert_false(s2.begin_drag(Vector2i(0, 0)))


func test_begin_drag_rejects_when_not_idle() -> void:
	var s := _session()
	assert_true(s.begin_drag(Vector2i(0, 0)))
	assert_false(s.begin_drag(Vector2i(1, 0)))
	assert_eq(s.state(), PuzzleSession.State.ROUTE_DRAG)


# --- C. route integration ---


func test_route_steps_revisit_and_read_api() -> void:
	var s := _session(3, 3, 7, 60000)
	# Ensure neighbors exist via snapshot search of any adjacent pair with orbs.
	var start := Vector2i(0, 0)
	var mid := Vector2i(1, 0)
	if s.orb_at(start) < 0 or s.orb_at(mid) < 0:
		start = Vector2i(1, 1)
		mid = Vector2i(2, 1)
	assert_true(s.orb_at(start) >= 0)
	assert_true(s.orb_at(mid) >= 0)
	assert_true(s.begin_drag(start))
	assert_eq(s.step_drag(mid), DragRoute.StepResult.SWAPPED)
	assert_eq(s.active_drag_swap_count(), 1)
	assert_eq(s.active_drag_current_cell(), mid)
	# backtrack
	assert_eq(s.step_drag(start), DragRoute.StepResult.SWAPPED)
	assert_eq(s.active_drag_swap_count(), 2)
	var path := s.active_drag_path_snapshot()
	assert_eq(path.size(), 3)
	assert_eq(path[0], start)
	assert_eq(path[1], mid)
	assert_eq(path[2], start)
	# jitter
	assert_eq(s.step_drag(start), DragRoute.StepResult.NO_CHANGE_SAME_CELL)
	assert_eq(s.active_drag_swap_count(), 2)


# --- D / E. release ---


func test_release_zero_swap_returns_idle_no_score() -> void:
	var s := _session()
	var before := s.board_snapshot()
	assert_true(s.begin_drag(Vector2i(0, 0)))
	var result := s.release_drag()
	assert_true(result.is_success())
	assert_false(result.is_error())
	assert_eq(result.move_score(), 0)
	assert_eq(s.score(), 0)
	assert_eq(s.state(), PuzzleSession.State.IDLE)
	assert_eq(s.board_snapshot(), before)
	assert_false(s.has_active_drag())


func test_release_with_swap_scores_and_returns_idle() -> void:
	var s := _session(6, 6, 42, 60000)
	var before_score := s.score()
	var result := _play_matching_move(s)
	assert_true(result.is_success())
	assert_false(result.is_error())
	assert_false(result.is_session_over())
	assert_eq(s.state(), PuzzleSession.State.IDLE)
	assert_gt(s.score(), before_score)
	assert_eq(s.score(), result.score_after())
	assert_eq(result.move_score(), s.score() - before_score)
	# Final board match-stable.
	var detect := MatchResolver.detect(_board_from_snapshot(s.board_snapshot()))
	assert_false(detect.has_matches())


# --- F. Score examples ---


func test_compute_move_score_examples() -> void:
	var r1 := PuzzleSession.compute_move_score([3])
	assert_true(r1["ok"])
	assert_eq(r1["value"], 300)

	var r2 := PuzzleSession.compute_move_score([3, 3])
	assert_true(r2["ok"])
	assert_eq(r2["value"], 675)

	var r3 := PuzzleSession.compute_move_score([5, 3, 4])
	assert_true(r3["ok"])
	assert_eq(r3["value"], 1475)

	var empty := PuzzleSession.compute_move_score([])
	assert_true(empty["ok"])
	assert_eq(empty["value"], 0)


# --- G. Score accumulation ---


func test_score_accumulates_across_moves() -> void:
	var s := _session(6, 6, 11, 60000)
	var r1 := _play_matching_move(s)
	assert_true(r1.is_success())
	var after1 := s.score()
	assert_eq(after1, r1.move_score())
	var r2 := _play_matching_move(s)
	assert_true(r2.is_success())
	assert_eq(s.score(), after1 + r2.move_score())


# --- H. Score overflow ---


func test_checked_arithmetic_and_overflow_paths() -> void:
	var mul_ok := PuzzleSession.checked_mul(3, 100)
	assert_true(mul_ok["ok"])
	assert_eq(mul_ok["value"], 300)

	var mul_ov := PuzzleSession.checked_mul(PuzzleSession.SCORE_MAX, 2)
	assert_false(mul_ov["ok"])

	var add_ok := PuzzleSession.checked_add(10, 20)
	assert_true(add_ok["ok"])
	assert_eq(add_ok["value"], 30)

	var add_ov := PuzzleSession.checked_add(PuzzleSession.SCORE_MAX, 1)
	assert_false(add_ov["ok"])

	# Move accumulation overflow: huge cleared cells.
	var huge := PuzzleSession.compute_move_score([PuzzleSession.SCORE_MAX])
	assert_false(huge["ok"])

	# session_score + move_score overflow via the same checked_add commit uses.
	var near := PuzzleSession.checked_add(PuzzleSession.SCORE_MAX - 100, 300)
	assert_false(near["ok"])

	# Zero factors ok.
	assert_true(PuzzleSession.checked_mul(0, PuzzleSession.SCORE_MAX)["ok"])
	assert_eq(PuzzleSession.checked_mul(0, PuzzleSession.SCORE_MAX)["value"], 0)

	# Negative inputs rejected (fail-closed).
	assert_false(PuzzleSession.checked_mul(-1, 2)["ok"])
	assert_false(PuzzleSession.checked_add(-1, 2)["ok"])


func test_session_score_plus_move_score_overflow_integration() -> void:
	## Direct session commit path: prior score near SCORE_MAX, stable cascade move ≥300.
	## ERROR cause is score commit overflow — not cascade failure (default max steps).
	var s := _session(6, 6, 42, 60000)
	assert_eq(s.state(), PuzzleSession.State.IDLE)
	var prior := PuzzleSession.SCORE_MAX - 100
	s._score = prior
	assert_eq(s.score(), prior)
	var remaining_before := s.remaining_ms()

	var pair: Array = _find_matching_swap(s)
	assert_eq(pair.size(), 2)
	var a: Vector2i = pair[0]
	var b: Vector2i = pair[1]
	assert_true(s.begin_drag(a))
	assert_eq(s.step_drag(b), DragRoute.StepResult.SWAPPED)
	var result := s.release_drag()

	# Cascade completed enough to produce a move_score ≥ 300 (single step min clear is 3).
	assert_true(result.is_error())
	assert_false(result.is_success())
	assert_eq(s.state(), PuzzleSession.State.ERROR)
	assert_eq(s.score(), prior)
	assert_ne(s.score(), PuzzleSession.SCORE_MAX)
	assert_true(s.score() >= 0)
	assert_eq(s.remaining_ms(), remaining_before)
	assert_true(s.remaining_ms() >= 0)

	# Input blocked after ERROR.
	assert_false(s.begin_drag(Vector2i(0, 0)))
	assert_eq(s.step_drag(Vector2i(1, 0)), DragRoute.StepResult.REJECTED)
	var ignored := s.release_drag()
	assert_false(ignored.is_success())
	assert_false(ignored.is_error()) # ignored() — not a successful move


# --- I. Timer IDLE ---


func test_timer_idle_ticks_expiry_and_noops() -> void:
	var s := _session(6, 6, 1, 1000)
	s.advance_time(-10)
	assert_eq(s.remaining_ms(), 1000)
	assert_eq(s.state(), PuzzleSession.State.IDLE)
	s.advance_time(0)
	assert_eq(s.remaining_ms(), 1000)
	s.advance_time(400)
	assert_eq(s.remaining_ms(), 600)
	s.advance_time(600)
	assert_eq(s.remaining_ms(), 0)
	assert_eq(s.state(), PuzzleSession.State.SESSION_OVER)
	assert_eq(s.score(), 0)
	# repeated tick after expiry
	s.advance_time(50)
	assert_eq(s.remaining_ms(), 0)
	assert_eq(s.state(), PuzzleSession.State.SESSION_OVER)

	var s2 := _session(6, 6, 1, 100)
	s2.advance_time(250)
	assert_eq(s2.remaining_ms(), 0)
	assert_eq(s2.state(), PuzzleSession.State.SESSION_OVER)


# --- J. Timer drag no swap expiry ---


func test_timer_drag_no_swap_expiry() -> void:
	var s := _session(6, 6, 2, 500)
	assert_true(s.begin_drag(Vector2i(0, 0)))
	var before := s.board_snapshot()
	s.advance_time(500)
	assert_eq(s.state(), PuzzleSession.State.SESSION_OVER)
	assert_eq(s.score(), 0)
	assert_eq(s.board_snapshot(), before)
	assert_false(s.has_active_drag())


# --- K. Timer drag with swap expiry ---


func test_timer_drag_with_swap_forced_release_scores() -> void:
	var s := _session(6, 6, 42, 5000)
	var pair: Array = _find_matching_swap(s)
	assert_eq(pair.size(), 2)
	var a: Vector2i = pair[0]
	var b: Vector2i = pair[1]
	assert_true(s.begin_drag(a))
	assert_eq(s.step_drag(b), DragRoute.StepResult.SWAPPED)
	assert_eq(s.active_drag_swap_count(), 1)
	s.advance_time(5000)
	assert_eq(s.state(), PuzzleSession.State.SESSION_OVER)
	assert_gt(s.score(), 0)
	assert_false(s.has_active_drag())
	assert_false(MatchResolver.detect(_board_from_snapshot(s.board_snapshot())).has_matches())


# --- L. RESOLVING pause ---


func test_resolving_does_not_consume_timer() -> void:
	var s := _session(6, 6, 42, 60000)
	var before := s.remaining_ms()
	var result := _play_matching_move(s)
	assert_true(result.is_success())
	assert_eq(s.remaining_ms(), before)
	# Non-ticking states ignore advance_time.
	s.advance_time(60000)
	assert_eq(s.state(), PuzzleSession.State.SESSION_OVER)
	var rem := s.remaining_ms()
	s.advance_time(100)
	assert_eq(s.remaining_ms(), rem)


# --- M. Cascade error ---


func test_cascade_guard_error_blocks_input() -> void:
	var s := _session(6, 6, 42, 60000, 0)
	var prior := s.score()
	var result := _play_matching_move(s)
	assert_true(result.is_error())
	assert_eq(s.state(), PuzzleSession.State.ERROR)
	assert_eq(s.score(), prior)
	assert_false(s.begin_drag(Vector2i(0, 0)))
	assert_eq(s.release_drag().is_success(), false)


# --- N. RNG continuity / reproducibility ---


func test_same_seed_same_inputs_same_outcomes() -> void:
	var a := _run_repro_session(123)
	var b := _run_repro_session(123)
	assert_eq(a["board"], b["board"])
	assert_eq(a["score"], b["score"])
	assert_eq(a["remaining"], b["remaining"])
	assert_eq(a["move"], b["move"])
	assert_eq(a["steps"], b["steps"])
	assert_eq(a["state"], b["state"])


func _run_repro_session(seed_value: int) -> Dictionary:
	var s := _session(6, 6, seed_value, 60000)
	var pair: Array = _find_matching_swap(s)
	assert_eq(pair.size(), 2)
	var cell_a: Vector2i = pair[0]
	var cell_b: Vector2i = pair[1]
	assert_true(s.begin_drag(cell_a))
	assert_eq(s.step_drag(cell_b), DragRoute.StepResult.SWAPPED)
	s.advance_time(10)
	var result := s.release_drag()
	return {
		"board": s.board_snapshot(),
		"score": s.score(),
		"remaining": s.remaining_ms(),
		"move": result.move_score(),
		"steps": result.cascade_step_count(),
		"state": s.state(),
	}


func test_active_drag_defaults_when_idle() -> void:
	var s := _session()
	assert_false(s.has_active_drag())
	assert_eq(s.active_drag_current_cell(), Vector2i(-1, -1))
	assert_eq(s.active_drag_path_snapshot().size(), 0)
	assert_eq(s.active_drag_swap_count(), 0)
	assert_eq(s.step_drag(Vector2i(0, 0)), DragRoute.StepResult.REJECTED)
