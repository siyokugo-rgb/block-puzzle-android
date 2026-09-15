extends GutTest

## Phase 1-B: catalog / generator / tray / placement search.


func _sample_catalog() -> PieceCatalog:
	return PieceCatalog.create([
		PieceShape.create_single_cell(),
		PieceShape.create([Vector2i(0, 0), Vector2i(1, 0)]),
		PieceShape.create([Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]),
	])


func _cells_key(piece: PieceShape) -> String:
	var parts: PackedStringArray = []
	for c in piece.cells():
		parts.append("%d,%d" % [c.x, c.y])
	return "|".join(parts)


func test_catalog_accepts_valid_pieces() -> void:
	var catalog := _sample_catalog()
	assert_true(catalog.is_valid())
	assert_eq(catalog.size(), 3)
	assert_true(catalog.piece_at(0).is_valid())
	assert_eq(catalog.piece_at(0).cell_count(), 1)


func test_catalog_rejects_empty_null_invalid() -> void:
	assert_false(PieceCatalog.create([]).is_valid())
	assert_false(PieceCatalog.create([null]).is_valid())
	assert_false(PieceCatalog.create([PieceShape.create([])]).is_valid())
	assert_false(PieceCatalog.create([PieceShape.create_single_cell(), null]).is_valid())


func test_catalog_defensive_copies_from_input_and_output() -> void:
	var source: Array = [PieceShape.create_single_cell(), PieceShape.create([Vector2i(0, 0), Vector2i(1, 0)])]
	var catalog := PieceCatalog.create(source)
	assert_true(catalog.is_valid())

	source.clear()
	source.append(PieceShape.create([Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]))
	assert_eq(catalog.size(), 2)
	assert_eq(catalog.piece_at(0).cell_count(), 1)

	var exported := catalog.pieces()
	assert_eq(exported.size(), 2)
	exported.clear()
	assert_eq(catalog.size(), 2)
	assert_eq(catalog.piece_at(1).cell_count(), 2)


func test_generator_draws_only_from_catalog() -> void:
	var catalog := _sample_catalog()
	var allowed: Dictionary = {}
	for piece in catalog.pieces():
		allowed[_cells_key(piece)] = true

	var generator := PieceGenerator.create(catalog)
	generator.set_seed(42)
	assert_true(generator.is_valid())
	for _i in range(30):
		var piece := generator.generate_piece()
		assert_true(piece != null and piece.is_valid())
		assert_true(allowed.has(_cells_key(piece)))


func test_generator_same_seed_same_sequence() -> void:
	var catalog := _sample_catalog()
	var a := PieceGenerator.create(catalog)
	var b := PieceGenerator.create(catalog)
	a.set_seed(7)
	b.set_seed(7)
	var seq_a: Array[String] = []
	var seq_b: Array[String] = []
	for _i in range(12):
		seq_a.append(_cells_key(a.generate_piece()))
		seq_b.append(_cells_key(b.generate_piece()))
	assert_eq(seq_a, seq_b)


func test_generator_different_seed_runs() -> void:
	## Different seeds are supported; sequence inequality is not asserted as a hard requirement.
	var catalog := _sample_catalog()
	var a := PieceGenerator.create(catalog)
	var b := PieceGenerator.create(catalog)
	a.set_seed(1)
	b.set_seed(99991)
	assert_true(a.generate_piece().is_valid())
	assert_true(b.generate_piece().is_valid())


func test_generator_generate_three_and_invalid_catalog() -> void:
	var catalog := _sample_catalog()
	var generator := PieceGenerator.create(catalog)
	generator.set_seed(3)
	var three := generator.generate_three()
	assert_eq(three.size(), 3)
	for piece in three:
		assert_true(piece.is_valid())

	var bad := PieceGenerator.create(PieceCatalog.create([]))
	assert_false(bad.is_valid())
	assert_true(bad.generate_piece() == null)
	assert_eq(bad.generate_three().size(), 0)


func test_tray_three_slots_consume_semantics() -> void:
	var pieces := _sample_catalog().pieces()
	var tray := PieceTray.create(pieces)
	assert_true(tray.is_valid())
	assert_eq(tray.slot_count(), 3)
	assert_eq(tray.remaining_count(), 3)
	assert_false(tray.is_empty())
	for i in range(3):
		assert_true(tray.has_piece(i))
		assert_true(tray.piece_at(i).is_valid())

	assert_true(tray.consume(1))
	assert_false(tray.has_piece(1))
	assert_true(tray.piece_at(1) == null)
	assert_eq(tray.remaining_count(), 2)
	assert_true(tray.has_piece(0))
	assert_true(tray.has_piece(2))

	assert_false(tray.consume(1)) # duplicate consume
	assert_eq(tray.remaining_count(), 2)

	assert_true(tray.consume(0))
	assert_true(tray.consume(2))
	assert_true(tray.is_empty())
	assert_eq(tray.remaining_count(), 0)


func test_tray_invalid_index_and_invalid_create_leave_state() -> void:
	var tray := PieceTray.create(_sample_catalog().pieces())
	var before := tray.remaining_count()
	assert_false(tray.consume(-1))
	assert_false(tray.consume(3))
	assert_false(tray.has_piece(-1))
	assert_false(tray.has_piece(3))
	assert_true(tray.piece_at(-1) == null)
	assert_true(tray.piece_at(3) == null)
	assert_eq(tray.remaining_count(), before)

	assert_false(PieceTray.create([]).is_valid())
	assert_false(PieceTray.create([PieceShape.create_single_cell()]).is_valid())
	assert_false(PieceTray.create([
		PieceShape.create_single_cell(),
		PieceShape.create_single_cell(),
		PieceShape.create([]),
	]).is_valid())


