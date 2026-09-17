extends GutTest

## Phase R-G: ROCK obstacle vertical slice.


func _board(w: int = 6, h: int = 6) -> PuzzleBoard:
	return PuzzleBoard.create(w, h)


func _place_orb(board: PuzzleBoard, x: int, y: int, orb: int) -> void:
	assert_true(board.set_orb(Vector2i(x, y), orb))


# --- A. PuzzleCell ---


func test_cell_rock_clears_orb_and_forbids_orb() -> void:
	var cell := PuzzleCell.with_orb(OrbType.Id.ORB_1)
	assert_ne(cell, null)
	assert_true(cell.has_orb())
	assert_true(cell.set_rock())
	assert_true(cell.is_rock())
	assert_false(cell.has_orb())
	assert_eq(cell.orb_id(), -1)
	assert_false(cell.is_empty())
	assert_false(cell.set_orb(OrbType.Id.ORB_0))
	assert_false(cell.has_orb())
	# Invalid obstacle rejected; ROCK retained.
	assert_false(cell.set_obstacle(99))
	assert_true(cell.is_rock())
	var copy := cell.duplicate_cell()
	assert_true(copy.is_rock())
	assert_false(copy.has_orb())
	copy.clear_obstacle()
	assert_true(copy.is_empty())
	assert_true(cell.is_rock()) # defensive


func test_cell_none_obstacle_and_invalid_with_orb() -> void:
	assert_eq(PuzzleCell.with_orb(-1), null)
	var empty := PuzzleCell.empty()
	assert_true(empty.is_empty())
	assert_true(empty.set_obstacle(ObstacleType.Id.NONE))
	assert_true(empty.is_empty())


# --- B. PuzzleBoard ---


func test_board_rock_apis_and_set_orb_reject() -> void:
	var board := _board(3, 3)
	assert_true(board.set_orb(Vector2i(0, 0), OrbType.Id.ORB_2))
	assert_true(board.set_rock(Vector2i(0, 0)))
	assert_true(board.is_rock(Vector2i(0, 0)))
	assert_true(board.has_obstacle(Vector2i(0, 0)))
	assert_eq(board.orb_at(Vector2i(0, 0)), -1)
	assert_false(board.is_empty(Vector2i(0, 0)))
	assert_false(board.set_orb(Vector2i(0, 0), OrbType.Id.ORB_1))
	assert_eq(board.rock_count(), 1)
	var snap := board.snapshot_obstacle_types()
	assert_eq(snap[0][0], ObstacleType.Id.ROCK)
	snap[0][0] = ObstacleType.Id.NONE
	assert_eq(board.obstacle_at(Vector2i(0, 0)), ObstacleType.Id.ROCK)
	assert_true(board.clear_obstacle(Vector2i(0, 0)))
	assert_true(board.is_empty(Vector2i(0, 0)))
	assert_eq(board.rock_count(), 0)


# --- C. Drag ---


func test_drag_rejects_rock_start_and_destination() -> void:
	var board := _board(3, 3)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	_place_orb(board, 1, 0, OrbType.Id.ORB_1)
	assert_true(board.set_rock(Vector2i(2, 0)))
	assert_eq(DragRoute.begin(board, Vector2i(2, 0)), null)
	var route := DragRoute.begin(board, Vector2i(0, 0))
	assert_ne(route, null)
	assert_eq(route.try_step(Vector2i(1, 0)), DragRoute.StepResult.SWAPPED)
	# Destination ROCK rejected; route atomic at (1,0).
	assert_eq(route.try_step(Vector2i(2, 0)), DragRoute.StepResult.REJECTED)
	assert_eq(route.current_cell(), Vector2i(1, 0))
	assert_eq(route.swap_count(), 1)
	assert_true(board.is_rock(Vector2i(2, 0)))
	assert_false(board.swap(Vector2i(1, 0), Vector2i(2, 0)))


# --- D. Match breaks ---


func test_rock_breaks_horizontal_and_vertical_runs() -> void:
	var board := _board(5, 1)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	_place_orb(board, 1, 0, OrbType.Id.ORB_0)
	assert_true(board.set_rock(Vector2i(2, 0)))
	_place_orb(board, 3, 0, OrbType.Id.ORB_0)
	_place_orb(board, 4, 0, OrbType.Id.ORB_0)
	assert_false(MatchResolver.detect(board).has_matches())

	var vboard := _board(1, 5)
	_place_orb(vboard, 0, 0, OrbType.Id.ORB_1)
	_place_orb(vboard, 0, 1, OrbType.Id.ORB_1)
	assert_true(vboard.set_rock(Vector2i(0, 2)))
	_place_orb(vboard, 0, 3, OrbType.Id.ORB_1)
	_place_orb(vboard, 0, 4, OrbType.Id.ORB_1)
	assert_false(MatchResolver.detect(vboard).has_matches())


