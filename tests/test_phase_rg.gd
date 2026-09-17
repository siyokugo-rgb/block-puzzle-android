extends GutTest

## Phase R-G: ROCK obstacle with Gate 2 DEV durability HP=2.
## Damage unit: max 1 hit per ROCK per cascade step.


func _board(w: int = 6, h: int = 6) -> PuzzleBoard:
	return PuzzleBoard.create(w, h)


func _place_orb(board: PuzzleBoard, x: int, y: int, orb: int) -> void:
	assert_true(board.set_orb(Vector2i(x, y), orb))


# --- A. PuzzleCell durability ---


func test_cell_rock_hp2_damage_and_forbid_orb() -> void:
	var cell := PuzzleCell.with_orb(OrbType.Id.ORB_1)
	assert_ne(cell, null)
	assert_true(cell.has_orb())
	assert_true(cell.set_rock())
	assert_true(cell.is_rock())
	assert_eq(cell.obstacle_hp(), PuzzleCell.ROCK_INITIAL_HP)
	assert_eq(cell.obstacle_hp(), 2)
	assert_false(cell.has_orb())
	assert_false(cell.is_empty())
	assert_false(cell.set_orb(OrbType.Id.ORB_0))
	# Existing ROCK: set_rock refuses silent HP reset.
	assert_false(cell.set_rock())
	assert_eq(cell.obstacle_hp(), 2)
	# Invalid obstacle rejected; ROCK retained.
	assert_false(cell.set_obstacle(99))
	assert_true(cell.is_rock())
	assert_eq(cell.obstacle_hp(), 2)
	# Hit 1: HP2 → HP1, still ROCK.
	assert_eq(cell.damage_rock(), 1)
	assert_true(cell.is_rock())
	assert_eq(cell.obstacle_hp(), 1)
	assert_false(cell.is_empty())
	var copy := cell.duplicate_cell()
	assert_true(copy.is_rock())
	assert_eq(copy.obstacle_hp(), 1)
	copy.clear_obstacle()
	assert_true(copy.is_empty())
	assert_eq(copy.obstacle_hp(), 0)
	assert_true(cell.is_rock()) # defensive
	# Hit 2: HP1 → destroy.
	assert_eq(cell.damage_rock(), 0)
	assert_false(cell.is_rock())
	assert_true(cell.is_empty())
	assert_eq(cell.obstacle_hp(), 0)
	# Invalid damage on non-ROCK.
	assert_eq(cell.damage_rock(), -1)
	assert_true(cell.is_empty())


func test_cell_none_obstacle_and_invalid_with_orb() -> void:
	assert_eq(PuzzleCell.with_orb(-1), null)
	var empty := PuzzleCell.empty()
	assert_true(empty.is_empty())
	assert_eq(empty.obstacle_hp(), 0)
	assert_true(empty.set_obstacle(ObstacleType.Id.NONE))
	assert_true(empty.is_empty())
	assert_eq(empty.obstacle_hp(), 0)


# --- B. PuzzleBoard ---


func test_board_rock_hp_damage_and_snapshots() -> void:
	var board := _board(3, 3)
	assert_true(board.set_orb(Vector2i(0, 0), OrbType.Id.ORB_2))
	assert_true(board.set_rock(Vector2i(0, 0)))
	assert_true(board.is_rock(Vector2i(0, 0)))
	assert_eq(board.rock_hp_at(Vector2i(0, 0)), 2)
	assert_false(board.is_empty(Vector2i(0, 0)))
	assert_false(board.set_orb(Vector2i(0, 0), OrbType.Id.ORB_1))
	assert_false(board.set_rock(Vector2i(0, 0))) # already ROCK
	assert_eq(board.rock_hp_at(Vector2i(0, 0)), 2)
	assert_eq(board.damage_rock(Vector2i(0, 0)), 1)
	assert_eq(board.rock_hp_at(Vector2i(0, 0)), 1)
	assert_true(board.is_rock(Vector2i(0, 0)))
	assert_eq(board.rock_count(), 1)
	assert_eq(board.damage_rock(Vector2i(0, 0)), 0)
	assert_eq(board.rock_hp_at(Vector2i(0, 0)), 0)
	assert_false(board.is_rock(Vector2i(0, 0)))
	assert_true(board.is_empty(Vector2i(0, 0)))
	assert_eq(board.damage_rock(Vector2i(0, 0)), -1)
	assert_eq(board.damage_rock(Vector2i(9, 9)), -1)
	assert_eq(board.rock_hp_at(Vector2i(1, 1)), 0)

	assert_true(board.set_rock(Vector2i(1, 1)))
	var type_snap := board.snapshot_obstacle_types()
	var hp_snap := board.snapshot_obstacle_hp()
	assert_eq(type_snap[1][1], ObstacleType.Id.ROCK)
	assert_eq(hp_snap[1][1], 2)
	hp_snap[1][1] = 0
	type_snap[1][1] = ObstacleType.Id.NONE
	assert_eq(board.obstacle_at(Vector2i(1, 1)), ObstacleType.Id.ROCK)
	assert_eq(board.rock_hp_at(Vector2i(1, 1)), 2)


