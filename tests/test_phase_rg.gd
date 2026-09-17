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


func test_first_hit_then_rock_falls_preserving_hp1() -> void:
	var board := _board(3, 3)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	_place_orb(board, 1, 0, OrbType.Id.ORB_0)
	_place_orb(board, 2, 0, OrbType.Id.ORB_0)
	assert_true(board.set_rock(Vector2i(1, 1)))
	_place_orb(board, 0, 2, OrbType.Id.ORB_1)
	var matched := MatchResolver.detect(board).matched_cells_snapshot()
	var rocks := CascadeResolver.collect_adjacent_rocks(board, matched)
	assert_eq(rocks.size(), 1)
	var stats := CascadeResolver.apply_rock_hits(board, rocks)
	assert_eq(stats["hits"], 1)
	assert_eq(stats["destroyed"], 0)
	assert_eq(board.rock_hp_at(Vector2i(1, 1)), 1)
	assert_true(MatchResolver.clear_current_matches(board).has_matches())
	# After clear, column 1 has only R1 at y=1 → falls to bottom as R1.
	assert_true(GravityResolver.apply(board))
	assert_false(board.is_rock(Vector2i(1, 1)))
	assert_true(board.is_rock(Vector2i(1, 2)))
	assert_eq(board.rock_hp_at(Vector2i(1, 2)), 1)


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


# --- H. Mixed Gravity (falling ROCK) ---


func test_mixed_gravity_preserves_order_and_hp() -> void:
	var board := _board(1, 6)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	assert_true(board.set_rock(Vector2i(0, 2)))
	assert_eq(board.damage_rock(Vector2i(0, 2)), 1) # R1
	_place_orb(board, 0, 3, OrbType.Id.ORB_1)
	_place_orb(board, 0, 5, OrbType.Id.ORB_2)
	var traced := GravityResolver.apply_traced(board)
	assert_true(traced["ok"])
	# Occupants A, R1, B, C → bottom compact order preserved.
	assert_eq(board.orb_at(Vector2i(0, 2)), OrbType.Id.ORB_0)
	assert_true(board.is_rock(Vector2i(0, 3)))
	assert_eq(board.rock_hp_at(Vector2i(0, 3)), 1)
	assert_eq(board.orb_at(Vector2i(0, 4)), OrbType.Id.ORB_1)
	assert_eq(board.orb_at(Vector2i(0, 5)), OrbType.Id.ORB_2)
	for item in traced["moves"]:
		var mv: GravityMoveTrace = item
		assert_eq(mv.from_cell().x, mv.to_cell().x)
		assert_gt(mv.to_cell().y, mv.from_cell().y)


func test_rock_only_falls_preserving_r2() -> void:
	var board := _board(1, 4)
	assert_true(board.set_rock(Vector2i(0, 0)))
	assert_true(GravityResolver.apply(board))
	assert_true(board.is_rock(Vector2i(0, 3)))
	assert_eq(board.rock_hp_at(Vector2i(0, 3)), 2)
	assert_false(board.is_rock(Vector2i(0, 0)))


func test_multiple_rocks_relative_order() -> void:
	var board := _board(1, 6)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	assert_true(board.set_rock(Vector2i(0, 1))) # R2
	_place_orb(board, 0, 3, OrbType.Id.ORB_1)
	assert_true(board.set_rock(Vector2i(0, 4)))
	assert_eq(board.damage_rock(Vector2i(0, 4)), 1) # R1
	assert_true(GravityResolver.apply(board))
	assert_eq(board.orb_at(Vector2i(0, 2)), OrbType.Id.ORB_0)
	assert_eq(board.rock_hp_at(Vector2i(0, 3)), 2)
	assert_eq(board.orb_at(Vector2i(0, 4)), OrbType.Id.ORB_1)
	assert_eq(board.rock_hp_at(Vector2i(0, 5)), 1)


