extends GutTest

## Phase R-D: GravityResolver / CascadeResolver / CascadeResult.


## Test-only OrbGenerator: fixed generate_orb() sequence (no RNG native override).
class SequenceOrbGenerator extends OrbGenerator:
	var _values: Array[int] = []
	var _index: int = 0

	static func from_values(values: Array[int]) -> SequenceOrbGenerator:
		var gen := SequenceOrbGenerator.new()
		gen._build(RandomNumberGenerator.new())
		gen._values = values.duplicate()
		gen._index = 0
		return gen

	func generate_orb() -> int:
		if not is_valid():
			return -1
		if _index >= _values.size():
			return -1
		var v: int = _values[_index]
		_index += 1
		if not OrbType.is_dev_id(v):
			return -1
		return v

	func remaining() -> int:
		return _values.size() - _index


func _place(board: PuzzleBoard, x: int, y: int, orb: int) -> void:
	assert_true(board.set_orb(Vector2i(x, y), orb))


func _orb_count(board: PuzzleBoard) -> int:
	var n := 0
	for y in range(board.height()):
		for x in range(board.width()):
			if board.has_orb(Vector2i(x, y)):
				n += 1
	return n


func _column_multiset(board: PuzzleBoard, x: int) -> Array:
	var ids: Array = []
	for y in range(board.height()):
		var id := board.orb_at(Vector2i(x, y))
		if id >= 0:
			ids.append(id)
	ids.sort()
	return ids


func _make_seq_generator(values: Array[int]) -> OrbGenerator:
	return SequenceOrbGenerator.from_values(values)


func _board_with_bottom_match() -> PuzzleBoard:
	var board := PuzzleBoard.create(3, 2)
	_place(board, 0, 0, OrbType.Id.ORB_1)
	_place(board, 1, 0, OrbType.Id.ORB_2)
	_place(board, 2, 0, OrbType.Id.ORB_3)
	_place(board, 0, 1, OrbType.Id.ORB_0)
	_place(board, 1, 1, OrbType.Id.ORB_0)
	_place(board, 2, 1, OrbType.Id.ORB_0)
	return board


# --- A. Gravity basic ---


func test_gravity_single_column_gaps_and_order() -> void:
	# y0=A, y1=empty, y2=B, y3=empty, y4=C → empty,empty,A,B,C
	var board := PuzzleBoard.create(1, 5)
	_place(board, 0, 0, OrbType.Id.ORB_0)
	_place(board, 0, 2, OrbType.Id.ORB_1)
	_place(board, 0, 4, OrbType.Id.ORB_2)
	assert_true(GravityResolver.apply(board))
	assert_true(board.is_empty(Vector2i(0, 0)))
	assert_true(board.is_empty(Vector2i(0, 1)))
	assert_eq(board.orb_at(Vector2i(0, 2)), OrbType.Id.ORB_0)
	assert_eq(board.orb_at(Vector2i(0, 3)), OrbType.Id.ORB_1)
	assert_eq(board.orb_at(Vector2i(0, 4)), OrbType.Id.ORB_2)


func test_gravity_multiple_columns_independent() -> void:
	var board := PuzzleBoard.create(2, 3)
	_place(board, 0, 0, OrbType.Id.ORB_0)
	_place(board, 1, 1, OrbType.Id.ORB_1)
	assert_true(GravityResolver.apply(board))
	assert_true(board.is_empty(Vector2i(0, 0)))
	assert_true(board.is_empty(Vector2i(0, 1)))
	assert_eq(board.orb_at(Vector2i(0, 2)), OrbType.Id.ORB_0)
	assert_true(board.is_empty(Vector2i(1, 0)))
	assert_true(board.is_empty(Vector2i(1, 1)))
	assert_eq(board.orb_at(Vector2i(1, 2)), OrbType.Id.ORB_1)


