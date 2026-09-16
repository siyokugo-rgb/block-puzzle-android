class_name PuzzleCell
extends RefCounted

## Phase R-A: one board cell — optional orb or empty.
## Obstacle slot is intentionally absent/unimplemented (ROCK later).

var _orb_id: int = -1 # -1 = empty; otherwise OrbType.Id


static func empty() -> PuzzleCell:
	return PuzzleCell.new()


static func with_orb(orb_id: int) -> PuzzleCell:
	var cell := PuzzleCell.new()
	if OrbType.is_dev_id(orb_id):
		cell._orb_id = orb_id
	return cell


func is_empty() -> bool:
	return _orb_id < 0


func has_orb() -> bool:
	return _orb_id >= 0


## OrbType.Id when present; -1 when empty.
func orb_id() -> int:
	return _orb_id


func clear_orb() -> void:
	_orb_id = -1


func set_orb(orb_id: int) -> bool:
	if not OrbType.is_dev_id(orb_id):
		return false
	_orb_id = orb_id
	return true


func duplicate_cell() -> PuzzleCell:
	var copy := PuzzleCell.new()
	copy._orb_id = _orb_id
	return copy