func test_move_occupant_preserves_rock_hp() -> void:
	var board := _board(1, 3)
	assert_true(board.set_rock(Vector2i(0, 0)))
	assert_eq(board.damage_rock(Vector2i(0, 0)), 1)
	assert_true(board.move_occupant(Vector2i(0, 0), Vector2i(0, 2)))
	assert_false(board.is_rock(Vector2i(0, 0)))
	assert_eq(board.rock_hp_at(Vector2i(0, 2)), 1)
	assert_true(board.is_empty(Vector2i(0, 1)))
	assert_true(board.move_occupant(Vector2i(0, 2), Vector2i(0, 1)))
	assert_eq(board.rock_hp_at(Vector2i(0, 1)), 1)
	# Same-cell is a no-op success.
	assert_true(board.move_occupant(Vector2i(0, 1), Vector2i(0, 1)))
	assert_eq(board.rock_hp_at(Vector2i(0, 1)), 1)
	# Non-empty dest fails; source unchanged.
	_place_orb(board, 0, 2, OrbType.Id.ORB_0)
	assert_false(board.move_occupant(Vector2i(0, 1), Vector2i(0, 2)))
	assert_eq(board.rock_hp_at(Vector2i(0, 1)), 1)
	assert_eq(board.orb_at(Vector2i(0, 2)), OrbType.Id.ORB_0)
	# OOB fails.
	assert_false(board.move_occupant(Vector2i(0, 1), Vector2i(0, 9)))
	assert_eq(board.rock_hp_at(Vector2i(0, 1)), 1)


func test_orb_only_column_compacts_like_classic() -> void:
	var board := _board(1, 5)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	_place_orb(board, 0, 2, OrbType.Id.ORB_1)
	_place_orb(board, 0, 4, OrbType.Id.ORB_2)
	var traced := GravityResolver.apply_traced(board)
	assert_true(traced["ok"])
	assert_eq(board.orb_at(Vector2i(0, 0)), -1)
	assert_eq(board.orb_at(Vector2i(0, 1)), -1)
	assert_eq(board.orb_at(Vector2i(0, 2)), OrbType.Id.ORB_0)
	assert_eq(board.orb_at(Vector2i(0, 3)), OrbType.Id.ORB_1)
	assert_eq(board.orb_at(Vector2i(0, 4)), OrbType.Id.ORB_2)
	for item in traced["moves"]:
		var mv: GravityMoveTrace = item
		assert_true(mv.is_orb())
		assert_eq(mv.from_cell().x, mv.to_cell().x)
		assert_gt(mv.to_cell().y, mv.from_cell().y)


func test_orb_cannot_overtake_rock() -> void:
	var board := _board(1, 4)
	_place_orb(board, 0, 0, OrbType.Id.ORB_3)
	assert_true(board.set_rock(Vector2i(0, 2)))
	assert_true(GravityResolver.apply(board))
	# A above R → after compact: A at y=2, R at y=3 (orb stays above rock).
	assert_eq(board.orb_at(Vector2i(0, 2)), OrbType.Id.ORB_3)
	assert_true(board.is_rock(Vector2i(0, 3)))
	assert_eq(board.orb_at(Vector2i(0, 3)), -1)


func test_rock_cannot_overtake_orb() -> void:
	var board := _board(1, 4)
	assert_true(board.set_rock(Vector2i(0, 0)))
	_place_orb(board, 0, 2, OrbType.Id.ORB_4)
	assert_true(GravityResolver.apply(board))
	# R above B → after compact: R at y=2, B at y=3.
	assert_true(board.is_rock(Vector2i(0, 2)))
	assert_eq(board.orb_at(Vector2i(0, 3)), OrbType.Id.ORB_4)


