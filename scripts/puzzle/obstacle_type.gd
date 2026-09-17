class_name ObstacleType
extends RefCounted

## Phase R-G: obstacle catalog. Gate 2 implements ROCK only.
## LOCK / SLIME are reserved ids but must not be constructed in R-G.

enum Id {
	NONE = 0,
	ROCK = 1,
	# Reserved (unimplemented in R-G):
	# LOCK = 2,
	# SLIME = 3,
}


static func is_valid_id(obstacle_id: int) -> bool:
	return obstacle_id == Id.NONE or obstacle_id == Id.ROCK


static func is_rock(obstacle_id: int) -> bool:
	return obstacle_id == Id.ROCK
