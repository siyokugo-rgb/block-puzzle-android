class_name BoardView
extends Control

## Draws board occupancy + optional placement preview. Not a domain owner.

const COLOR_EMPTY := Color(0.16, 0.18, 0.22, 1.0)
const COLOR_GRID := Color(0.28, 0.32, 0.38, 1.0)
const COLOR_OCCUPIED := Color(0.35, 0.72, 0.55, 1.0)
const COLOR_PREVIEW_VALID := Color(0.35, 0.75, 0.95, 0.55)
const COLOR_PREVIEW_INVALID := Color(0.90, 0.35, 0.35, 0.55)

var _session: GameSession
var _coords: BoardCoords
var _preview_cells: Array[Vector2i] = []
var _preview_valid: bool = false


func bind_session(session: GameSession) -> void:
	_session = session
	queue_redraw()


func set_coords(coords: BoardCoords) -> void:
	_coords = coords
	queue_redraw()


func set_preview(cells: Array[Vector2i], valid: bool) -> void:
	_preview_cells = cells.duplicate()
	_preview_valid = valid
	queue_redraw()


func clear_preview() -> void:
	_preview_cells.clear()
	_preview_valid = false
	queue_redraw()


func _draw() -> void:
	if _session == null or not _session.is_valid() or _coords == null:
		return
	var w := _session.board_width()
	var h := _session.board_height()
	var cs := _coords.cell_size()
	for y in range(h):
		for x in range(w):
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(float(x) * cs, float(y) * cs), Vector2(cs, cs))
			var fill := COLOR_OCCUPIED if _session.is_occupied(cell) else COLOR_EMPTY
			draw_rect(rect, fill, true)
			draw_rect(rect, COLOR_GRID, false, 1.0)
	var preview_color := COLOR_PREVIEW_VALID if _preview_valid else COLOR_PREVIEW_INVALID
	for cell in _preview_cells:
		if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h:
			continue
		var rect := Rect2(Vector2(float(cell.x) * cs, float(cell.y) * cs), Vector2(cs, cs))
		draw_rect(rect, preview_color, true)