# --- C. Drag HP2 / HP1 impassable ---


func test_drag_rejects_hp2_and_hp1_rock() -> void:
	var board := _board(3, 3)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	_place_orb(board, 1, 0, OrbType.Id.ORB_1)
	assert_true(board.set_rock(Vector2i(2, 0)))
	assert_eq(board.rock_hp_at(Vector2i(2, 0)), 2)
	assert_eq(DragRoute.begin(board, Vector2i(2, 0)), null)
	var route := DragRoute.begin(board, Vector2i(0, 0))
	assert_ne(route, null)
	assert_eq(route.try_step(Vector2i(1, 0)), DragRoute.StepResult.SWAPPED)
	assert_eq(route.try_step(Vector2i(2, 0)), DragRoute.StepResult.REJECTED)
	assert_eq(route.current_cell(), Vector2i(1, 0))
	assert_eq(route.swap_count(), 1)
	# Damage to HP1: still impassable; route state unchanged.
	assert_eq(board.damage_rock(Vector2i(2, 0)), 1)
	assert_eq(board.rock_hp_at(Vector2i(2, 0)), 1)
	assert_eq(route.try_step(Vector2i(2, 0)), DragRoute.StepResult.REJECTED)
	assert_eq(route.current_cell(), Vector2i(1, 0))
	assert_eq(route.swap_count(), 1)
	assert_false(board.swap(Vector2i(1, 0), Vector2i(2, 0)))
	assert_eq(DragRoute.begin(board, Vector2i(2, 0)), null)


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
	assert_true(board.set_rock(Vector2i(2, 2)))
	var matched := MatchResolver.detect(board).matched_cells_snapshot()
	assert_true(matched.size() >= 3)
	var rocks := CascadeResolver.collect_adjacent_rocks(board, matched)
	assert_eq(rocks.size(), 0)
	assert_true(board.is_rock(Vector2i(2, 2)))
	assert_eq(board.rock_hp_at(Vector2i(2, 2)), 2)


# --- D/E. Same-step multi-adjacency = 1 damage ---


func test_same_step_multi_adjacency_damages_once_not_destroy() -> void:
	var board := _board(4, 3)
	# Horizontal match row 1: AAA — rocks above/below touch multiple matched cells.
	_place_orb(board, 0, 1, OrbType.Id.ORB_2)
	_place_orb(board, 1, 1, OrbType.Id.ORB_2)
	_place_orb(board, 2, 1, OrbType.Id.ORB_2)
	assert_true(board.set_rock(Vector2i(1, 0)))
	assert_true(board.set_rock(Vector2i(1, 2)))
	assert_true(board.set_rock(Vector2i(0, 2)))
	var matched := MatchResolver.detect(board).matched_cells_snapshot()
	assert_true(matched.size() >= 3)
	var rocks := CascadeResolver.collect_adjacent_rocks(board, matched)
	assert_eq(rocks.size(), 3)
	var stats := CascadeResolver.apply_rock_hits(board, rocks)
	assert_true(stats["ok"])
	assert_eq(stats["hits"], 3)
	assert_eq(stats["destroyed"], 0)
	assert_eq(board.rock_count(), 3)
	assert_eq(board.rock_hp_at(Vector2i(1, 0)), 1)
	assert_eq(board.rock_hp_at(Vector2i(1, 2)), 1)
	assert_eq(board.rock_hp_at(Vector2i(0, 2)), 1)


