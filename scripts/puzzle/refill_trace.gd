class_name RefillTrace
extends RefCounted

## One orb spawn into an empty cell during cascade refill.

var _pos: Vector2i = Vector2i(-1, -1)
var _orb_id: int = -1


static func create(pos: Vector2i, orb_id: int) -> RefillTrace:
	var t := RefillTrace.new()
	t._pos = pos
	t._orb_id = orb_id
	return t


func pos() -> Vector2i:
	return _pos


func orb_id() -> int:
	return _orb_id


func duplicate_trace() -> RefillTrace:
	return create(_pos, _orb_id)
