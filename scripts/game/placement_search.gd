class_name PlacementSearch
extends RefCounted

## Phase 1-B: exhaustive placement search using BoardState.can_place as SoT.
## Origin ranges account for negative / translated piece offsets.


## True if there exists any origin where board.can_place(piece, origin) holds.
static func can_place_anywhere(board: BoardState, piece: PieceShape) -> bool:
	if board == null or not board.is_valid():
		return false
	if piece == null or not piece.is_valid():
		return false

	var min_off := piece.min_offset()
	var max_off := piece.max_offset()
	var origin_x_min := -min_off.x
	var origin_x_max := board.width() - 1 - max_off.x
	var origin_y_min := -min_off.y
	var origin_y_max := board.height() - 1 - max_off.y

	if origin_x_min > origin_x_max or origin_y_min > origin_y_max:
		return false

	for y in range(origin_y_min, origin_y_max + 1):
		for x in range(origin_x_min, origin_x_max + 1):
			if board.can_place(piece, Vector2i(x, y)):
				return true
	return false


## True if any remaining tray piece can be placed somewhere on the board.
## Empty tray / invalid inputs → false. This is NOT a Game Over API.
static func has_any_placeable_piece(board: BoardState, tray: PieceTray) -> bool:
	if board == null or not board.is_valid():
		return false
	if tray == null or not tray.is_valid():
		return false
	if tray.is_empty():
		return false

	for i in range(tray.slot_count()):
		if not tray.has_piece(i):
			continue
		var piece := tray.piece_at(i)
		if can_place_anywhere(board, piece):
			return true
	return false