func test_gravity_move_trace_kinds() -> void:
	var board := _board(1, 5)
	_place_orb(board, 0, 0, OrbType.Id.ORB_1)
	assert_true(board.set_rock(Vector2i(0, 1)))
	assert_eq(board.damage_rock(Vector2i(0, 1)), 1) # R1
	var traced := GravityResolver.apply_traced(board)
	assert_true(traced["ok"])
	var moves: Array = traced["moves"]
	assert_eq(moves.size(), 2)
	var orb_mv: GravityMoveTrace = moves[0]
	var rock_mv: GravityMoveTrace = moves[1]
	assert_true(orb_mv.is_orb())
	assert_eq(orb_mv.orb_id(), OrbType.Id.ORB_1)
	assert_eq(orb_mv.from_cell(), Vector2i(0, 0))
	assert_eq(orb_mv.to_cell(), Vector2i(0, 3))
	assert_true(rock_mv.is_rock())
	assert_eq(rock_mv.rock_hp(), 1)
	assert_eq(rock_mv.from_cell(), Vector2i(0, 1))
	assert_eq(rock_mv.to_cell(), Vector2i(0, 4))
	# Defensive duplicate.
	var dup := rock_mv.duplicate_trace()
	dup._rock_hp = 2
	assert_eq(rock_mv.rock_hp(), 1)
	for item in moves:
		var mv: GravityMoveTrace = item
		assert_eq(mv.from_cell().x, mv.to_cell().x)
		assert_gt(mv.to_cell().y, mv.from_cell().y)


func test_r1_destroy_excluded_from_gravity() -> void:
	var board := _board(1, 3)
	assert_true(board.set_rock(Vector2i(0, 0)))
	assert_eq(board.damage_rock(Vector2i(0, 0)), 1)
	assert_eq(board.damage_rock(Vector2i(0, 0)), 0)
	assert_true(board.is_empty(Vector2i(0, 0)))
	var traced := GravityResolver.apply_traced(board)
	assert_true(traced["ok"])
	assert_eq(traced["moves"].size(), 0)
	assert_false(board.is_rock(Vector2i(0, 2)))


func test_gravity_after_rock_destroyed_allows_orb_pass() -> void:
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


# --- Independent HP audit ---


func test_independent_hp_single_target_only() -> void:
	# Test A: Match adjacent only to ROCK A; B/C untouched.
	var board := _board(5, 3)
	# Match on row 0: AAA at (0,0)(1,0)(2,0) — adjacent to A at (1,1)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	_place_orb(board, 1, 0, OrbType.Id.ORB_0)
	_place_orb(board, 2, 0, OrbType.Id.ORB_0)
	assert_true(board.set_rock(Vector2i(1, 1))) # A
	assert_true(board.set_rock(Vector2i(4, 0))) # B — not orthogonal to match cells
	assert_true(board.set_rock(Vector2i(4, 2))) # C
	var matched := MatchResolver.detect(board).matched_cells_snapshot()
	assert_true(matched.size() >= 3)
	var rocks := CascadeResolver.collect_adjacent_rocks(board, matched)
	assert_eq(rocks.size(), 1)
	assert_eq(rocks[0], Vector2i(1, 1))
	var stats := CascadeResolver.apply_rock_hits(board, rocks)
	assert_eq(stats["hits"], 1)
	assert_eq(stats["destroyed"], 0)
	assert_eq(board.rock_hp_at(Vector2i(1, 1)), 1)
	assert_eq(board.rock_hp_at(Vector2i(4, 0)), 2)
	assert_eq(board.rock_hp_at(Vector2i(4, 2)), 2)


func test_independent_hp_separate_simultaneous_matches() -> void:
	# Test B: two match groups in one step, each adjacent to a different ROCK.
	var board := _board(6, 3)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	_place_orb(board, 1, 0, OrbType.Id.ORB_0)
	_place_orb(board, 2, 0, OrbType.Id.ORB_0)
	assert_true(board.set_rock(Vector2i(1, 1))) # A under first match
	_place_orb(board, 3, 2, OrbType.Id.ORB_1)
	_place_orb(board, 4, 2, OrbType.Id.ORB_1)
	_place_orb(board, 5, 2, OrbType.Id.ORB_1)
	assert_true(board.set_rock(Vector2i(4, 1))) # B above second match
	assert_true(board.set_rock(Vector2i(0, 2))) # C isolated
	var matched := MatchResolver.detect(board).matched_cells_snapshot()
	assert_true(matched.size() >= 6)
	var rocks := CascadeResolver.collect_adjacent_rocks(board, matched)
	assert_eq(rocks.size(), 2)
	var stats := CascadeResolver.apply_rock_hits(board, rocks)
	assert_eq(stats["hits"], 2)
	assert_eq(stats["destroyed"], 0)
	assert_eq(board.rock_hp_at(Vector2i(1, 1)), 1)
	assert_eq(board.rock_hp_at(Vector2i(4, 1)), 1)
	assert_eq(board.rock_hp_at(Vector2i(0, 2)), 2)