func test_gravity_already_compact_all_empty_all_full_1x1() -> void:
	var compact := PuzzleBoard.create(1, 3)
	_place(compact, 0, 1, OrbType.Id.ORB_0)
	_place(compact, 0, 2, OrbType.Id.ORB_1)
	var before := compact.snapshot_orb_ids()
	assert_true(GravityResolver.apply(compact))
	assert_eq(compact.snapshot_orb_ids(), before)

	var empty := PuzzleBoard.create(2, 2)
	assert_true(GravityResolver.apply(empty))
	assert_eq(_orb_count(empty), 0)

	var full := PuzzleBoard.create(2, 2)
	_place(full, 0, 0, OrbType.Id.ORB_0)
	_place(full, 1, 0, OrbType.Id.ORB_1)
	_place(full, 0, 1, OrbType.Id.ORB_2)
	_place(full, 1, 1, OrbType.Id.ORB_3)
	var full_before := full.snapshot_orb_ids()
	assert_true(GravityResolver.apply(full))
	assert_eq(full.snapshot_orb_ids(), full_before)

	var one := PuzzleBoard.create(1, 1)
	_place(one, 0, 0, OrbType.Id.ORB_4)
	assert_true(GravityResolver.apply(one))
	assert_eq(one.orb_at(Vector2i(0, 0)), OrbType.Id.ORB_4)


# --- B. Gravity integrity ---


func test_gravity_integrity_count_multiset_and_invalid() -> void:
	var board := PuzzleBoard.create(3, 4)
	_place(board, 0, 0, OrbType.Id.ORB_0)
	_place(board, 0, 2, OrbType.Id.ORB_1)
	_place(board, 1, 1, OrbType.Id.ORB_2)
	_place(board, 1, 3, OrbType.Id.ORB_2)
	_place(board, 2, 0, OrbType.Id.ORB_3)
	var before_count := _orb_count(board)
	var col0 := _column_multiset(board, 0)
	var col1 := _column_multiset(board, 1)
	var col2 := _column_multiset(board, 2)
	assert_true(GravityResolver.apply(board))
	assert_eq(_orb_count(board), before_count)
	assert_eq(_column_multiset(board, 0), col0)
	assert_eq(_column_multiset(board, 1), col1)
	assert_eq(_column_multiset(board, 2), col2)
	assert_eq(board.orb_at(Vector2i(0, 2)), OrbType.Id.ORB_0)
	assert_eq(board.orb_at(Vector2i(0, 3)), OrbType.Id.ORB_1)

	var invalid := PuzzleBoard.create(0, 3)
	assert_false(GravityResolver.apply(invalid))
	assert_false(GravityResolver.apply(null))


# --- C. Stable cascade ---


func test_stable_cascade_no_match_zero_steps() -> void:
	var board := PuzzleBoard.create(3, 3)
	_place(board, 0, 0, OrbType.Id.ORB_0)
	_place(board, 1, 0, OrbType.Id.ORB_1)
	_place(board, 2, 0, OrbType.Id.ORB_0)
	_place(board, 0, 1, OrbType.Id.ORB_1)
	_place(board, 1, 1, OrbType.Id.ORB_0)
	_place(board, 2, 1, OrbType.Id.ORB_1)
	_place(board, 0, 2, OrbType.Id.ORB_0)
	_place(board, 1, 2, OrbType.Id.ORB_1)
	_place(board, 2, 2, OrbType.Id.ORB_0)
	var before := board.snapshot_orb_ids()
	var gen: SequenceOrbGenerator = SequenceOrbGenerator.from_values([0, 1, 2])
	var result := CascadeResolver.resolve(board, gen)
	assert_true(result.is_valid())
	assert_true(result.is_stable())
	assert_false(result.is_guard_exceeded())
	assert_eq(result.step_count(), 0)
	assert_eq(result.total_cleared_cells(), 0)
	assert_eq(result.cleared_cell_count_per_step_snapshot().size(), 0)
	assert_eq(board.snapshot_orb_ids(), before)
	assert_eq(gen.remaining(), 3)


# --- D. One-step cascade ---


