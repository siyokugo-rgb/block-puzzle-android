class_name GravityMoveTrace
extends RefCounted

## One downward gravity relocation (Orb or ROCK) within a cascade step.

enum Kind {
	ORB = 0,
	ROCK = 1,
}

var _kind: int = Kind.ORB
var _from: Vector2i = Vector2i(-1, -1)
var _to: Vector2i = Vector2i(-1, -1)
var _orb_id: int = -1
var _rock_hp: int = 0


static func create_orb(from: Vector2i, to: Vector2i, orb_id: int) -> GravityMoveTrace:
	var t := GravityMoveTrace.new()
	t._kind = Kind.ORB
	t._from = from
	t._to = to
	t._orb_id = orb_id
	t._rock_hp = 0
	return t


static func create_rock(from: Vector2i, to: Vector2i, rock_hp: int) -> GravityMoveTrace:
	var t := GravityMoveTrace.new()
	t._kind = Kind.ROCK
	t._from = from
	t._to = to
	t._orb_id = -1
	t._rock_hp = rock_hp
	return t


## Back-compat alias for Orb moves.
static func create(from: Vector2i, to: Vector2i, orb_id: int) -> GravityMoveTrace:
	return create_orb(from, to, orb_id)


func kind() -> int:
	return _kind


func is_orb() -> bool:
	return _kind == Kind.ORB


func is_rock() -> bool:
	return _kind == Kind.ROCK


func from_cell() -> Vector2i:
	return _from


func to_cell() -> Vector2i:
	return _to


func orb_id() -> int:
	return _orb_id


func rock_hp() -> int:
	return _rock_hp


func duplicate_trace() -> GravityMoveTrace:
	if is_rock():
		return create_rock(_from, _to, _rock_hp)
	return create_orb(_from, _to, _orb_id)
