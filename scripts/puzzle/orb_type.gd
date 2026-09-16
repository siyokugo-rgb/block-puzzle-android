class_name OrbType
extends RefCounted

## Phase R-A: normal orb identity only (not ROCK / LOCK / SLIME).
## DEV catalog has exactly five kinds: ORB_0 … ORB_4.
## Rendering colors are UI concern — not encoded here.

enum Id {
	ORB_0 = 0,
	ORB_1 = 1,
	ORB_2 = 2,
	ORB_3 = 3,
	ORB_4 = 4,
}

const DEV_TYPE_COUNT := 5


static func is_dev_id(id: int) -> bool:
	return id >= Id.ORB_0 and id <= Id.ORB_4


static func all_dev_ids() -> Array[int]:
	var out: Array[int] = [Id.ORB_0, Id.ORB_1, Id.ORB_2, Id.ORB_3, Id.ORB_4]
	return out


static func id_name(id: int) -> String:
	match id:
		Id.ORB_0:
			return "ORB_0"
		Id.ORB_1:
			return "ORB_1"
		Id.ORB_2:
			return "ORB_2"
		Id.ORB_3:
			return "ORB_3"
		Id.ORB_4:
			return "ORB_4"
		_:
			return "INVALID"
