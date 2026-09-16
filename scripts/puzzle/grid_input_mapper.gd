class_name GridInputMapper
extends RefCounted

## Phase R-F: pointer ownership + orthogonal route interpolation.
## Converts non-adjacent pointer cells into adjacent 4-dir steps for PuzzleSession.


enum PointerSource {
	NONE,
	TOUCH,
	MOUSE,
}

## Active ownership (UI-side). Domain session is separate.
var source: PointerSource = PointerSource.NONE
var touch_index: int = -1


func clear() -> void:
	source = PointerSource.NONE
	touch_index = -1


func begin_touch(index: int) -> bool:
	if source != PointerSource.NONE:
		return false
	source = PointerSource.TOUCH
	touch_index = index
	return true


func begin_mouse() -> bool:
	if source != PointerSource.NONE:
		return false
	source = PointerSource.MOUSE
	touch_index = -1
	return true


func accepts_touch(index: int) -> bool:
	return source == PointerSource.TOUCH and touch_index == index


func accepts_mouse() -> bool:
	return source == PointerSource.MOUSE


func is_active() -> bool:
	return source != PointerSource.NONE


## Build orthogonal adjacent steps from current → target (includes target, excludes current).
## Gate 1 DEV rule: prefer X when |dx| >= |dy| and dx != 0; else Y if dy != 0. Tie → X first.
static func interpolate_orthogonal(current: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if current == target:
		return out
	var cur := current
	var guard := 0
	var max_steps := absi(target.x - current.x) + absi(target.y - current.y) + 8
	while cur != target and guard < max_steps:
		guard += 1
		var dx := target.x - cur.x
		var dy := target.y - cur.y
		var step := Vector2i.ZERO
		if absi(dx) >= absi(dy) and dx != 0:
			step = Vector2i(signi(dx), 0)
		elif dy != 0:
			step = Vector2i(0, signi(dy))
		else:
			break
		cur += step
		out.append(cur)
	return out
