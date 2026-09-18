class_name ResolutionPresenter
extends RefCounted

## Presentation-only playback of SessionMoveResult traces.
## Does not own gameplay state; never reimplements match/gravity/refill.
## Fall motion uses smoothstep easing + distance-based duration (presentation only).

enum Phase {
	IDLE,
	MATCH,
	ROCK_HIT,
	GRAVITY,
	REFILL,
	RESPAWN_WARN,
	RESPAWN_SHOW,
	BOARD_OPENING,
	DONE,
}

const MATCH_MS := 120.0
const ROCK_HIT_MS := 130.0

## Distance-based fall timing (DEV). Shared by gravity / refill.
const FALL_BASE_MS := 100.0
const FALL_PER_CELL_MS := 30.0
const FALL_MIN_MS := 130.0
const FALL_MAX_MS := 260.0

## Legacy aliases (= max clamp) for call sites that only need an upper bound.
const GRAVITY_MS := FALL_MAX_MS
const REFILL_MS := FALL_MAX_MS

const RESPAWN_WARN_MS := 120.0
const RESPAWN_SHOW_MS := 180.0
## Presentation-only travel for respawn drop (cells above top row).
const RESPAWN_DROP_CELLS := 1.5
## Pre-game board settle: all final tokens drop from this many cells above their target.
const OPENING_DROP_CELLS := 6
## Parallel column settle duration (DEV; ~300–600ms band).
const OPENING_MS := 450.0

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
var gravity_progress: float = 0.0 # 0..1 linear elapsed ratio
var gravity_moves: Array = []
var gravity_duration_ms: float = FALL_MIN_MS
var refill_progress: float = 0.0 # 0..1 linear elapsed ratio
var refill_cells: Array = []
var refill_duration_ms: float = FALL_MIN_MS
var spawn_cells: Array[Vector2i] = []
var flash_rocks: Array[Vector2i] = []


