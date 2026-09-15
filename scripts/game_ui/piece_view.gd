class_name PieceView
extends Control

## Draws a PieceShape in local pixel space. Display-only; not domain state.

const COLOR_PIECE := Color(0.95, 0.78, 0.35, 1.0)
const COLOR_OUTLINE := Color(0.15, 0.12, 0.08, 1.0)
const COLOR_DIM := Color(0.45, 0.45, 0.48, 0.35)

var _piece: PieceShape
var _cell_size: float = 24.0
var _dimmed: bool = false


func set_piece(piece: PieceShape) -> void:
	_piece = piece
	_update_min_size()
	queue_redraw()


func set_cell_size(cell_size: float) -> void:
	_cell_size = maxf(cell_size, 1.0)
	_update_min_size()
	queue_redraw()


func set_dimmed(dimmed: bool) -> void:
	_dimmed = dimmed
	queue_redraw()


func clear_piece() -> void:
	_piece = null
	custom_minimum_size = Vector2.ZERO
	queue_redraw()


func _update_min_size() -> void:
	if _piece == null or not _piece.is_valid():
		custom_minimum_size = Vector2.ZERO
		return
	var min_o := _piece.min_offset()
	var max_o := _piece.max_offset()
	var w := float(max_o.x - min_o.x + 1) * _cell_size
	var h := float(max_o.y - min_o.y + 1) * _cell_size
	custom_minimum_size = Vector2(w, h)


func _draw() -> void:
	if _piece == null or not _piece.is_valid():
		return
	var min_o := _piece.min_offset()
	var max_o := _piece.max_offset()
	var shape_w := float(max_o.x - min_o.x + 1) * _cell_size
	var shape_h := float(max_o.y - min_o.y + 1) * _cell_size
	var origin := Vector2(
		maxf((size.x - shape_w) * 0.5, 0.0),
		maxf((size.y - shape_h) * 0.5, 0.0)
	)
	var fill := COLOR_DIM if _dimmed else COLOR_PIECE
	for offset in _piece.cells():
		var local := origin + Vector2(
			float(offset.x - min_o.x) * _cell_size,
			float(offset.y - min_o.y) * _cell_size
		)
		var rect := Rect2(local, Vector2(_cell_size, _cell_size))
		draw_rect(rect, fill, true)
		draw_rect(rect, COLOR_OUTLINE, false, 1.0)