func test_one_step_cascade_clears_gravity_refills_stable() -> void:
	var board := PuzzleBoard.create(3, 3)
	_place(board, 0, 0, OrbType.Id.ORB_1)
	_place(board, 1, 0, OrbType.Id.ORB_2)
	_place(board, 2, 0, OrbType.Id.ORB_3)
	_place(board, 0, 1, OrbType.Id.ORB_2)
	_place(board, 1, 1, OrbType.Id.ORB_3)
	_place(board, 2, 1, OrbType.Id.ORB_1)
	_place(board, 0, 2, OrbType.Id.ORB_0)
	_place(board, 1, 2, OrbType.Id.ORB_0)
	_place(board, 2, 2, OrbType.Id.ORB_0)
	var gen := _make_seq_generator([OrbType.Id.ORB_4, OrbType.Id.ORB_1, OrbType.Id.ORB_2])
	var result := CascadeResolver.resolve(board, gen)
	assert_true(result.is_valid())
	assert_true(result.is_stable())
	assert_eq(result.step_count(), 1)
	assert_eq(result.total_cleared_cells(), 3)
	assert_eq(result.cleared_cell_count_per_step_snapshot(), [3])
	assert_eq(_orb_count(board), 9)
	assert_false(MatchResolver.detect(board).has_matches())
	assert_eq(board.orb_at(Vector2i(0, 0)), OrbType.Id.ORB_4)
	assert_eq(board.orb_at(Vector2i(1, 0)), OrbType.Id.ORB_1)
	assert_eq(board.orb_at(Vector2i(2, 0)), OrbType.Id.ORB_2)


# --- E. Multi-step cascade ---


func test_multi_step_cascade_refill_creates_new_match() -> void:
	var board := _board_with_bottom_match()
	var gen := _make_seq_generator([
		OrbType.Id.ORB_0, OrbType.Id.ORB_0, OrbType.Id.ORB_0,
		OrbType.Id.ORB_1, OrbType.Id.ORB_2, OrbType.Id.ORB_3,
	])
	var result := CascadeResolver.resolve(board, gen)
	assert_true(result.is_valid())
	assert_true(result.is_stable())
	assert_gte(result.step_count(), 2)
	assert_eq(result.step_count(), 2)
	assert_eq(result.cleared_cell_count_per_step_snapshot(), [3, 3])
	assert_eq(result.total_cleared_cells(), 6)
	assert_false(MatchResolver.detect(board).has_matches())
	assert_eq(_orb_count(board), 6)


# --- F. Simultaneous clear integration ---


func test_simultaneous_clear_count_flows_into_cascade_result() -> void:
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
	assert_eq(MatchResolver.detect(board).matched_cell_count(), 5)
	var gen := _make_seq_generator([
		OrbType.Id.ORB_3,
		OrbType.Id.ORB_4,
		OrbType.Id.ORB_3,
		OrbType.Id.ORB_4,
		OrbType.Id.ORB_3,
	])
	var result := CascadeResolver.resolve(board, gen)
	assert_true(result.is_valid())
	assert_true(result.is_stable())
	assert_eq(result.step_count(), 1)
	assert_eq(result.cleared_cell_count_per_step_snapshot(), [5])
	assert_eq(result.total_cleared_cells(), 5)


# --- G. Refill order ---


func test_refill_order_left_to_right_top_to_bottom() -> void:
	var board := PuzzleBoard.create(3, 2)
	_place(board, 0, 0, OrbType.Id.ORB_1)
	_place(board, 1, 0, OrbType.Id.ORB_2)
	_place(board, 2, 0, OrbType.Id.ORB_3)
	_place(board, 0, 1, OrbType.Id.ORB_0)
	_place(board, 1, 1, OrbType.Id.ORB_0)
	_place(board, 2, 1, OrbType.Id.ORB_0)
	var gen := _make_seq_generator([OrbType.Id.ORB_4, OrbType.Id.ORB_1, OrbType.Id.ORB_2])
	var result := CascadeResolver.resolve(board, gen)
	assert_true(result.is_stable())
	assert_eq(board.orb_at(Vector2i(0, 0)), OrbType.Id.ORB_4)
	assert_eq(board.orb_at(Vector2i(1, 0)), OrbType.Id.ORB_1)
	assert_eq(board.orb_at(Vector2i(2, 0)), OrbType.Id.ORB_2)

	var vboard := PuzzleBoard.create(1, 4)
	_place(vboard, 0, 0, OrbType.Id.ORB_0)
	_place(vboard, 0, 1, OrbType.Id.ORB_0)
	_place(vboard, 0, 2, OrbType.Id.ORB_0)
	_place(vboard, 0, 3, OrbType.Id.ORB_1)
	var vgen := _make_seq_generator([OrbType.Id.ORB_2, OrbType.Id.ORB_3, OrbType.Id.ORB_4])
	var vresult := CascadeResolver.resolve(vboard, vgen)
	assert_true(vresult.is_stable())
	assert_eq(vboard.orb_at(Vector2i(0, 0)), OrbType.Id.ORB_2)
	assert_eq(vboard.orb_at(Vector2i(0, 1)), OrbType.Id.ORB_3)
	assert_eq(vboard.orb_at(Vector2i(0, 2)), OrbType.Id.ORB_4)
	assert_eq(vboard.orb_at(Vector2i(0, 3)), OrbType.Id.ORB_1)


