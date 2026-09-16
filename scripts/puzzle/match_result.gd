class_name MatchResult
extends RefCounted

## Phase R-C: immutable-equivalent match detection result.
## Cells are stored row-major (y asc, then x asc). No score/combo fields.

var _valid: bool = false
var _cells: Array[Vector2i] = []


static func invalid() -> MatchResult:
	var result := MatchResult.new()
	result._valid = false
	result._cells.clear()
	return result


## Build from a set of matched cells. Deduplicates and sorts row-major.
static func from_cells(matched: Array) -> MatchResult:
	var result := MatchResult.new()
	result._valid = true
	var seen: Dictionary = {}
	var unique: Array[Vector2i] = []
	for item in matched:
		if typeof(item) != TYPE_VECTOR2I:
			continue
		var cell: Vector2i = item
		var key := "%d,%d" % [cell.x, cell.y]
		if seen.has(key):
			continue
		seen[key] = true
		unique.append(cell)
	unique.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	result._cells = unique
	return result


static func empty_valid() -> MatchResult:
	return from_cells([])


func is_valid() -> bool:
	return _valid


func has_matches() -> bool:
	return _valid and not _cells.is_empty()


func matched_cell_count() -> int:
	return _cells.size() if _valid else 0


## Defensive copy; external mutation cannot alter this result.
func matched_cells_snapshot() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not _valid:
		return out
	out.assign(_cells)
	return out