## Smoothstep fall easing. Deterministic, no overshoot. Presentation only.
static func _ease_fall(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Presentation duration for a fall of `cells` board steps (clamped).
static func fall_duration_ms(cells: int) -> float:
	var n := maxi(cells, 1)
	return clampf(FALL_BASE_MS + FALL_PER_CELL_MS * float(n), FALL_MIN_MS, FALL_MAX_MS)


func is_busy() -> bool:
	return busy


## Eased draw progress for the active gravity phase (0..1).
func gravity_eased_progress() -> float:
	return _ease_fall(gravity_progress)


## Eased draw progress for the active refill phase (0..1).
func refill_eased_progress() -> float:
	return _ease_fall(refill_progress)


## Eased draw progress for respawn drop (0..1). Warn stays parked above.
func spawn_eased_progress() -> float:
	if phase == Phase.RESPAWN_WARN:
		return 0.0
	if phase != Phase.RESPAWN_SHOW:
		return 1.0
	return _ease_fall(clampf(phase_elapsed_ms / RESPAWN_SHOW_MS, 0.0, 1.0))


func begin(move: SessionMoveResult) -> void:
	busy = false
	phase = Phase.IDLE
	gravity_duration_ms = FALL_MIN_MS
	refill_duration_ms = FALL_MIN_MS
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


## Pre-game: settle final Orb/ROCK occupants from above without piercing (order preserved).
## Domain already holds the final board; vis starts empty and commits at phase end.
func begin_board_opening(final_orbs: Array, final_obstacles: Array, final_hp: Array) -> void:
	busy = false
	phase = Phase.IDLE
	steps.clear()
	rock_spawns.clear()
	highlight_cells.clear()
	rock_hit_cells.clear()
	flash_rocks.clear()
	spawn_cells.clear()
	refill_cells.clear()
	gravity_moves.clear()
	vis_orbs = _copy_grid(final_orbs)
	vis_obstacles = _copy_grid(final_obstacles)
	vis_hp = _copy_grid(final_hp)
	if vis_orbs.is_empty():
		return
	var height := vis_orbs.size()
	var width := 0
	if height > 0 and typeof(vis_orbs[0]) == TYPE_ARRAY:
		width = (vis_orbs[0] as Array).size()
	if width <= 0:
		return
	# Empty static layer; tokens live only on the moving layer until landing.
	for y in range(height):
		var row_o: Array = vis_orbs[y]
		var row_b: Array = vis_obstacles[y]
		var row_h: Array = vis_hp[y]
		for x in range(width):
			var to := Vector2i(x, y)
			var from := Vector2i(x, y - OPENING_DROP_CELLS)
			if ObstacleType.is_rock(int(row_b[x])):
				gravity_moves.append(GravityMoveTrace.create_rock(from, to, int(row_h[x])))
			elif int(row_o[x]) >= 0:
				gravity_moves.append(GravityMoveTrace.create_orb(from, to, int(row_o[x])))
			row_o[x] = -1
			row_b[x] = ObstacleType.Id.NONE
			row_h[x] = 0
		vis_orbs[y] = row_o
		vis_obstacles[y] = row_b
		vis_hp[y] = row_h
	if gravity_moves.is_empty():
		return
	phase = Phase.BOARD_OPENING
	phase_elapsed_ms = 0.0
	gravity_progress = 0.0
	gravity_duration_ms = OPENING_MS
	busy = true


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
			gravity_progress = clampf(phase_elapsed_ms / gravity_duration_ms, 0.0, 1.0)
			if phase_elapsed_ms >= gravity_duration_ms:
				gravity_progress = 1.0
				_commit_gravity_to_vis()
				_begin_refill()
		Phase.BOARD_OPENING:
			gravity_progress = clampf(phase_elapsed_ms / gravity_duration_ms, 0.0, 1.0)
			if phase_elapsed_ms >= gravity_duration_ms:
				gravity_progress = 1.0
				_commit_gravity_to_vis()
				_finish()
		Phase.REFILL:
			refill_progress = clampf(phase_elapsed_ms / refill_duration_ms, 0.0, 1.0)
			if phase_elapsed_ms >= refill_duration_ms:
				refill_progress = 1.0
				_commit_refill_to_vis()
				step_index += 1
				if step_index < steps.size():
					_begin_step_match()
				else:
					_begin_respawn_or_done()
		Phase.RESPAWN_WARN:
			if phase_elapsed_ms >= RESPAWN_WARN_MS:
				# Landing commit deferred until RESPAWN_SHOW ends (moving-token layer).
				phase = Phase.RESPAWN_SHOW
				phase_elapsed_ms = 0.0
		Phase.RESPAWN_SHOW:
			if phase_elapsed_ms >= RESPAWN_SHOW_MS:
				_apply_spawns_to_vis()
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


## True while GRAVITY / BOARD_OPENING and `pos` is a moving-token source.
func is_gravity_source(pos: Vector2i) -> bool:
	if phase != Phase.GRAVITY and phase != Phase.BOARD_OPENING:
		return false
	for item in gravity_moves:
		var mv: GravityMoveTrace = item
		if mv.from_cell() == pos:
			return true
	return false


## True while GRAVITY / BOARD_OPENING and `pos` is a pending landing cell.
func is_gravity_destination(pos: Vector2i) -> bool:
	if phase != Phase.GRAVITY and phase != Phase.BOARD_OPENING:
		return false
	for item in gravity_moves:
		var mv: GravityMoveTrace = item
		if mv.to_cell() == pos:
			return true
	return false


## True while REFILL and `pos` is a pending landing target.
func is_refill_target(pos: Vector2i) -> bool:
	if phase != Phase.REFILL:
		return false
	for item in refill_cells:
		var rf: RefillTrace = item
		if rf.pos() == pos:
			return true
	return false


## True while RESPAWN_WARN/SHOW and `pos` is a pending spawn target.
func is_spawn_target(pos: Vector2i) -> bool:
	if phase != Phase.RESPAWN_WARN and phase != Phase.RESPAWN_SHOW:
		return false
	return pos in spawn_cells


## Legacy cell-offset helper (tests / diagnostics). Prefer geometry lerp in draw.
func gravity_draw_offset(pos: Vector2i, cell_size: float) -> Vector2:
	if (phase != Phase.GRAVITY and phase != Phase.BOARD_OPENING) or gravity_moves.is_empty():
		return Vector2.ZERO
	var eased := gravity_eased_progress()
	for item in gravity_moves:
		var mv: GravityMoveTrace = item
		if mv.from_cell() == pos:
			var delta := Vector2(mv.to_cell() - mv.from_cell()) * cell_size * eased
			return delta
	return Vector2.ZERO


## Moving tokens are always fully opaque (no fade-out / teleport).
func refill_alpha(_pos: Vector2i) -> float:
	return 1.0


## Presentation-only: drop from above board into target cell (0=above, 1=settled).
func refill_draw_offset(pos: Vector2i, cell_size: float) -> Vector2:
	if phase != Phase.REFILL:
		return Vector2.ZERO
	var eased := refill_eased_progress()
	for item in refill_cells:
		var rf: RefillTrace = item
		if rf.pos() == pos:
			var travel := -cell_size * (1.0 + float(pos.y)) * (1.0 - eased)
			return Vector2(0.0, travel)
	return Vector2.ZERO


func spawn_draw_offset(pos: Vector2i, cell_size: float) -> Vector2:
	if phase != Phase.RESPAWN_SHOW and phase != Phase.RESPAWN_WARN:
		return Vector2.ZERO
	if pos not in spawn_cells:
		return Vector2.ZERO
	var eased := spawn_eased_progress()
	return Vector2(0.0, -cell_size * RESPAWN_DROP_CELLS * (1.0 - eased))


## Pixel center of a gravity moving token (presentation SoT = GravityMoveTrace).
func gravity_token_center(mv: GravityMoveTrace, geometry: BoardGeometry) -> Vector2:
	var from_c := geometry.cell_rect(mv.from_cell()).get_center()
	var to_c := geometry.cell_rect(mv.to_cell()).get_center()
	return from_c.lerp(to_c, gravity_eased_progress())


## Pixel center of a refill moving token (above board → target).
func refill_token_center(rf: RefillTrace, geometry: BoardGeometry) -> Vector2:
	var target := geometry.cell_rect(rf.pos()).get_center()
	var start := target + Vector2(0.0, -geometry.cell_size() * (1.0 + float(rf.pos().y)))
	return start.lerp(target, refill_eased_progress())


## Pixel center of a respawn / opening ROCK moving token.
func spawn_token_center(pos: Vector2i, geometry: BoardGeometry) -> Vector2:
	var target := geometry.cell_rect(pos).get_center()
	var start := target + Vector2(0.0, -geometry.cell_size() * RESPAWN_DROP_CELLS)
	return start.lerp(target, spawn_eased_progress())


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
	gravity_duration_ms = fall_duration_ms(_max_gravity_cells())
	# Move tokens onto the transient layer: suppress static source cells immediately.
	# Destinations stay empty until phase-end commit (no double-draw / teleport).
	for item in gravity_moves:
		var mv: GravityMoveTrace = item
		if mv.is_rock():
			_set_obs(mv.from_cell(), ObstacleType.Id.NONE, 0)
		else:
			_set_orb(mv.from_cell(), -1)


func _max_gravity_cells() -> int:
	var max_d := 0
	for item in gravity_moves:
		var mv: GravityMoveTrace = item
		var dy := mv.to_cell().y - mv.from_cell().y
		if dy > max_d:
			max_d = dy
	return max_d


func _commit_gravity_to_vis() -> void:
	# Sources already cleared at phase begin; place destinations only.
	for item in gravity_moves:
		var mv: GravityMoveTrace = item
		if mv.is_rock():
			_set_obs(mv.to_cell(), ObstacleType.Id.ROCK, mv.rock_hp())
		else:
			_set_orb(mv.to_cell(), mv.orb_id())
	gravity_progress = 1.0


func _begin_refill() -> void:
	phase = Phase.REFILL
	phase_elapsed_ms = 0.0
	refill_progress = 0.0
	refill_duration_ms = fall_duration_ms(_max_refill_cells())
	# Targets stay empty until landing commit — moving tokens draw above→target.


func _max_refill_cells() -> int:
	var max_d := 0
	for item in refill_cells:
		var rf: RefillTrace = item
		# Travel from one cell above the board into target.y.
		var d := rf.pos().y + 1
		if d > max_d:
			max_d = d
	return max_d


func _commit_refill_to_vis() -> void:
	for item in refill_cells:
		var rf: RefillTrace = item
		_set_orb(rf.pos(), rf.orb_id())
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