func test_destroy_one_rock_leaves_others_unchanged() -> void:
	var board := _board(3, 3)
	assert_true(board.set_rock(Vector2i(0, 0)))
	assert_true(board.set_rock(Vector2i(2, 2)))
	var rocks_a: Array[Vector2i] = [Vector2i(0, 0)]
	assert_eq(CascadeResolver.apply_rock_hits(board, rocks_a)["destroyed"], 0)
	assert_eq(CascadeResolver.apply_rock_hits(board, rocks_a)["destroyed"], 1)
	assert_false(board.is_rock(Vector2i(0, 0)))
	assert_eq(board.rock_hp_at(Vector2i(2, 2)), 2)


# --- Trace ---


func test_cascade_step_trace_rock_hit_and_defensive() -> void:
	var board := _board(3, 3)
	_place_orb(board, 0, 0, OrbType.Id.ORB_0)
	_place_orb(board, 1, 0, OrbType.Id.ORB_0)
	_place_orb(board, 2, 0, OrbType.Id.ORB_0)
	assert_true(board.set_rock(Vector2i(1, 1)))
	var gen := OrbGenerator.create()
	gen.set_seed(11)
	var result := CascadeResolver.resolve(board, gen)
	assert_true(result.is_stable())
	var steps := result.steps_snapshot()
	assert_true(steps.size() >= 1)
	var step0: CascadeStepTrace = steps[0]
	var hits := step0.rock_hits_snapshot()
	assert_eq(hits.size(), 1)
	var hit: RockHitTrace = hits[0]
	assert_eq(hit.pos(), Vector2i(1, 1))
	assert_eq(hit.hp_before(), 2)
	assert_eq(hit.hp_after(), 1)
	assert_false(hit.is_destroyed())
	# Mutating snapshot arrays/objects must not alter stored result.
	hits.clear()
	assert_eq(result.steps_snapshot()[0].rock_hits_snapshot().size(), 1)
	# Gravity moves: downward same-column only (Orb and/or ROCK).
	for item in step0.gravity_moves_snapshot():
		var mv: GravityMoveTrace = item
		assert_eq(mv.from_cell().x, mv.to_cell().x)
		assert_gt(mv.to_cell().y, mv.from_cell().y)
		if mv.is_rock():
			assert_true(mv.rock_hp() == 1 or mv.rock_hp() == 2)


func test_trace_refill_matches_domain_generation() -> void:
	var board := _board(2, 2)
	_place_orb(board, 0, 0, OrbType.Id.ORB_2)
	_place_orb(board, 1, 0, OrbType.Id.ORB_2)
	_place_orb(board, 0, 1, OrbType.Id.ORB_2)
	# Force clear of three → refill empties via resolve path after match on col? 
	# Simpler: call refill traced on empty cells.
	var empty := _board(2, 1)
	assert_true(empty.set_rock(Vector2i(0, 0)))
	var gen := OrbGenerator.create()
	gen.set_seed(5)
	var stats := CascadeResolver._refill_empties_traced(empty, gen)
	assert_true(stats["ok"])
	var refills: Array = stats["refills"]
	assert_eq(refills.size(), 1)
	var rf: RefillTrace = refills[0]
	assert_eq(rf.pos(), Vector2i(1, 0))
	assert_eq(empty.orb_at(rf.pos()), rf.orb_id())
	assert_true(empty.is_rock(Vector2i(0, 0)))


# --- Respawn ---