func test_first_hit_cascade_keeps_rock_as_barrier() -> void:
	var board := _board(3, 3)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	_place_orb(board, 1, 0, OrbType.Id.ORB_0)
	_place_orb(board, 2, 0, OrbType.Id.ORB_0)
	assert_true(board.set_rock(Vector2i(1, 1)))
	_place_orb(board, 0, 2, OrbType.Id.ORB_1)
	# Single-step seam: detect → hit → clear; HP1 rock remains gravity barrier.
	var matched := MatchResolver.detect(board).matched_cells_snapshot()
	var rocks := CascadeResolver.collect_adjacent_rocks(board, matched)
	assert_eq(rocks.size(), 1)
	var stats := CascadeResolver.apply_rock_hits(board, rocks)
	assert_eq(stats["hits"], 1)
	assert_eq(stats["destroyed"], 0)
	assert_true(board.is_rock(Vector2i(1, 1)))
	assert_eq(board.rock_hp_at(Vector2i(1, 1)), 1)
	assert_true(MatchResolver.clear_current_matches(board).has_matches())
	assert_true(board.set_orb(Vector2i(1, 0), OrbType.Id.ORB_4))
	assert_true(GravityResolver.apply(board))
	# Column segment above HP1 ROCK is only y=0 → orb stays; rock not crossed.
	assert_eq(board.orb_at(Vector2i(1, 0)), OrbType.Id.ORB_4)
	assert_true(board.is_rock(Vector2i(1, 1)))
	assert_eq(board.orb_at(Vector2i(1, 1)), -1)


func test_second_hit_destroys_via_apply_rock_hits_seam() -> void:
	var board := _board(2, 3)
	assert_true(board.set_rock(Vector2i(1, 1)))
	assert_eq(board.rock_hp_at(Vector2i(1, 1)), 2)
	var rocks: Array[Vector2i] = [Vector2i(1, 1)]
	var first := CascadeResolver.apply_rock_hits(board, rocks)
	assert_true(first["ok"])
	assert_eq(first["hits"], 1)
	assert_eq(first["destroyed"], 0)
	assert_eq(board.rock_hp_at(Vector2i(1, 1)), 1)
	var second := CascadeResolver.apply_rock_hits(board, rocks)
	assert_true(second["ok"])
	assert_eq(second["hits"], 1)
	assert_eq(second["destroyed"], 1)
	assert_false(board.is_rock(Vector2i(1, 1)))
	assert_true(board.is_empty(Vector2i(1, 1)))


func test_vertical_match_first_hit_leaves_hp1() -> void:
	var board := _board(2, 3)
	_place_orb(board, 0, 0, OrbType.Id.ORB_3)
	_place_orb(board, 0, 1, OrbType.Id.ORB_3)
	_place_orb(board, 0, 2, OrbType.Id.ORB_3)
	assert_true(board.set_rock(Vector2i(1, 1)))
	var matched := MatchResolver.detect(board).matched_cells_snapshot()
	var rocks := CascadeResolver.collect_adjacent_rocks(board, matched)
	assert_eq(rocks.size(), 1)
	var stats := CascadeResolver.apply_rock_hits(board, rocks)
	assert_eq(stats["hits"], 1)
	assert_eq(stats["destroyed"], 0)
	assert_eq(board.rock_hp_at(Vector2i(1, 1)), 1)


# --- F/G. Cross-step cascade (deterministic seam, two apply_rock_hits) ---


func test_cross_cascade_step_two_hits_destroy() -> void:
	# Simulates step1 then step2 of resolve without RNG: same production helper twice.
	var board := _board(3, 3)
	assert_true(board.set_rock(Vector2i(1, 1)))
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	_place_orb(board, 1, 0, OrbType.Id.ORB_0)
	_place_orb(board, 2, 0, OrbType.Id.ORB_0)
	var matched1 := MatchResolver.detect(board).matched_cells_snapshot()
	var rocks1 := CascadeResolver.collect_adjacent_rocks(board, matched1)
	assert_eq(rocks1.size(), 1)
	var s1 := CascadeResolver.apply_rock_hits(board, rocks1)
	assert_eq(s1["destroyed"], 0)
	assert_eq(board.rock_hp_at(Vector2i(1, 1)), 1)
	# Second cascade-step adjacency (same geometry after clear would refill — call helper again).
	var s2 := CascadeResolver.apply_rock_hits(board, rocks1)
	assert_eq(s2["destroyed"], 1)
	assert_eq(board.rock_count(), 0)


# --- H. Gravity HP2 / HP1 / destroyed ---


func test_gravity_segments_for_hp2_and_hp1() -> void:
	var board := _board(1, 5)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	assert_true(board.set_rock(Vector2i(0, 2)))
	_place_orb(board, 0, 3, OrbType.Id.ORB_1)
	assert_true(GravityResolver.apply(board))
	assert_eq(board.orb_at(Vector2i(0, 1)), OrbType.Id.ORB_0)
	assert_eq(board.orb_at(Vector2i(0, 0)), -1)
	assert_eq(board.rock_hp_at(Vector2i(0, 2)), 2)
	assert_eq(board.orb_at(Vector2i(0, 4)), OrbType.Id.ORB_1)
	# HP1 still barrier.
	assert_eq(board.damage_rock(Vector2i(0, 2)), 1)
	_place_orb(board, 0, 0, OrbType.Id.ORB_4)
	assert_true(board.clear_orb(Vector2i(0, 1)))
	assert_true(GravityResolver.apply(board))
	assert_eq(board.orb_at(Vector2i(0, 1)), OrbType.Id.ORB_4)
	assert_true(board.is_rock(Vector2i(0, 2)))
	assert_eq(board.orb_at(Vector2i(0, 2)), -1)


