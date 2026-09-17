class_name ResolutionPresenter
extends RefCounted

## Presentation-only playback of SessionMoveResult traces.
## Does not own gameplay state; never reimplements match/gravity/refill.

enum Phase {
	IDLE,
	MATCH,
	ROCK_HIT,
	GRAVITY,
	REFILL,
	RESPAWN_WARN,
	RESPAWN_SHOW,
	DONE,
}

const MATCH_MS := 120.0
const ROCK_HIT_MS := 130.0
const GRAVITY_MS := 200.0
const REFILL_MS := 180.0
const RESPAWN_WARN_MS := 150.0
const RESPAWN_SHOW_MS := 150.0

var busy: bool = false
var phase: Phase = Phase.IDLE
var phase_elapsed_ms: float = 0.0
var step_index: int = 0
var steps: Array = []
var rock_spawns: Array = []
var vis_orbs: Array = []
var vis_obstacles: Array = []
var vis_hp: Array = []
var highlight_cells: Array[Vector2i] = []
var rock_hit_cells: Array[Vector2i] = []
var gravity_progress: float = 0.0 # 0..1
var gravity_moves: Array = []
var refill_progress: float = 0.0
var refill_cells: Array = []
var spawn_cells: Array[Vector2i] = []
var flash_rocks: Array[Vector2i] = []


func is_busy() -> bool:
	return busy


func begin(move: SessionMoveResult) -> void:
	busy = false
	phase = Phase.IDLE
	if move == null or not move.is_success() or not move.has_presentation():
		return
	vis_orbs = _copy_grid(move.board_before_orbs_snapshot())
	vis_obstacles = _copy_grid(move.board_before_obstacles_snapshot())
	vis_hp = _copy_grid(move.board_before_hp_snapshot())
	if vis_orbs.is_empty():
		return
	steps = move.cascade_steps_snapshot()
	rock_spawns = move.rock_spawns_snapshot()
	step_index = 0
	busy = true
	if steps.is_empty():
		_begin_respawn_or_done()
	else:
		_begin_step_match()


func advance(delta_ms: float) -> void:
	if not busy:
		return
	phase_elapsed_ms += delta_ms
	match phase:
		Phase.MATCH:
			if phase_elapsed_ms >= MATCH_MS:
				_apply_rock_hits_to_vis()
				_begin_rock_hit()
		Phase.ROCK_HIT:
			if phase_elapsed_ms >= ROCK_HIT_MS:
				_clear_matched_from_vis()
				_begin_gravity()
		Phase.GRAVITY:
			gravity_progress = clampf(phase_elapsed_ms / GRAVITY_MS, 0.0, 1.0)
			if phase_elapsed_ms >= GRAVITY_MS:
				_commit_gravity_to_vis()
				_begin_refill()
		Phase.REFILL:
			refill_progress = clampf(phase_elapsed_ms / REFILL_MS, 0.0, 1.0)
			if phase_elapsed_ms >= REFILL_MS:
				_commit_refill_to_vis()
				step_index += 1
				if step_index < steps.size():
					_begin_step_match()
				else:
					_begin_respawn_or_done()
		Phase.RESPAWN_WARN:
			if phase_elapsed_ms >= RESPAWN_WARN_MS:
				_apply_spawns_to_vis()
				phase = Phase.RESPAWN_SHOW
				phase_elapsed_ms = 0.0
		Phase.RESPAWN_SHOW:
			if phase_elapsed_ms >= RESPAWN_SHOW_MS:
				_finish()
		_:
			pass


func orb_at(pos: Vector2i) -> int:
	if pos.y < 0 or pos.y >= vis_orbs.size():
		return -1
	var row: Array = vis_orbs[pos.y]
	if pos.x < 0 or pos.x >= row.size():
		return -1
	return int(row[pos.x])


func obstacle_at(pos: Vector2i) -> int:
	if pos.y < 0 or pos.y >= vis_obstacles.size():
		return ObstacleType.Id.NONE
	var row: Array = vis_obstacles[pos.y]
	if pos.x < 0 or pos.x >= row.size():
		return ObstacleType.Id.NONE
	return int(row[pos.x])


func rock_hp_at(pos: Vector2i) -> int:
	if pos.y < 0 or pos.y >= vis_hp.size():
		return 0
	var row: Array = vis_hp[pos.y]
	if pos.x < 0 or pos.x >= row.size():
		return 0
	return int(row[pos.x])


func is_rock(pos: Vector2i) -> bool:
	return ObstacleType.is_rock(obstacle_at(pos))


func gravity_draw_offset(pos: Vector2i, cell_size: float) -> Vector2:
	if phase != Phase.GRAVITY or gravity_moves.is_empty():
		return Vector2.ZERO
	for item in gravity_moves:
		var mv: GravityMoveTrace = item
		if mv.from_cell() == pos:
			var delta := Vector2(mv.to_cell() - mv.from_cell()) * cell_size * gravity_progress
			return delta
	return Vector2.ZERO


