extends GutTest

## Gate 2-B1: paired-seed ROCK pressure harness (DEV).
## Does not start live 20-trial evaluation.


func _session_rock(seed_v: int, count: int) -> PuzzleSession:
	return PuzzleSession.create_score_attack(
		6,
		6,
		seed_v,
		60000,
		CascadeResolver.MAX_CASCADE_STEPS,
		PuzzleSession.ObstacleMode.ROCK,
		count,
		count
	)


func _session_off(seed_v: int) -> PuzzleSession:
	return PuzzleSession.create_score_attack(
		6, 6, seed_v, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.OFF
	)


func test_legacy_default_rock_is_3_3() -> void:
	var s := PuzzleSession.create_score_attack(
		6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK
	)
	assert_true(s.is_valid())
	assert_eq(s.initial_rock_count_config(), 3)
	assert_eq(s.target_rock_count(), 3)
	assert_eq(s.rock_count(), 3)
	assert_eq(s.resolved_move_count(), 0)
	assert_eq(s.rock_break_count(), 0)


func test_off_existing_caller_valid_ignores_default_counts() -> void:
	var s := PuzzleSession.create_score_attack(
		6, 6, 42, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.OFF
	)
	assert_true(s.is_valid())
	assert_eq(s.rock_count(), 0)
	assert_eq(s.initial_rock_count_config(), 0)
	assert_eq(s.target_rock_count(), 0)
	assert_eq(s.rock_break_count(), 0)


func test_rock_pressure_counts_2_3_4() -> void:
	for count in [2, 3, 4]:
		var s := _session_rock(104729, count)
		assert_true(s.is_valid())
		assert_eq(s.initial_rock_count_config(), count)
		assert_eq(s.target_rock_count(), count)
		assert_eq(s.rock_count(), count)
		assert_eq(s.initial_rock_positions().size(), count)
		var seen: Dictionary = {}
		for pos in s.initial_rock_positions():
			assert_gte(pos.x, 0)
			assert_lt(pos.x, 6)
			assert_gte(pos.y, 0)
			assert_lt(pos.y, 6)
			assert_false(seen.has(pos))
			seen[pos] = true
			assert_eq(s.rock_hp_at(pos), 2)
			assert_eq(s.orb_at(pos), -1)


func test_same_seed_same_condition_same_positions() -> void:
	var a := _session_rock(130363, 4)
	var b := _session_rock(130363, 4)
	assert_eq(a.initial_rock_positions(), b.initial_rock_positions())
	assert_eq(a.board_snapshot(), b.board_snapshot())


func test_paired_seed_orb_fill_not_consumed_by_obstacle_pick() -> void:
	var seed_v := 196613
	var off := _session_off(seed_v)
	var r2 := _session_rock(seed_v, 2)
	var r3 := _session_rock(seed_v, 3)
	var r4 := _session_rock(seed_v, 4)
	assert_eq(off.session_seed(), seed_v)
	assert_eq(r2.session_seed(), seed_v)
	assert_eq(r3.session_seed(), seed_v)
	assert_eq(r4.session_seed(), seed_v)
	# Non-ROCK cells match OFF stable-fill orbs (Obstacle RNG does not consume Orb stream).
	for y in range(6):
		for x in range(6):
			var pos := Vector2i(x, y)
			if r4.is_rock_at(pos):
				continue
			assert_eq(off.orb_at(pos), r4.orb_at(pos))
			assert_eq(r2.orb_at(pos), r4.orb_at(pos))
			assert_eq(r3.orb_at(pos), r4.orb_at(pos))


func test_nested_initial_rock_sets_r2_subset_r3_subset_r4() -> void:
	for seed_v in PuzzleGameView.GATE2_SEEDS:
		var r2 := _session_rock(seed_v, 2)
		var r3 := _session_rock(seed_v, 3)
		var r4 := _session_rock(seed_v, 4)
		var set3: Dictionary = {}
		for p in r3.initial_rock_positions():
			set3[p] = true
		var set4: Dictionary = {}
		for p in r4.initial_rock_positions():
			set4[p] = true
		for p in r2.initial_rock_positions():
			assert_true(set3.has(p), "R2 not subset of R3 for seed %d" % seed_v)
		for p in r3.initial_rock_positions():
			assert_true(set4.has(p), "R3 not subset of R4 for seed %d" % seed_v)


func test_respawn_targets_configured_count_not_baseline_only() -> void:
	for count in [2, 3, 4]:
		var s := _session_rock(104729, count)
		assert_true(s._board.clear_obstacle(s.initial_rock_positions()[0]))
		assert_eq(s.rock_count(), count - 1)
		s._pending_rock_respawns = 1
		s._respawn_armed = true
		var spawns: Array = s._apply_rock_respawn_after_resolve(0)
		assert_eq(spawns.size(), 1)
		assert_eq(s.rock_count(), count)
		assert_eq(s.target_rock_count(), count)


func test_rock4_does_not_converge_to_target3() -> void:
	var s := _session_rock(262147, 4)
	assert_eq(s.target_rock_count(), 4)
	assert_ne(s.target_rock_count(), PuzzleSession.TARGET_ROCK_COUNT) # when TARGET const stays 3
	# Destroy two; pending/spawn pressure still aims at 4.
	assert_true(s._board.clear_obstacle(s.initial_rock_positions()[0]))
	assert_true(s._board.clear_obstacle(s.initial_rock_positions()[1]))
	assert_eq(s.rock_count(), 2)
	s._pending_rock_respawns = 2
	s._respawn_armed = true
	var sp1: Array = s._apply_rock_respawn_after_resolve(0)
	assert_eq(sp1.size(), 1)
	assert_eq(s.rock_count(), 3)
	assert_true(s.respawn_armed())
	var sp2: Array = s._apply_rock_respawn_after_resolve(0)
	assert_eq(sp2.size(), 1)
	assert_eq(s.rock_count(), 4)
	assert_eq(s.target_rock_count(), 4)


