class_name PuzzleCell
extends RefCounted

## Phase R-A / R-G: one board cell — optional orb and optional obstacle.
## ROCK invariant: ROCK cells never hold an orb.
## Gate 2 DEV: ROCK durability starts at HP=2 (not production final).

const ROCK_INITIAL_HP := 2

var _orb_id: int = -1 # -1 = empty orb slot; otherwise OrbType.Id
var _obstacle_id: int = ObstacleType.Id.NONE
var _obstacle_hp: int = 0


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
	cell._obstacle_hp = 0
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


## 0 when NONE; 1 or 2 when ROCK.
func obstacle_hp() -> int:
	return _obstacle_hp


func clear_orb() -> void:
	_orb_id = -1


## Clears obstacle only. Does not change orb.
func clear_obstacle() -> void:
	_obstacle_id = ObstacleType.Id.NONE
	_obstacle_hp = 0


## Sets orb. Fails on invalid id or when cell is ROCK.
func set_orb(orb_id: int) -> bool:
	if is_rock():
		return false
	if not OrbType.is_dev_id(orb_id):
		return false
	_orb_id = orb_id
	return true


## Sets obstacle. NONE clears. ROCK places initial HP=2 and clears orb.
## Existing ROCK is unchanged (no silent HP reset) → false.
## Invalid ids fail closed.
func set_obstacle(obstacle_id: int) -> bool:
	if not ObstacleType.is_valid_id(obstacle_id):
		return false
	if obstacle_id == ObstacleType.Id.NONE:
		_obstacle_id = ObstacleType.Id.NONE
		_obstacle_hp = 0
		return true
	# ROCK: refuse reset of existing ROCK (no gameplay HP heal via set_rock).
	if is_rock():
		return false
	_orb_id = -1
	_obstacle_id = obstacle_id
	_obstacle_hp = ROCK_INITIAL_HP
	return true


func set_rock() -> bool:
	return set_obstacle(ObstacleType.Id.ROCK)


## Place ROCK with explicit HP on an empty cell (gravity / internal moves).
## Clears orb if somehow present. Does not reset via set_rock().
func place_rock_with_hp(hp: int) -> bool:
	if hp != 1 and hp != 2:
		return false
	if is_rock():
		return false
	_orb_id = -1
	_obstacle_id = ObstacleType.Id.ROCK
	_obstacle_hp = hp
	return true


## Apply one cascade-step hit. Returns remaining HP after hit (1 or 0), or -1 if not ROCK.
## HP2 → 1 (still ROCK). HP1 → 0 and clears obstacle.
func damage_rock() -> int:
	if not is_rock():
		return -1
	if _obstacle_hp <= 1:
		clear_obstacle()
		return 0
	_obstacle_hp -= 1
	return _obstacle_hp


func duplicate_cell() -> PuzzleCell:
	var copy := PuzzleCell.new()
	copy._orb_id = _orb_id
	copy._obstacle_id = _obstacle_id
	copy._obstacle_hp = _obstacle_hp
	return copy