func test_placement_search_basic_empty_and_blocked() -> void:
	var board := BoardState.create(3, 3)
	var mono := PieceShape.create_single_cell()
	assert_true(PlacementSearch.can_place_anywhere(board, mono))

	for y in range(3):
		for x in range(3):
			assert_true(board.place(mono, Vector2i(x, y)))
	assert_false(PlacementSearch.can_place_anywhere(board, mono))


func test_placement_search_too_large_piece() -> void:
	var board := BoardState.create(2, 2)
	var long_bar := PieceShape.create([
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	])
	assert_false(PlacementSearch.can_place_anywhere(board, long_bar))


func test_placement_search_edge_only_origins() -> void:
	var board := BoardState.create(3, 3)
	# Fill all but the rightmost column so a vertical 3-bar only fits at x=2.
	for y in range(3):
		for x in range(2):
			assert_true(board.place(PieceShape.create_single_cell(), Vector2i(x, y)))
	var tall := PieceShape.create([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)])
	assert_true(PlacementSearch.can_place_anywhere(board, tall))
	assert_true(board.can_place(tall, Vector2i(2, 0)))
	assert_false(board.can_place(tall, Vector2i(1, 0)))

	var board2 := BoardState.create(3, 3)
	for y in range(2):
		for x in range(3):
			assert_true(board2.place(PieceShape.create_single_cell(), Vector2i(x, y)))
	var wide := PieceShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	assert_true(PlacementSearch.can_place_anywhere(board2, wide))
	assert_true(board2.can_place(wide, Vector2i(0, 2)))


func test_placement_search_single_legal_cell() -> void:
	var board := BoardState.create(2, 2)
	assert_true(board.place(PieceShape.create_single_cell(), Vector2i(0, 0)))
	assert_true(board.place(PieceShape.create_single_cell(), Vector2i(1, 0)))
	assert_true(board.place(PieceShape.create_single_cell(), Vector2i(0, 1)))
	var mono := PieceShape.create_single_cell()
	assert_true(PlacementSearch.can_place_anywhere(board, mono))
	assert_true(board.can_place(mono, Vector2i(1, 1)))
	assert_false(board.can_place(mono, Vector2i(0, 0)))


func test_placement_search_negative_and_translated_offsets() -> void:
	var board := BoardState.create(3, 3)
	# Negative offset: cells at origin+(-1,0) and origin+(0,0)
	var neg := PieceShape.create([Vector2i(-1, 0), Vector2i(0, 0)])
	assert_true(neg.is_valid())
	assert_true(PlacementSearch.can_place_anywhere(board, neg))
	# origin_x_min = -(-1) = 1; place at (1,0) occupies (0,0) and (1,0)
	assert_true(board.can_place(neg, Vector2i(1, 0)))
	assert_false(board.can_place(neg, Vector2i(0, 0))) # would go to x=-1

	# Translated shape with no (0,0) cell.
	var shifted := PieceShape.create([Vector2i(2, 2), Vector2i(3, 2)])
	assert_true(shifted.is_valid())
	assert_true(PlacementSearch.can_place_anywhere(board, shifted))
	# origin_x_min = -2, origin_x_max = 3-1-3 = -1 → only x=-2..-1
	assert_true(board.can_place(shifted, Vector2i(-2, -2))) # occupies (0,0)(1,0)
	assert_false(board.can_place(shifted, Vector2i(0, 0))) # would occupy (2,2)(3,2) OOB


func test_placement_search_invalid_inputs() -> void:
	var board := BoardState.create(2, 2)
	assert_false(PlacementSearch.can_place_anywhere(board, PieceShape.create([])))
	assert_false(PlacementSearch.can_place_anywhere(board, null))
	assert_false(PlacementSearch.can_place_anywhere(BoardState.create(0, 2), PieceShape.create_single_cell()))
	assert_false(PlacementSearch.can_place_anywhere(null, PieceShape.create_single_cell()))


func test_tray_placeability_partial_and_none() -> void:
	var mono := PieceShape.create_single_cell()
	var bar := PieceShape.create([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	var tall := PieceShape.create([Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)])
	var tray := PieceTray.create([mono, bar, tall])

	var board := BoardState.create(2, 2)
	# Only mono fits on 2x2; bar/tall do not.
	assert_true(PlacementSearch.has_any_placeable_piece(board, tray))

	# Fill board completely → none placeable.
	for y in range(2):
		for x in range(2):
			assert_true(board.place(mono, Vector2i(x, y)))
	assert_false(PlacementSearch.has_any_placeable_piece(board, tray))


func test_tray_placeability_multiple_and_consumed_slots() -> void:
	var mono := PieceShape.create_single_cell()
	var bar2 := PieceShape.create([Vector2i(0, 0), Vector2i(1, 0)])
	var tray := PieceTray.create([mono, bar2, mono])
	var board := BoardState.create(3, 3)
	assert_true(PlacementSearch.has_any_placeable_piece(board, tray))

	assert_true(tray.consume(0))
	assert_true(PlacementSearch.has_any_placeable_piece(board, tray))

	assert_true(tray.consume(1))
	assert_true(tray.consume(2))
	assert_true(tray.is_empty())
	assert_false(PlacementSearch.has_any_placeable_piece(board, tray))


func test_piece_shape_bounds_helpers_do_not_change_semantics() -> void:
	var piece := PieceShape.create([Vector2i(2, -1), Vector2i(3, -1), Vector2i(2, 0)])
	assert_true(piece.is_valid())
	assert_eq(piece.min_offset(), Vector2i(2, -1))
	assert_eq(piece.max_offset(), Vector2i(3, 0))
	# Still rejects duplicates / empty as before.
	assert_false(PieceShape.create([]).is_valid())
	assert_false(PieceShape.create([Vector2i(0, 0), Vector2i(0, 0)]).is_valid())
