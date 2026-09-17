class_name GravityMoveTrace
extends RefCounted

## One orb gravity relocation within a cascade step.

var _from: Vector2i = Vector2i(-1, -1)
var _to: Vector2i = Vector2i(-1, -1)
var _orb_id: int = -1


static func create(from: Vector2i, to: Vector2i, orb_id: int) -> GravityMoveTrace:
	var t := GravityMoveTrace.new()
	t._from = from
	t._to = to
	t._orb_id = orb_id
	return t


func from_cell() -> Vector2i:
	return _from


func to_cell() -> Vector2i:
	return _to


func orb_id() -> int:
	return _orb_id


func duplicate_trace() -> GravityMoveTrace:
	return create(_from, _to, _orb_id)