func test_metrics_zero_on_new_session_and_zero_swap() -> void:
	var s := _session_rock(42, 3)
	assert_eq(s.resolved_move_count(), 0)
	assert_eq(s.rock_break_count(), 0)
	# Grab a non-rock orb.
	var start := Vector2i(-1, -1)
	for y in range(6):
		for x in range(6):
			var p := Vector2i(x, y)
			if not s.is_rock_at(p) and s.orb_at(p) >= 0:
				start = p
				break
		if start.x >= 0:
			break
	assert_true(s.begin_drag(start))
	var zero := s.release_drag()
	assert_true(zero.is_success())
	assert_eq(s.resolved_move_count(), 0)
	assert_eq(s.rock_break_count(), 0)


func test_successful_resolve_increments_resolved_moves() -> void:
	var s := PuzzleSession.create_score_attack(
		6, 6, 7, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.OFF
	)
	assert_true(s.is_valid())
	var a := Vector2i(-1, -1)
	var b := Vector2i(-1, -1)
	for y in range(6):
		for x in range(5):
			var p := Vector2i(x, y)
			var n := Vector2i(x + 1, y)
			if s.orb_at(p) >= 0 and s.orb_at(n) >= 0 and s.orb_at(p) != s.orb_at(n):
				a = p
				b = n
				break
		if a.x >= 0:
			break
	assert_true(a.x >= 0)
	assert_true(s.begin_drag(a))
	assert_eq(s.step_drag(b), DragRoute.StepResult.SWAPPED)
	var res := s.release_drag()
	assert_true(res.is_success())
	assert_eq(s.resolved_move_count(), 1)


func test_off_breaks_always_zero() -> void:
	var s := _session_off(42)
	assert_eq(s.rock_break_count(), 0)
	var a := Vector2i(-1, -1)
	var b := Vector2i(-1, -1)
	for y in range(6):
		for x in range(5):
			var p := Vector2i(x, y)
			var n := Vector2i(x + 1, y)
			if s.orb_at(p) >= 0 and s.orb_at(n) >= 0:
				a = p
				b = n
				break
		if a.x >= 0:
			break
	assert_true(s.begin_drag(a))
	s.step_drag(b)
	s.release_drag()
	assert_eq(s.rock_break_count(), 0)


func test_gate2_ui_selectors_and_start() -> void:
	var view := PuzzleGameView.new()
	add_child_autofree(view)
	assert_eq(view.selected_duration_ms(), 60000)
	assert_eq(PuzzleGameView.GATE2_SEEDS.size(), 5)
	assert_eq(PuzzleGameView.GATE2_SEEDS[0], 104729)
	assert_eq(PuzzleGameView.GATE2_SEEDS[4], 524287)
	view.select_gate2_seed_index(2)
	assert_eq(view.selected_gate2_seed(), 196613)
	view.select_gate2_condition(PuzzleGameView.Gate2Condition.ROCK2)
	view.start_selected_session()
	assert_eq(view._session.session_seed(), 196613)
	assert_eq(view._session.initial_rock_count_config(), 2)
	assert_eq(view._session.target_rock_count(), 2)
	assert_eq(view._session.rock_count(), 2)
	view.select_gate2_condition(PuzzleGameView.Gate2Condition.ROCK4)
	view.select_gate2_seed_index(4)
	view.restart_selected_session()
	assert_eq(view._session.session_seed(), 524287)
	assert_eq(view._session.initial_rock_count_config(), 4)
	assert_eq(view._session.target_rock_count(), 4)
	assert_eq(view._session.rock_count(), 4)
	assert_eq(view._session.resolved_move_count(), 0)
	assert_eq(view._session.rock_break_count(), 0)


func test_gate2_ui_off_and_rock3_baseline() -> void:
	var view := PuzzleGameView.new()
	add_child_autofree(view)
	view.select_gate2_condition(PuzzleGameView.Gate2Condition.OFF)
	view.select_gate2_seed_index(0)
	view.start_selected_session()
	assert_eq(view._session.session_seed(), 104729)
	assert_eq(view._session.rock_count(), 0)
	assert_eq(view._session.initial_rock_count_config(), 0)
	view.select_gate2_condition(PuzzleGameView.Gate2Condition.ROCK3)
	view.restart_selected_session()
	assert_eq(view._session.initial_rock_count_config(), 3)
	assert_eq(view._session.target_rock_count(), 3)
	assert_eq(view._session.rock_count(), 3)


func test_gate2_duration_buttons_lock_non_60() -> void:
	var view := PuzzleGameView.new()
	add_child_autofree(view)
	view._refresh_duration_buttons()
	assert_true(view._duration_buttons[45000].disabled)
	assert_false(view._duration_buttons[60000].disabled)
	assert_true(view._duration_buttons[90000].disabled)
	# Programmatic select still works for DEV helpers.
	view.select_duration(45000)
	assert_eq(view.selected_duration_ms(), 45000)
	view.start_selected_session()
	assert_eq(view._session.remaining_ms(), 60000)


func test_invalid_rock_count_fail_closed() -> void:
	var bad := PuzzleSession.create_score_attack(
		6, 6, 1, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK, 0, 0
	)
	assert_false(bad.is_valid())
	var huge := PuzzleSession.create_score_attack(
		6, 6, 1, 60000, CascadeResolver.MAX_CASCADE_STEPS, PuzzleSession.ObstacleMode.ROCK, 37, 37
	)
	assert_false(huge.is_valid())