# --- H. Reproducibility ---


func test_cascade_reproducibility_same_seed_state() -> void:
	var g1 := OrbGenerator.create()
	g1.set_seed(99)
	var g2 := OrbGenerator.create()
	g2.set_seed(99)
	var b1 := _board_with_bottom_match()
	var b2 := _board_with_bottom_match()
	var r1 := CascadeResolver.resolve(b1, g1)
	var r2 := CascadeResolver.resolve(b2, g2)
	assert_true(r1.is_stable())
	assert_true(r2.is_stable())
	assert_eq(r1.step_count(), r2.step_count())
	assert_eq(r1.cleared_cell_count_per_step_snapshot(), r2.cleared_cell_count_per_step_snapshot())
	assert_eq(b1.snapshot_orb_ids(), b2.snapshot_orb_ids())


# --- I. Continuous RNG stream ---


func test_continuous_rng_stream_after_stable_fill() -> void:
	var seed_value := 12345
	var gen_a := OrbGenerator.create()
	gen_a.set_seed(seed_value)
	var board_a := PuzzleBoard.create(4, 4)
	assert_true(gen_a.fill_match_stable(board_a))
	_place(board_a, 0, 3, OrbType.Id.ORB_0)
	_place(board_a, 1, 3, OrbType.Id.ORB_0)
	_place(board_a, 2, 3, OrbType.Id.ORB_0)
	var result_a := CascadeResolver.resolve(board_a, gen_a)
	assert_true(result_a.is_stable())

	var gen_b := OrbGenerator.create()
	gen_b.set_seed(seed_value)
	var board_b := PuzzleBoard.create(4, 4)
	assert_true(gen_b.fill_match_stable(board_b))
	_place(board_b, 0, 3, OrbType.Id.ORB_0)
	_place(board_b, 1, 3, OrbType.Id.ORB_0)
	_place(board_b, 2, 3, OrbType.Id.ORB_0)
	var result_b := CascadeResolver.resolve(board_b, gen_b)
	assert_true(result_b.is_stable())

	assert_eq(result_a.step_count(), result_b.step_count())
	assert_eq(result_a.cleared_cell_count_per_step_snapshot(), result_b.cleared_cell_count_per_step_snapshot())
	assert_eq(board_a.snapshot_orb_ids(), board_b.snapshot_orb_ids())

	# Continuous stream (fill then cascade on same gen) vs fresh same-seed gen for cascade only.
	var gen_cont := OrbGenerator.create()
	gen_cont.set_seed(7)
	var board_cont := PuzzleBoard.create(3, 3)
	assert_true(gen_cont.fill_match_stable(board_cont))
	_place(board_cont, 0, 2, OrbType.Id.ORB_0)
	_place(board_cont, 1, 2, OrbType.Id.ORB_0)
	_place(board_cont, 2, 2, OrbType.Id.ORB_0)
	var r_cont := CascadeResolver.resolve(board_cont, gen_cont)
	assert_true(r_cont.is_stable())

	var rebuild := OrbGenerator.create()
	rebuild.set_seed(7)
	var board_fresh := PuzzleBoard.create(3, 3)
	assert_true(rebuild.fill_match_stable(board_fresh))
	_place(board_fresh, 0, 2, OrbType.Id.ORB_0)
	_place(board_fresh, 1, 2, OrbType.Id.ORB_0)
	_place(board_fresh, 2, 2, OrbType.Id.ORB_0)
	var gen_fresh := OrbGenerator.create()
	gen_fresh.set_seed(7)
	var r_fresh := CascadeResolver.resolve(board_fresh, gen_fresh)
	assert_true(r_fresh.is_stable())
	if r_cont.step_count() >= 1 and r_fresh.step_count() >= 1:
		assert_ne(board_cont.snapshot_orb_ids(), board_fresh.snapshot_orb_ids())


