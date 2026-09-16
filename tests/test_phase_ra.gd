extends GutTest

## Phase R-A: PuzzleBoard / OrbType / OrbGenerator / match-stable initial fill.


func test_orb_type_dev_catalog() -> void:
	assert_eq(OrbType.DEV_TYPE_COUNT, 5)
	assert_eq(OrbType.all_dev_ids().size(), 5)
	assert_true(OrbType.is_dev_id(OrbType.Id.ORB_0))
	assert_true(OrbType.is_dev_id(OrbType.Id.ORB_4))
	assert_false(OrbType.is_dev_id(-1))
	assert_false(OrbType.is_dev_id(5))
	assert_eq(OrbType.id_name(OrbType.Id.ORB_2), "ORB_2")


func test_orb_generator_valid_and_dev_range() -> void:
	var gen := OrbGenerator.create()
	assert_true(gen.is_valid())
	gen.set_seed(7)
	for _i in range(40):
		var id := gen.generate_orb()
		assert_true(OrbType.is_dev_id(id))


func test_orb_generator_same_seed_reproducible() -> void:
	var a := OrbGenerator.create()
	var b := OrbGenerator.create()
	a.set_seed(12345)
	b.set_seed(12345)
	var seq_a: Array = []
	var seq_b: Array = []
	for _i in range(32):
		seq_a.append(a.generate_orb())
		seq_b.append(b.generate_orb())
	assert_eq(seq_a, seq_b)


func test_orb_generator_different_seeds_diverge() -> void:
	var a := OrbGenerator.create()
	var b := OrbGenerator.create()
	a.set_seed(1)
	b.set_seed(2)
	var same := true
	for _i in range(24):
		if a.generate_orb() != b.generate_orb():
			same = false
			break
	assert_false(same)


func test_board_valid_and_invalid_sizes() -> void:
	var ok := PuzzleBoard.create(1, 1)
	assert_true(ok.is_valid())
	assert_eq(ok.width(), 1)
	assert_eq(ok.height(), 1)
	var bad_w := PuzzleBoard.create(0, 4)
	assert_false(bad_w.is_valid())
	var bad_h := PuzzleBoard.create(4, -1)
	assert_false(bad_h.is_valid())
	var mid := PuzzleBoard.create(6, 6)
	assert_true(mid.is_valid())


func test_board_get_set_bounds_and_immutability_on_invalid() -> void:
	var board := PuzzleBoard.create(3, 2)
	assert_true(board.set_orb(Vector2i(0, 0), OrbType.Id.ORB_1))
	assert_eq(board.orb_at(Vector2i(0, 0)), OrbType.Id.ORB_1)
	assert_true(board.has_orb(Vector2i(0, 0)))
	assert_true(board.is_empty(Vector2i(1, 0)))
	assert_false(board.in_bounds(Vector2i(-1, 0)))
	assert_false(board.in_bounds(Vector2i(3, 0)))
	assert_false(board.in_bounds(Vector2i(0, 2)))
	assert_eq(board.orb_at(Vector2i(9, 9)), -1)
	var snap_before := board.snapshot_orb_ids()
	assert_false(board.set_orb(Vector2i(9, 0), OrbType.Id.ORB_0))
	assert_false(board.set_orb(Vector2i(0, 0), 99))
	assert_eq(board.snapshot_orb_ids(), snap_before)


func test_snapshot_is_defensive() -> void:
	var board := PuzzleBoard.create(2, 2)
	assert_true(board.set_orb(Vector2i(0, 0), OrbType.Id.ORB_3))
	var snap: Array = board.snapshot_orb_ids()
	snap[0][0] = OrbType.Id.ORB_0
	assert_eq(board.orb_at(Vector2i(0, 0)), OrbType.Id.ORB_3)


func test_swap_adjacent_success_and_failures_atomic() -> void:
	var board := PuzzleBoard.create(3, 3)
	assert_true(board.set_orb(Vector2i(1, 1), OrbType.Id.ORB_0))
	assert_true(board.set_orb(Vector2i(2, 1), OrbType.Id.ORB_1))
	assert_true(board.set_orb(Vector2i(1, 2), OrbType.Id.ORB_2))
	# Horizontal adjacent
	assert_true(board.swap(Vector2i(1, 1), Vector2i(2, 1)))
	assert_eq(board.orb_at(Vector2i(1, 1)), OrbType.Id.ORB_1)
	assert_eq(board.orb_at(Vector2i(2, 1)), OrbType.Id.ORB_0)
	# Vertical adjacent
	assert_true(board.swap(Vector2i(1, 1), Vector2i(1, 2)))
	assert_eq(board.orb_at(Vector2i(1, 1)), OrbType.Id.ORB_2)
	assert_eq(board.orb_at(Vector2i(1, 2)), OrbType.Id.ORB_1)
	var before := board.snapshot_orb_ids()
	assert_false(board.swap(Vector2i(1, 1), Vector2i(1, 1))) # same
	assert_false(board.swap(Vector2i(0, 0), Vector2i(1, 1))) # empty / no orb
	assert_false(board.swap(Vector2i(1, 1), Vector2i(2, 2))) # diagonal
	assert_false(board.swap(Vector2i(1, 1), Vector2i(1, 1) + Vector2i(2, 0))) # non-adj
	assert_false(board.swap(Vector2i(1, 1), Vector2i(-1, 1))) # OOB
	assert_eq(board.snapshot_orb_ids(), before)


func test_stable_fill_dev_board_no_matches_multiple_seeds() -> void:
	var seeds: Array[int] = [1, 2, 7, 42, 99, 12345, 99991]
	for seed_value in seeds:
		var board := OrbGenerator.create_match_stable_board(6, 6, seed_value)
		assert_ne(board, null)
		assert_true(board.is_valid())
		assert_eq(board.width(), 6)
		assert_eq(board.height(), 6)
		for y in range(6):
			for x in range(6):
				assert_true(board.has_orb(Vector2i(x, y)))
				assert_true(OrbType.is_dev_id(board.orb_at(Vector2i(x, y))))
		assert_false(board.has_match_of_length_at_least(3))


func test_stable_fill_same_seed_same_board() -> void:
	var a := OrbGenerator.create_match_stable_board(6, 6, 777)
	var b := OrbGenerator.create_match_stable_board(6, 6, 777)
	assert_ne(a, null)
	assert_ne(b, null)
	assert_eq(a.snapshot_orb_ids(), b.snapshot_orb_ids())


func test_stable_fill_different_seeds_can_differ() -> void:
	var a := OrbGenerator.create_match_stable_board(6, 6, 10)
	var b := OrbGenerator.create_match_stable_board(6, 6, 11)
	assert_ne(a, null)
	assert_ne(b, null)
	assert_ne(a.snapshot_orb_ids(), b.snapshot_orb_ids())


func test_puzzle_cell_empty_and_orb() -> void:
	var empty := PuzzleCell.empty()
	assert_true(empty.is_empty())
	assert_false(empty.has_orb())
	assert_eq(empty.orb_id(), -1)
	var cell := PuzzleCell.with_orb(OrbType.Id.ORB_4)
	assert_true(cell.has_orb())
	assert_eq(cell.orb_id(), OrbType.Id.ORB_4)
	assert_false(cell.set_orb(99))
	assert_eq(cell.orb_id(), OrbType.Id.ORB_4)
	var copy := cell.duplicate_cell()
	copy.clear_orb()
	assert_true(cell.has_orb())
	assert_true(copy.is_empty())
