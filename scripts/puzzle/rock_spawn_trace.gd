class_name RockSpawnTrace
extends RefCounted

## Session-level ROCK respawn after a resolved move (not cascade-internal).

var _pos: Vector2i = Vector2i(-1, -1)
var _hp: int = 0


static func create(pos: Vector2i, hp: int) -> RockSpawnTrace:
	var t := RockSpawnTrace.new()
	t._pos = pos
	t._hp = hp
	return t


func pos() -> Vector2i:
	return _pos


func hp() -> int:
	return _hp


func duplicate_trace() -> RockSpawnTrace:
	return create(_pos, _hp)