# --- J. Guard ---


func test_guard_exceeded_after_max_steps_not_before() -> void:
	var board := PuzzleBoard.create(3, 1)
	_place(board, 0, 0, OrbType.Id.ORB_0)
	_place(board, 1, 0, OrbType.Id.ORB_0)
	_place(board, 2, 0, OrbType.Id.ORB_0)
	var gen := _make_seq_generator([
		OrbType.Id.ORB_0, OrbType.Id.ORB_0, OrbType.Id.ORB_0,
		OrbType.Id.ORB_0, OrbType.Id.ORB_0, OrbType.Id.ORB_0,
		OrbType.Id.ORB_0, OrbType.Id.ORB_0, OrbType.Id.ORB_0,
	])
	var exceeded := CascadeResolver.resolve(board, gen, 2)
	assert_false(exceeded.is_valid())
	assert_false(exceeded.is_stable())
	assert_true(exceeded.is_guard_exceeded())
	assert_eq(exceeded.step_count(), 2)
	assert_eq(exceeded.cleared_cell_count_per_step_snapshot(), [3, 3])

	var board2 := PuzzleBoard.create(3, 1)
	_place(board2, 0, 0, OrbType.Id.ORB_0)
	_place(board2, 1, 0, OrbType.Id.ORB_0)
	_place(board2, 2, 0, OrbType.Id.ORB_0)
	var gen2 := _make_seq_generator([
		OrbType.Id.ORB_0, OrbType.Id.ORB_0, OrbType.Id.ORB_0,
	])
	var one := CascadeResolver.resolve(board2, gen2, 1)
	assert_true(one.is_guard_exceeded())
	assert_eq(one.step_count(), 1)

	var board3 := PuzzleBoard.create(3, 1)
	_place(board3, 0, 0, OrbType.Id.ORB_0)
	_place(board3, 1, 0, OrbType.Id.ORB_0)
	_place(board3, 2, 0, OrbType.Id.ORB_0)
	var gen3 := _make_seq_generator([OrbType.Id.ORB_1, OrbType.Id.ORB_2, OrbType.Id.ORB_3])
	var ok := CascadeResolver.resolve(board3, gen3, 1)
	assert_true(ok.is_valid())
	assert_true(ok.is_stable())
	assert_false(ok.is_guard_exceeded())
	assert_eq(ok.step_count(), 1)


# --- K. Invalid inputs ---


func test_invalid_cascade_inputs_fail_closed() -> void:
	var valid_board := PuzzleBoard.create(2, 2)
	_place(valid_board, 0, 0, OrbType.Id.ORB_0)
	_place(valid_board, 1, 0, OrbType.Id.ORB_1)
	var before := valid_board.snapshot_orb_ids()
	var valid_gen := OrbGenerator.create()
	valid_gen.set_seed(1)

	var r_null_board := CascadeResolver.resolve(null, valid_gen)
	assert_false(r_null_board.is_valid())
	assert_false(r_null_board.is_guard_exceeded())

	var invalid_board := PuzzleBoard.create(0, 2)
	var r_inv_board := CascadeResolver.resolve(invalid_board, valid_gen)
	assert_false(r_inv_board.is_valid())

	var r_null_gen := CascadeResolver.resolve(valid_board, null)
	assert_false(r_null_gen.is_valid())
	assert_eq(valid_board.snapshot_orb_ids(), before)

	var unbuilt_gen := OrbGenerator.new()
	assert_false(unbuilt_gen.is_valid())
	var r_inv_gen := CascadeResolver.resolve(valid_board, unbuilt_gen)
	assert_false(r_inv_gen.is_valid())
	assert_eq(valid_board.snapshot_orb_ids(), before)

	var r_bad_max := CascadeResolver.resolve(valid_board, valid_gen, -1)
	assert_false(r_bad_max.is_valid())
	assert_eq(valid_board.snapshot_orb_ids(), before)
