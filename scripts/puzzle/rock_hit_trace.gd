class_name RockHitTrace
extends RefCounted

## One ROCK damage event within a cascade step (presentation / QA).

var _pos: Vector2i = Vector2i(-1, -1)
var _hp_before: int = 0
var _hp_after: int = 0
var _destroyed: bool = false


static func create(pos: Vector2i, hp_before: int, hp_after: int, destroyed: bool) -> RockHitTrace:
	var t := RockHitTrace.new()
	t._pos = pos
	t._hp_before = hp_before
	t._hp_after = hp_after
	t._destroyed = destroyed
	return t


func pos() -> Vector2i:
	return _pos


func hp_before() -> int:
	return _hp_before


func hp_after() -> int:
	return _hp_after


func is_destroyed() -> bool:
	return _destroyed


func duplicate_trace() -> RockHitTrace:
	return create(_pos, _hp_before, _hp_after, _destroyed)
