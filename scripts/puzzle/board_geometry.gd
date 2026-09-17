class_name BoardGeometry
extends RefCounted

## Phase R-F: pixel ↔ board-cell mapping. Domain never sees pixels.


var _origin: Vector2 = Vector2.ZERO
var _cell_size: float = 1.0
var _width: int = 0
var _height: int = 0


static func create(origin: Vector2, cell_size: float, width: int, height: int) -> BoardGeometry:
	var g := BoardGeometry.new()
	g._origin = origin
	g._cell_size = maxf(cell_size, 0.0001)
	g._width = maxi(width, 0)
	g._height = maxi(height, 0)
	return g


func origin() -> Vector2:
	return _origin


func cell_size() -> float:
	return _cell_size


func width() -> int:
	return _width


func height() -> int:
	return _height


func board_rect() -> Rect2:
	return Rect2(_origin, Vector2(_cell_size * float(_width), _cell_size * float(_height)))


func contains_pixel(pixel: Vector2) -> bool:
	return board_rect().has_point(pixel)


## Returns cell for a pixel inside the board, or Vector2i(-1, -1) if outside.
func pixel_to_cell(pixel: Vector2) -> Vector2i:
	if _width <= 0 or _height <= 0:
		return Vector2i(-1, -1)
	if not contains_pixel(pixel):
		return Vector2i(-1, -1)
	var local := pixel - _origin
	var x := int(floor(local.x / _cell_size))
	var y := int(floor(local.y / _cell_size))
	# Clamp edge case when pixel is exactly on the right/bottom edge of the rect.
	x = clampi(x, 0, _width - 1)
	y = clampi(y, 0, _height - 1)
	return Vector2i(x, y)


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		_origin + Vector2(float(cell.x) * _cell_size, float(cell.y) * _cell_size),
		Vector2(_cell_size, _cell_size)
	)