func test_diagonal_rock_not_damaged_by_match() -> void:
	var board := _board(3, 3)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	_place_orb(board, 1, 0, OrbType.Id.ORB_0)
	_place_orb(board, 2, 0, OrbType.Id.ORB_0)
	# ROCK at (2,2): not orthogonally adjacent to matched row y=0.
	assert_true(board.set_rock(Vector2i(2, 2)))
	var matched := MatchResolver.detect(board).matched_cells_snapshot()
	assert_true(matched.size() >= 3)
	var rocks := CascadeResolver.collect_adjacent_rocks(board, matched)
	assert_eq(rocks.size(), 0)
	assert_true(board.is_rock(Vector2i(2, 2)))


# --- E. Destruction ---


func test_adjacent_match_destroys_rocks_once_and_simultaneous() -> void:
	var board := _board(4, 3)
	# Horizontal match on row 1: AAA
	_place_orb(board, 0, 1, OrbType.Id.ORB_2)
	_place_orb(board, 1, 1, OrbType.Id.ORB_2)
	_place_orb(board, 2, 1, OrbType.Id.ORB_2)
	# ROCK above middle (touched by one match cell) and ROCK below two cells (multi-adjacent → once)
	assert_true(board.set_rock(Vector2i(1, 0)))
	assert_true(board.set_rock(Vector2i(1, 2)))
	assert_true(board.set_rock(Vector2i(0, 2))) # also adjacent to (0,1)
	var gen := OrbGenerator.create()
	gen.set_seed(7)
	var result := CascadeResolver.resolve(board, gen)
	assert_true(result.is_stable())
	assert_eq(board.rock_count(), 0)
	assert_eq(result.total_rocks_destroyed(), 3)
	assert_eq(result.rocks_destroyed_per_step_snapshot()[0], 3)


func test_vertical_match_destroys_side_rock() -> void:
	var board := _board(2, 3)
	_place_orb(board, 0, 0, OrbType.Id.ORB_3)
	_place_orb(board, 0, 1, OrbType.Id.ORB_3)
	_place_orb(board, 0, 2, OrbType.Id.ORB_3)
	assert_true(board.set_rock(Vector2i(1, 1)))
	var gen := OrbGenerator.create()
	gen.set_seed(3)
	var result := CascadeResolver.resolve(board, gen)
	assert_true(result.is_stable())
	assert_false(board.is_rock(Vector2i(1, 1)))
	assert_true(result.total_rocks_destroyed() >= 1)


# --- F. Gravity segments ---


func test_gravity_segments_do_not_cross_rock() -> void:
	var board := _board(1, 5)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0) # above
	assert_true(board.set_rock(Vector2i(0, 2)))
	_place_orb(board, 0, 3, OrbType.Id.ORB_1) # below with gap under rock
	assert_true(GravityResolver.apply(board))
	assert_eq(board.orb_at(Vector2i(0, 1)), OrbType.Id.ORB_0) # compacted in upper segment
	assert_eq(board.orb_at(Vector2i(0, 0)), -1)
	assert_true(board.is_rock(Vector2i(0, 2)))
	assert_eq(board.orb_at(Vector2i(0, 4)), OrbType.Id.ORB_1)
	assert_eq(board.orb_at(Vector2i(0, 3)), -1)


func test_gravity_after_rock_destroyed_allows_pass() -> void:
	var board := _board(1, 4)
	_place_orb(board, 0, 0, OrbType.Id.ORB_4)
	assert_true(board.set_rock(Vector2i(0, 1)))
	_place_orb(board, 0, 2, OrbType.Id.ORB_4)
	_place_orb(board, 0, 3, OrbType.Id.ORB_4)
	assert_true(board.clear_obstacle(Vector2i(0, 1)))
	assert_true(GravityResolver.apply(board))
	assert_eq(board.orb_at(Vector2i(0, 0)), -1)
	assert_eq(board.orb_at(Vector2i(0, 1)), OrbType.Id.ORB_4)
	assert_eq(board.orb_at(Vector2i(0, 2)), OrbType.Id.ORB_4)
	assert_eq(board.orb_at(Vector2i(0, 3)), OrbType.Id.ORB_4)


