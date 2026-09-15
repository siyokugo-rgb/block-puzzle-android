class_name DevPlayConfig
extends RefCounted

## Phase 1-D development-only play settings.
## NOT a production / final board size or piece catalog.
## Final board size and production catalog remain unspecified.

## Development board size for the playable slice (not FINAL / production).
const DEV_BOARD_WIDTH := 8
const DEV_BOARD_HEIGHT := 8

## Finger preview offset in multiples of cell size (upward). Tunable after device QA.
const DEV_DRAG_FINGER_OFFSET_CELLS := 1.25


## Development catalog for Phase 1-D only (not production).
static func create_dev_catalog() -> PieceCatalog:
	var pieces: Array = [
		PieceShape.create_single_cell(),
		PieceShape.create([Vector2i(0, 0), Vector2i(1, 0)]), # 2 horizontal
		PieceShape.create([Vector2i(0, 0), Vector2i(0, 1)]), # 2 vertical
		PieceShape.create([Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]), # small L
		PieceShape.create([
			Vector2i(0, 0), Vector2i(1, 0),
			Vector2i(0, 1), Vector2i(1, 1),
		]), # 2x2 square
	]
	return PieceCatalog.create(pieces)


static func create_dev_session(seed_value: int = 1) -> GameSession:
	var catalog := create_dev_catalog()
	var generator := PieceGenerator.create(catalog)
	generator.set_seed(seed_value)
	return GameSession.create(DEV_BOARD_WIDTH, DEV_BOARD_HEIGHT, generator)