func test_gravity_after_rock_destroyed_allows_pass() -> void:
	var board := _board(1, 4)
	_place_orb(board, 0, 0, OrbType.Id.ORB_4)
	assert_true(board.set_rock(Vector2i(0, 1)))
	_place_orb(board, 0, 2, OrbType.Id.ORB_4)
	_place_orb(board, 0, 3, OrbType.Id.ORB_4)
	assert_eq(board.damage_rock(Vector2i(0, 1)), 1)
	assert_eq(board.damage_rock(Vector2i(0, 1)), 0)
	assert_true(GravityResolver.apply(board))
	assert_eq(board.orb_at(Vector2i(0, 0)), -1)
	assert_eq(board.orb_at(Vector2i(0, 1)), OrbType.Id.ORB_4)
	assert_eq(board.orb_at(Vector2i(0, 2)), OrbType.Id.ORB_4)
	assert_eq(board.orb_at(Vector2i(0, 3)), OrbType.Id.ORB_4)


# --- I. Refill HP2 / HP1 skip ---


func test_refill_skips_hp2_and_hp1_rock() -> void:
	var a := _board(2, 2)
	var b := _board(2, 2)
	assert_true(a.set_rock(Vector2i(0, 0)))
	assert_true(b.set_rock(Vector2i(0, 0)))
	assert_eq(a.damage_rock(Vector2i(0, 0)), 1) # HP1
	assert_eq(b.rock_hp_at(Vector2i(0, 0)), 2)
	var ga := OrbGenerator.create()
	var gb := OrbGenerator.create()
	ga.set_seed(99)
	gb.set_seed(99)
	assert_true(CascadeResolver._refill_empties(a, ga))
	assert_true(CascadeResolver._refill_empties(b, gb))
	assert_true(a.is_rock(Vector2i(0, 0)))
	assert_eq(a.rock_hp_at(Vector2i(0, 0)), 1)
	assert_eq(a.orb_at(Vector2i(0, 0)), -1)
	assert_true(a.has_orb(Vector2i(1, 0)))
	assert_true(b.is_rock(Vector2i(0, 0)))
	assert_eq(b.rock_hp_at(Vector2i(0, 0)), 2)
	# Destroyed cell becomes refill target.
	assert_eq(a.damage_rock(Vector2i(0, 0)), 0)
	assert_true(a.is_empty(Vector2i(0, 0)))
	var gc := OrbGenerator.create()
	gc.set_seed(5)
	assert_true(CascadeResolver._refill_empties(a, gc))
	assert_true(a.has_orb(Vector2i(0, 0)))


# --- J / K. Session ROCK HP2 layout + OFF baseline ---


func test_session_rock_layout_hp2_and_off_baseline() -> void:
	var rock := PuzzleSession.create_score_attack(
		6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK
	)
	assert_true(rock.is_valid())
	assert_eq(rock.obstacle_mode(), PuzzleSession.ObstacleMode.ROCK)
	assert_eq(rock.rock_count(), 3)
	for pos in PuzzleSession.DEV_ROCK_LAYOUT:
		assert_true(rock.is_rock_at(pos))
		assert_eq(rock.orb_at(pos), -1)
		assert_eq(rock.rock_hp_at(pos), 2)
	assert_false(rock.begin_drag(PuzzleSession.DEV_ROCK_LAYOUT[0]))

	var off := PuzzleSession.create_score_attack(
		6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.OFF
	)
	assert_true(off.is_valid())
	assert_eq(off.obstacle_mode(), PuzzleSession.ObstacleMode.OFF)
	assert_eq(off.rock_count(), 0)
	assert_eq(off.remaining_ms(), 60000)
	assert_eq(off.score(), 0)
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
	assert_eq(view._session.obstacle_mode(), PuzzleSession.ObstacleMode.OFF)
	view.restart_selected_session()
	assert_eq(view._session.obstacle_mode(), PuzzleSession.ObstacleMode.ROCK)
	assert_eq(view._session.rock_count(), 3)
	for pos in PuzzleSession.DEV_ROCK_LAYOUT:
		assert_eq(view._session.rock_hp_at(pos), 2)