func test_respawn_grace_and_one_per_move() -> void:
	var session := PuzzleSession.create_score_attack(
		6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK
	)
	assert_true(session.is_valid())
	assert_eq(session.rock_count(), 3)
	assert_eq(session.pending_rock_respawns(), 0)
	assert_true(session.begin_drag(Vector2i(0, 0)))
	var zero := session.release_drag()
	assert_true(zero.is_success())
	assert_eq(session.pending_rock_respawns(), 0)
	assert_false(session.respawn_armed())
	assert_true(session._board.clear_obstacle(PuzzleSession.DEV_ROCK_LAYOUT[0]))
	assert_eq(session.rock_count(), 2)
	session._pending_rock_respawns = 1
	session._respawn_armed = true
	var spawns: Array = session._apply_rock_respawn_after_resolve(0)
	assert_eq(spawns.size(), 1)
	var sp: RockSpawnTrace = spawns[0]
	assert_eq(sp.hp(), 2)
	assert_eq(sp.pos().y, 0)
	assert_true(session.is_rock_at(sp.pos()))
	assert_eq(session.rock_hp_at(sp.pos()), 2)
	assert_eq(session.rock_count(), 3)
	assert_eq(session.pending_rock_respawns(), 0)


func test_respawn_top_row_only_never_mid_board() -> void:
	var session := PuzzleSession.create_score_attack(
		6, 6, 55, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK
	)
	assert_true(session._board.clear_obstacle(PuzzleSession.DEV_ROCK_LAYOUT[0]))
	assert_true(session._board.clear_obstacle(PuzzleSession.DEV_ROCK_LAYOUT[1]))
	session._pending_rock_respawns = 2
	session._respawn_armed = true
	for _i in range(2):
		var spawns: Array = session._apply_rock_respawn_after_resolve(0)
		assert_eq(spawns.size(), 1)
		var sp: RockSpawnTrace = spawns[0]
		assert_eq(sp.pos().y, 0)
		assert_eq(sp.hp(), 2)
	assert_eq(session.rock_count(), 3)
	session._pending_rock_respawns = 1
	session._respawn_armed = true
	assert_eq(session._apply_rock_respawn_after_resolve(0).size(), 0)


func test_respawn_two_destroys_refill_one_per_move() -> void:
	var session := PuzzleSession.create_score_attack(
		6, 6, 99, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK
	)
	assert_true(session.is_valid())
	assert_true(session._board.clear_obstacle(PuzzleSession.DEV_ROCK_LAYOUT[0]))
	assert_true(session._board.clear_obstacle(PuzzleSession.DEV_ROCK_LAYOUT[1]))
	assert_eq(session.rock_count(), 1)
	session._pending_rock_respawns = 2
	session._respawn_armed = true
	var s1: Array = session._apply_rock_respawn_after_resolve(0)
	assert_eq(s1.size(), 1)
	assert_eq((s1[0] as RockSpawnTrace).pos().y, 0)
	assert_eq(session.rock_count(), 2)
	assert_eq(session.pending_rock_respawns(), 1)
	assert_true(session.respawn_armed())
	var s2: Array = session._apply_rock_respawn_after_resolve(0)
	assert_eq(s2.size(), 1)
	assert_eq((s2[0] as RockSpawnTrace).pos().y, 0)
	assert_eq(session.rock_count(), 3)
	assert_eq(session.pending_rock_respawns(), 0)


func test_respawn_off_and_no_candidate() -> void:
	var off := PuzzleSession.create_score_attack(
		6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.OFF
	)
	assert_eq(off.pending_rock_respawns(), 0)
	assert_eq(off._apply_rock_respawn_after_resolve(2).size(), 0)
	assert_eq(off.rock_count(), 0)

	var session := PuzzleSession.create_score_attack(
		6, 6, 7, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK
	)
	for x in range(6):
		var p := Vector2i(x, 0)
		if not session._board.is_rock(p):
			if session._board.has_orb(p):
				session._board.clear_orb(p)
			assert_true(session._board.set_rock(p))
	assert_eq(session._try_spawn_one_rock(), null)
	assert_eq(session.state(), PuzzleSession.State.IDLE)