# --- G. Refill ---


func test_refill_skips_rock_without_rng_and_is_deterministic() -> void:
	var a := _board(2, 2)
	var b := _board(2, 2)
	assert_true(a.set_rock(Vector2i(0, 0)))
	assert_true(b.set_rock(Vector2i(0, 0)))
	var ga := OrbGenerator.create()
	var gb := OrbGenerator.create()
	ga.set_seed(99)
	gb.set_seed(99)
	assert_true(CascadeResolver._refill_empties(a, ga))
	assert_true(CascadeResolver._refill_empties(b, gb))
	assert_true(a.is_rock(Vector2i(0, 0)))
	assert_eq(a.orb_at(Vector2i(0, 0)), -1)
	assert_true(a.has_orb(Vector2i(1, 0)))
	assert_true(a.has_orb(Vector2i(0, 1)))
	assert_true(a.has_orb(Vector2i(1, 1)))
	assert_eq(a.snapshot_orb_ids(), b.snapshot_orb_ids())
	assert_eq(a.snapshot_obstacle_types(), b.snapshot_obstacle_types())


# --- H. Cascade integration ---


func test_cascade_match_breaks_rock_then_segmented_gravity_refill() -> void:
	var board := _board(3, 3)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	_place_orb(board, 1, 0, OrbType.Id.ORB_0)
	_place_orb(board, 2, 0, OrbType.Id.ORB_0)
	assert_true(board.set_rock(Vector2i(1, 1)))
	_place_orb(board, 0, 2, OrbType.Id.ORB_1)
	var gen := OrbGenerator.create()
	gen.set_seed(11)
	var before_rock := board.rock_count()
	assert_eq(before_rock, 1)
	var result := CascadeResolver.resolve(board, gen)
	assert_true(result.is_stable())
	assert_eq(board.rock_count(), 0)
	assert_true(result.total_rocks_destroyed() >= 1)
	assert_false(MatchResolver.detect(board).has_matches())


# --- I / J. Session ROCK + OFF baseline ---


func test_session_rock_layout_and_off_baseline() -> void:
	var rock := PuzzleSession.create_score_attack(
		6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK
	)
	assert_true(rock.is_valid())
	assert_eq(rock.obstacle_mode(), PuzzleSession.ObstacleMode.ROCK)
	assert_eq(rock.rock_count(), 3)
	for pos in PuzzleSession.DEV_ROCK_LAYOUT:
		assert_true(rock.is_rock_at(pos))
		assert_eq(rock.orb_at(pos), -1)
	assert_false(rock.begin_drag(PuzzleSession.DEV_ROCK_LAYOUT[0]))

	var off := PuzzleSession.create_score_attack(
		6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.OFF
	)
	assert_true(off.is_valid())
	assert_eq(off.obstacle_mode(), PuzzleSession.ObstacleMode.OFF)
	assert_eq(off.rock_count(), 0)
	assert_eq(off.remaining_ms(), 60000)
	assert_eq(off.score(), 0)
	# Same seed OFF board matches prior R-F opening (full of orbs, no rocks).
	assert_eq(off.board_width(), 6)
	assert_true(off.begin_drag(Vector2i(0, 0)))
	assert_eq(off.move_remaining_ms(), PuzzleSession.MOVE_DURATION_MS)


func test_ready_helpers_support_obstacle_selection() -> void:
	var view := PuzzleGameView.new()
	add_child_autofree(view)
	assert_true(view.is_awaiting_start())
	assert_eq(view.selected_obstacle_mode(), PuzzleSession.ObstacleMode.ROCK)
	view.select_obstacle_mode(PuzzleSession.ObstacleMode.OFF)
	assert_eq(view.selected_obstacle_mode(), PuzzleSession.ObstacleMode.OFF)
	assert_true(view.is_awaiting_start())
	view.start_selected_session()
	assert_true(view.has_playable_session())
	assert_eq(view._session.obstacle_mode(), PuzzleSession.ObstacleMode.OFF)
	assert_eq(view._session.rock_count(), 0)
	view.select_obstacle_mode(PuzzleSession.ObstacleMode.ROCK)
	# Selection alone does not restart.
	assert_eq(view._session.obstacle_mode(), PuzzleSession.ObstacleMode.OFF)
	view.restart_selected_session()
	assert_eq(view._session.obstacle_mode(), PuzzleSession.ObstacleMode.ROCK)
	assert_eq(view._session.rock_count(), 3)