func refill_alpha(pos: Vector2i) -> float:
	if phase != Phase.REFILL:
		return 1.0
	for item in refill_cells:
		var rf: RefillTrace = item
		if rf.pos() == pos:
			return refill_progress
	return 1.0


func _begin_step_match() -> void:
	phase = Phase.MATCH
	phase_elapsed_ms = 0.0
	gravity_progress = 0.0
	refill_progress = 0.0
	rock_hit_cells.clear()
	flash_rocks.clear()
	spawn_cells.clear()
	var step: CascadeStepTrace = steps[step_index]
	highlight_cells = step.matched_cells_snapshot()
	gravity_moves = step.gravity_moves_snapshot()
	refill_cells = step.refills_snapshot()


func _begin_rock_hit() -> void:
	phase = Phase.ROCK_HIT
	phase_elapsed_ms = 0.0
	highlight_cells.clear()
	var step: CascadeStepTrace = steps[step_index]
	rock_hit_cells.clear()
	flash_rocks.clear()
	for item in step.rock_hits_snapshot():
		var hit: RockHitTrace = item
		rock_hit_cells.append(hit.pos())
		flash_rocks.append(hit.pos())


func _apply_rock_hits_to_vis() -> void:
	var step: CascadeStepTrace = steps[step_index]
	for item in step.rock_hits_snapshot():
		var hit: RockHitTrace = item
		var p := hit.pos()
		if hit.is_destroyed():
			_set_obs(p, ObstacleType.Id.NONE, 0)
		else:
			_set_obs(p, ObstacleType.Id.ROCK, hit.hp_after())


func _clear_matched_from_vis() -> void:
	var step: CascadeStepTrace = steps[step_index]
	for cell in step.matched_cells_snapshot():
		_set_orb(cell, -1)
	rock_hit_cells.clear()
	flash_rocks.clear()


func _begin_gravity() -> void:
	phase = Phase.GRAVITY
	phase_elapsed_ms = 0.0
	gravity_progress = 0.0


func _commit_gravity_to_vis() -> void:
	# Apply in reverse-safe order: clear sources then set destinations.
	var pending: Array = []
	for item in gravity_moves:
		var mv: GravityMoveTrace = item
		pending.append(mv)
		_set_orb(mv.from_cell(), -1)
	for item in pending:
		var mv2: GravityMoveTrace = item
		_set_orb(mv2.to_cell(), mv2.orb_id())
	gravity_progress = 1.0


func _begin_refill() -> void:
	phase = Phase.REFILL
	phase_elapsed_ms = 0.0
	refill_progress = 0.0
	for item in refill_cells:
		var rf: RefillTrace = item
		_set_orb(rf.pos(), rf.orb_id())


func _commit_refill_to_vis() -> void:
	refill_progress = 1.0


func _begin_respawn_or_done() -> void:
	highlight_cells.clear()
	rock_hit_cells.clear()
	flash_rocks.clear()
	if rock_spawns.is_empty():
		_finish()
		return
	spawn_cells.clear()
	for item in rock_spawns:
		var sp: RockSpawnTrace = item
		spawn_cells.append(sp.pos())
	phase = Phase.RESPAWN_WARN
	phase_elapsed_ms = 0.0


func _apply_spawns_to_vis() -> void:
	for item in rock_spawns:
		var sp: RockSpawnTrace = item
		_set_orb(sp.pos(), -1)
		_set_obs(sp.pos(), ObstacleType.Id.ROCK, sp.hp())


func _finish() -> void:
	busy = false
	phase = Phase.DONE
	highlight_cells.clear()
	rock_hit_cells.clear()
	flash_rocks.clear()
	spawn_cells.clear()
	gravity_moves.clear()
	refill_cells.clear()


func _set_orb(pos: Vector2i, orb_id: int) -> void:
	if pos.y < 0 or pos.y >= vis_orbs.size():
		return
	var row: Array = vis_orbs[pos.y]
	if pos.x < 0 or pos.x >= row.size():
		return
	row[pos.x] = orb_id
	vis_orbs[pos.y] = row


func _set_obs(pos: Vector2i, obs_id: int, hp: int) -> void:
	if pos.y < 0 or pos.y >= vis_obstacles.size():
		return
	var row_o: Array = vis_obstacles[pos.y]
	var row_h: Array = vis_hp[pos.y]
	if pos.x < 0 or pos.x >= row_o.size():
		return
	row_o[pos.x] = obs_id
	row_h[pos.x] = hp
	vis_obstacles[pos.y] = row_o
	vis_hp[pos.y] = row_h


static func _copy_grid(src: Array) -> Array:
	var out: Array = []
	for row_v in src:
		if typeof(row_v) != TYPE_ARRAY:
			continue
		var row: Array = []
		for cell in row_v:
			row.append(int(cell) if typeof(cell) == TYPE_INT else -1)
		out.append(row)
	return out