func test_same_seed_same_spawn_column() -> void:
	var columns: Array = []
	for _i in range(2):
		var session := PuzzleSession.create_score_attack(
			6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK
		)
		assert_true(session._board.clear_obstacle(PuzzleSession.DEV_ROCK_LAYOUT[0]))
		session._pending_rock_respawns = 1
		session._respawn_armed = true
		var spawns: Array = session._apply_rock_respawn_after_resolve(0)
		assert_eq(spawns.size(), 1)
		columns.append((spawns[0] as RockSpawnTrace).pos().x)
	assert_eq(columns[0], columns[1])


func test_obstacle_rng_independent_of_orb_stream() -> void:
	assert_eq(
		PuzzleSession.derive_obstacle_rng_seed(42),
		42 ^ PuzzleSession.OBSTACLE_RNG_SEED_XOR
	)
	var a := PuzzleSession.create_score_attack(
		6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK
	)
	var b := PuzzleSession.create_score_attack(
		6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK
	)
	assert_eq(a.board_snapshot(), b.board_snapshot())
	a._pending_rock_respawns = 1
	a._respawn_armed = true
	assert_true(a._board.clear_obstacle(PuzzleSession.DEV_ROCK_LAYOUT[0]))
	var sp := a._apply_rock_respawn_after_resolve(0)
	assert_eq(sp.size(), 1)
	var c := PuzzleSession.create_score_attack(
		6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK
	)
	assert_eq(b.board_snapshot(), c.board_snapshot())


func test_session_over_skips_spawn() -> void:
	var session := PuzzleSession.create_score_attack(
		6, 6, 3, 1000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK
	)
	assert_true(session.begin_drag(Vector2i(0, 0)))
	session.step_drag(Vector2i(1, 0))
	session.advance_time(2000)
	assert_eq(session.state(), PuzzleSession.State.SESSION_OVER)
	assert_true(session.rock_count() <= PuzzleSession.TARGET_ROCK_COUNT)


# --- Presenter ---


func test_presenter_gravity_rock_hp_and_downward_offsets() -> void:
	var mboard := _board(3, 3)
	_place_orb(mboard, 0, 0, OrbType.Id.ORB_0)
	_place_orb(mboard, 1, 0, OrbType.Id.ORB_0)
	_place_orb(mboard, 2, 0, OrbType.Id.ORB_0)
	assert_true(mboard.set_rock(Vector2i(1, 1)))
	_place_orb(mboard, 0, 1, OrbType.Id.ORB_2)
	_place_orb(mboard, 2, 1, OrbType.Id.ORB_3)
	_place_orb(mboard, 0, 2, OrbType.Id.ORB_4)
	# (1,2) empty so R1 can fall after match clear
	_place_orb(mboard, 2, 2, OrbType.Id.ORB_2)
	var before_orbs := mboard.snapshot_orb_ids()
	var before_obs := mboard.snapshot_obstacle_types()
	var before_hp := mboard.snapshot_obstacle_hp()
	var gen := OrbGenerator.create()
	gen.set_seed(21)
	var result := CascadeResolver.resolve(mboard, gen)
	assert_true(result.is_stable())
	var steps := result.steps_snapshot()
	assert_true(steps.size() >= 1)
	var step0: CascadeStepTrace = steps[0]
	var saw_rock := false
	for item in step0.gravity_moves_snapshot():
		var mv: GravityMoveTrace = item
		assert_eq(mv.from_cell().x, mv.to_cell().x)
		assert_gt(mv.to_cell().y, mv.from_cell().y)
		if mv.is_rock():
			saw_rock = true
			assert_eq(mv.rock_hp(), 1)
			assert_eq(mv.from_cell(), Vector2i(1, 1))
			assert_eq(mv.to_cell(), Vector2i(1, 2))
	assert_true(saw_rock)
	var move := SessionMoveResult.resolved(
		steps.size(),
		[],
		0,
		0,
		false,
		before_orbs,
		before_obs,
		before_hp,
		steps,
		[]
	)
	var presenter := ResolutionPresenter.new()
	presenter.begin(move)
	presenter.advance(ResolutionPresenter.MATCH_MS)
	presenter.advance(ResolutionPresenter.ROCK_HIT_MS)
	assert_eq(presenter.phase, ResolutionPresenter.Phase.GRAVITY)
	presenter.advance(ResolutionPresenter.GRAVITY_MS * 0.5)
	var cell_size := 40.0
	var any_down := false
	for item in presenter.gravity_moves:
		var mv2: GravityMoveTrace = item
		var off := presenter.gravity_draw_offset(mv2.from_cell(), cell_size)
		assert_eq(off.x, 0.0)
		assert_gt(off.y, 0.0)
		any_down = true
	assert_true(any_down)
	presenter.advance(ResolutionPresenter.GRAVITY_MS)
	assert_eq(presenter.phase, ResolutionPresenter.Phase.REFILL)
	if not presenter.refill_cells.is_empty():
		var rf: RefillTrace = presenter.refill_cells[0]
		var roff := presenter.refill_draw_offset(rf.pos(), cell_size)
		assert_eq(roff.x, 0.0)
		assert_lt(roff.y, 0.0)
	for _i in range(40):
		if not presenter.is_busy():
			break
		presenter.advance(50.0)
	assert_false(presenter.is_busy())
	assert_eq(presenter.vis_orbs, mboard.snapshot_orb_ids())
	assert_eq(presenter.vis_obstacles, mboard.snapshot_obstacle_types())
	assert_eq(presenter.vis_hp, mboard.snapshot_obstacle_hp())


