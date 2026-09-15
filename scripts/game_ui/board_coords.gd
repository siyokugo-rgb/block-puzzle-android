class_name BoardCoords
extends RefCounted

## Pixel ↔ board-cell conversion for Phase 1-D UI.
## Owns the single conversion site; GameSession never receives pixels.

var _origin_local: Vector2 = Vector2.ZERO
var _cell_size: float = 1.0
var _width: int = 0
var _height: int = 0


static func create(origin_local: Vector2, cell_size: float, width: int, height: int) -> BoardCoords:
	var coords := BoardCoords.new()
	coords._origin_local = origin_local
	coords._cell_size = maxf(cell_size, 0.0001)
	coords._width = maxi(width, 0)
	coords._height = maxi(height, 0)
	return coords


func origin_local() -> Vector2:
	return _origin_local


func cell_size() -> float:
	return _cell_size


func board_width() -> int:
	return _width


func board_height() -> int:
	return _height


func board_pixel_size() -> Vector2:
	return Vector2(_cell_size * float(_width), _cell_size * float(_height))


## Floor mapping from local pixel (board parent space) to cell. May be out of bounds.
func local_to_cell(local_pos: Vector2) -> Vector2i:
	var rel := local_pos - _origin_local
	return Vector2i(floori(rel.x / _cell_size), floori(rel.y / _cell_size))


func is_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _width and cell.y < _height


func contains_local(local_pos: Vector2) -> bool:
	return is_cell_in_bounds(local_to_cell(local_pos))


## Top-left pixel of a cell in local space.
func cell_to_local(cell: Vector2i) -> Vector2:
	return _origin_local + Vector2(float(cell.x) * _cell_size, float(cell.y) * _cell_size)


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell_to_local(cell), Vector2(_cell_size, _cell_size))


func board_rect() -> Rect2:
	return Rect2(_origin_local, board_pixel_size())
