class_name PuzzleCell
extends RefCounted

## Phase R-A / R-G: one board cell — optional orb and optional obstacle.
## ROCK invariant: ROCK cells never hold an orb.

var _orb_id: int = -1 # -1 = empty orb slot; otherwise OrbType.Id
var _obstacle_id: int = ObstacleType.Id.NONE


static func empty() -> PuzzleCell:
	return PuzzleCell.new()


static func with_orb(orb_id: int) -> PuzzleCell:
	## Returns a cell with the orb, or null if orb_id is not a valid DEV OrbType.
	## Invalid ids must not be silently treated as empty.
	if not OrbType.is_dev_id(orb_id):
		return null
	var cell := PuzzleCell.new()
	cell._orb_id = orb_id
	cell._obstacle_id = ObstacleType.Id.NONE
	return cell


## True only when no orb and no obstacle.
func is_empty() -> bool:
	return _orb_id < 0 and _obstacle_id == ObstacleType.Id.NONE


func has_orb() -> bool:
	return _orb_id >= 0


func has_obstacle() -> bool:
	return _obstacle_id != ObstacleType.Id.NONE


func is_rock() -> bool:
	return ObstacleType.is_rock(_obstacle_id)


## OrbType.Id when present; -1 when no orb.
func orb_id() -> int:
	return _orb_id


func obstacle_id() -> int:
	return _obstacle_id


func clear_orb() -> void:
	_orb_id = -1


## Clears obstacle only. Does not change orb.
func clear_obstacle() -> void:
	_obstacle_id = ObstacleType.Id.NONE


## Sets orb. Fails on invalid id or when cell is ROCK.
func set_orb(orb_id: int) -> bool:
	if is_rock():
		return false
	if not OrbType.is_dev_id(orb_id):
		return false
	_orb_id = orb_id
	return true


## Sets ROCK and clears any orb (ROCK+Orb forbidden). Invalid ids fail closed.
func set_obstacle(obstacle_id: int) -> bool:
	if not ObstacleType.is_valid_id(obstacle_id):
		return false
	if obstacle_id == ObstacleType.Id.NONE:
		_obstacle_id = ObstacleType.Id.NONE
		return true
	# ROCK: clear orb first (invariant).
	_orb_id = -1
	_obstacle_id = obstacle_id
	return true


func set_rock() -> bool:
	return set_obstacle(ObstacleType.Id.ROCK)


func duplicate_cell() -> PuzzleCell:
	var copy := PuzzleCell.new()
	copy._orb_id = _orb_id
	copy._obstacle_id = _obstacle_id
	return copy