func test_presenter_respawn_drop_from_above() -> void:
	var session := PuzzleSession.create_score_attack(
		6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK
	)
	assert_true(session._board.clear_obstacle(PuzzleSession.DEV_ROCK_LAYOUT[0]))
	session._pending_rock_respawns = 1
	session._respawn_armed = true
	var spawns: Array = session._apply_rock_respawn_after_resolve(0)
	assert_eq(spawns.size(), 1)
	var sp: RockSpawnTrace = spawns[0]
	assert_eq(sp.pos().y, 0)
	var before_orbs: Array = session.board_snapshot()
	var before_obs: Array = session.obstacle_snapshot()
	var before_hp: Array = session._board.snapshot_obstacle_hp()
	# Simulate pre-spawn presentation baseline: clear the spawned rock from "before".
	before_obs[sp.pos().y][sp.pos().x] = ObstacleType.Id.NONE
	before_hp[sp.pos().y][sp.pos().x] = 0
	var move := SessionMoveResult.resolved(
		0, [], 0, 0, false,
		before_orbs, before_obs, before_hp,
		[], spawns
	)
	var presenter := ResolutionPresenter.new()
	presenter.begin(move)
	assert_eq(presenter.phase, ResolutionPresenter.Phase.RESPAWN_WARN)
	var cell_size := 40.0
	var warn_off := presenter.spawn_draw_offset(sp.pos(), cell_size)
	assert_eq(warn_off.x, 0.0)
	assert_lt(warn_off.y, 0.0)
	presenter.advance(ResolutionPresenter.RESPAWN_WARN_MS)
	assert_eq(presenter.phase, ResolutionPresenter.Phase.RESPAWN_SHOW)
	presenter.advance(ResolutionPresenter.RESPAWN_SHOW_MS * 0.5)
	var mid := presenter.spawn_draw_offset(sp.pos(), cell_size)
	assert_eq(mid.x, 0.0)
	assert_lt(mid.y, 0.0)
	presenter.advance(ResolutionPresenter.RESPAWN_SHOW_MS)
	assert_false(presenter.is_busy())
	assert_true(presenter.is_rock(sp.pos()))
	assert_eq(presenter.rock_hp_at(sp.pos()), 2)


func test_presenter_off_has_no_rock_animation() -> void:
	var off := PuzzleSession.create_score_attack(
		6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.OFF
	)
	assert_eq(off.rock_count(), 0)
	assert_true(off.begin_drag(Vector2i(0, 0)))
	var released := off.release_drag()
	assert_true(released.is_success())
	assert_eq(released.rock_spawns_snapshot().size(), 0)
