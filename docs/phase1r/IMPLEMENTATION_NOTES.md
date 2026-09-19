# Phase R-A / R-B / R-C / R-D / R-E0 / R-E — Implementation notes

## Roadmap alignment (post Phase 1-R)

| Phase | Scope |
| --- | --- |
| **R-A** | OrbType / PuzzleCell / PuzzleBoard / OrbGenerator / stable initial fill |
| **R-B** | DragRoute / 4-direction swap semantics only (no match resolve) |
| **R-C** | MatchResolver / orthogonal ≥3 / simultaneous clear set |
| **R-D** | GravityResolver / refill / CascadeResolver / finite safety guard |
| **R-E0** | Provisional Score / Timer / Session-state contracts (**docs only**; gate before R-E) |
| **R-E** | PuzzleSession / timer / mid-drag forced release / provisional Score |
| **R-F** | Minimal Puzzle UI / Android touch / playable Score Attack / Dual Timer — **MERGED** (#16) |
| **Gate 1** | **PASS WITH FINDINGS** (human device eval; not market proof) |
| **R-G** | Minimal ROCK Obstacle vertical slice — **COMPLETE** (#17) |
| **Gate 2-A** | Game modes / Obstacle progression / evaluation contract — **COMPLETE** ([`GATE2_GAME_DESIGN.md`](GATE2_GAME_DESIGN.md); PR #18) |
| **Gate 2-B1** | Paired-seed ROCK pressure DEV harness — **COMPLETE** (PR #19 `20faaca`) |
| **Gate 2-B2** | Live 20-trial evaluation ([`GATE2B_RESULTS.md`](GATE2B_RESULTS.md)) — **NOT STARTED** |
| Post R-F | Legacy Block Placement deletion decision |
| Post Gate 2 | LOCK / SLIME / Rescue (not before) |

## Paths

| Type | Path | Phase |
| --- | --- | --- |
| `OrbType` | `scripts/puzzle/orb_type.gd` | R-A |
| `PuzzleCell` | `scripts/puzzle/puzzle_cell.gd` | R-A |
| `PuzzleBoard` | `scripts/puzzle/puzzle_board.gd` | R-A |
| `OrbGenerator` | `scripts/puzzle/orb_generator.gd` | R-A |
| `DragRoute` | `scripts/puzzle/drag_route.gd` | R-B |
| `MatchResult` | `scripts/puzzle/match_result.gd` | R-C |
| `MatchResolver` | `scripts/puzzle/match_resolver.gd` | R-C |
| `GravityResolver` | `scripts/puzzle/gravity_resolver.gd` | R-D |
| `CascadeResult` | `scripts/puzzle/cascade_result.gd` | R-D |
| `CascadeResolver` | `scripts/puzzle/cascade_resolver.gd` | R-D |
| `PuzzleSession` | `scripts/puzzle/puzzle_session.gd` | R-E |
| `SessionMoveResult` | `scripts/puzzle/session_move_result.gd` | R-E |
| `BoardGeometry` | `scripts/puzzle/board_geometry.gd` | R-F |
| `GridInputMapper` | `scripts/puzzle/grid_input_mapper.gd` | R-F |
| `PuzzleGameView` | `scripts/puzzle_ui/puzzle_game_view.gd` | R-F |

Legacy `scripts/game/*` unchanged.

## Coordinates

- `x` left → right, `y` top → bottom, origin `(0,0)` top-left
- Domain APIs take `Vector2i` cells only (no pixels)

## Adjacency / swap (R-A)

- `PuzzleBoard.swap(a, b)` allows **orthogonal Manhattan distance 1** only
- Rejects: OOB, same cell, diagonal, distance > 1, either cell empty
- Failure is atomic (board unchanged)

## PuzzleCell

- `with_orb(valid_id)` → `PuzzleCell`
- `with_orb(invalid_id)` → `null` (never silent empty)
- `set_orb(invalid)` → false; existing orb unchanged

## Match detection

- **Not** on `PuzzleBoard` (MatchResolver = R-C)
- Stable-fill tests use test-local `_has_orthogonal_run(snapshot, min_len)`

## RNG

- Injected / owned `RandomNumberGenerator`
- `set_seed(int)` supported
- Picks use `randi_range(0, n - 1)` — **not** `randi() % n`
- No dependency on global `randi()`

## Initial fill order (RNG consumption order) — FIXED

Precondition: board is **valid and entirely empty**. If any orb is present → `fill_match_stable` returns `false`, board unchanged, **no RNG consumption**.

Row-major:

```
for y in 0 .. height-1:
  for x in 0 .. width-1:
    candidates = DEV types minus exclusions
    pick = rng among candidates   # one randi_range consumption
    board[x,y] = pick
```

Exclusions at cell `(x,y)`:

- If `x >= 2` and `board[x-1,y] == board[x-2,y]` (both orbs): exclude that type
- If `y >= 2` and `board[x,y-1] == board[x,y-2]` (both orbs): exclude that type

Fail-closed if candidates empty (no whole-board unbounded retry).
No cascade cleanup. No score.

DEV verification target: **6×6 / 5 OrbType** → no horizontal/vertical ≥3 after fill.

---

## Phase R-B — DragRoute

### Board binding

- `DragRoute.begin(board, start_cell)` stores a **private** `PuzzleBoard` reference
- `try_step(next_cell)` does **not** accept a board argument (prevents mid-route board switching)
- No public board getter
- Contract while a route is active: callers must not mutate the same board externally (R-E session will own this boundary)

### begin

- Requires valid board, in-bounds start, start cell has an orb
- Failure → `null`
- Success: `path=[start]`, `current=start`, `swap_count=0`, **board unchanged**

### StepResult

| Value | Meaning |
| --- | --- |
| `SWAPPED` | Orthogonal step; `PuzzleBoard.swap` succeeded; path/current/count committed |
| `NO_CHANGE_SAME_CELL` | `next == current` (jitter); board and route state unchanged |
| `REJECTED` | OOB / non-adjacent / swap failed / inactive; fully atomic |

### Path / revisit / jitter

- Path **includes revisits** (e.g. `[A,B,C,B]`)
- Revisit and immediate backtrack are legal; each new cell enter swaps
- Same-cell jitter does **not** append to path and does not swap
- “New cell enter” means transitioning to a cell **different from current**, not “never visited”

### Carried orb

- Selected orb identity is carried at the route head via successive `PuzzleBoard.swap` calls
- Example `A=a,B=b,C=c` then `A→B→C` ⇒ board `b,c,a`

### Atomicity

- Route state (`path` / `current` / `swap_count`) updates **only after** successful `PuzzleBoard.swap`
- Never commit one without the other

### Out of R-B scope

- `release` / `finish` / `cancel` / rollback
- MatchResolver / clear / gravity / refill / cascade
- PuzzleSession / timer / score / UI / touch

---

## Phase R-C — MatchResolver

### Ownership

- `MatchResolver` owns match geometry (SoT)
- `PuzzleBoard` does **not** detect matches
- Threshold: orthogonal contiguous same `OrbType` length **≥ 3**
- **No diagonal** matching
- Empty cells break runs (future obstacles without orbs also break naturally)

### detect(board) → MatchResult

- Read-only: never mutates the board
- null / invalid board → `MatchResult.invalid()` (`is_valid() == false`)
- Scans all rows then all columns; unions cells; dedupes intersections
- Long runs include **all** cells (e.g. 5-in-a-row → 5 cells, not 3)
- Line-end runs are flushed (no end-of-line leak)

### MatchResult

- `is_valid()` / `has_matches()` / `matched_cell_count()` / `matched_cells_snapshot()`
- Snapshot is defensive; order is **row-major** (`y` asc, then `x` asc)
- No score / combo fields

### clear_current_matches(board) → MatchResult

- Re-detects on the **current** board (no stale MatchResult input API)
- Clears the simultaneous union in one pass after detection completes
- Non-matched cells preserved
- No matches → board unchanged, valid empty result
- Invalid board → invalid result, no mutation
- Does **not** gravity / refill / cascade

### Out of R-C scope

- GravityResolver / refill / CascadeResolver
- PuzzleSession / timer / score / combo / specials
- Obstacles / UI / touch

---

## Phase R-D — Gravity / Refill / Cascade

### Gravity

- Coordinates: `y=0` top, `y=height-1` bottom
- Each column independent; orbs compact **downward**
- Empties gather at the **top**
- Relative vertical order of orbs in a column is **preserved**
- No orb duplication / loss / cross-column moves
- Null / invalid board → `apply` returns `false`, no mutation
- Obstacles / falling ROCK gravity: delivered in **R-G** (see Phase R-G)

### Refill order — FIXED

After gravity, empty cells are refilled with:

```
for x in 0 .. width-1:          # left → right
  for y in 0 .. height-1:       # top → bottom
    if board[x,y] empty:
      orb = generator.generate_orb()
      board[x,y] = orb
```

- Deterministic; same seed/state → same consumption order
- Refill is **not** match-stable (new matches are allowed and become cascade steps)
- No dedicated RefillResolver class (private helper inside `CascadeResolver`)

### Continuous RNG stream

- Future `PuzzleSession` pattern: one `OrbGenerator` instance → `fill_match_stable` → **same instance** for cascade refill
- Cascade must **not** reset `generator` seed
- Do **not** recreate a same-seed generator after initial fill for production play

### Cascade order

```
steps = 0
loop:
  match_result = MatchResolver.detect(board)
  if invalid → ERROR
  if no matches → STABLE SUCCESS
  if steps >= MAX_CASCADE_STEPS → GUARD_EXCEEDED
  clear_current_matches
  GravityResolver.apply
  refill empties (order above)
  steps += 1
```

### MAX_CASCADE_STEPS

- `const MAX_CASCADE_STEPS := 128`
- Safety guard against abnormal infinite loops — **not** a gameplay combo cap
- Up to **128 successful** resolve steps are allowed
- Guard fires only when matches still exist **after** those steps (off-by-one: the 128th step is processed)
- Optional `max_steps` argument on `resolve` is an internal test/seam defaulting to 128 (no production `force_infinite` flag)

### CascadeResult (neutral metrics)

- `is_valid()` / `is_stable()` / `is_guard_exceeded()` / `step_count()` / `total_cleared_cells()`
- `cleared_cell_count_per_step_snapshot()` — per-step unique cleared cell counts (e.g. `[6,3,8]`)
- **Score formula is undefined in R-D** (locked before R-E)
- Combo count / match group count are **not** fixed here

### Error semantics (fail-closed)

ERROR (not stable success):

- null / invalid board or generator
- detect / clear / gravity / refill failure
- cascade guard exceeded (`is_guard_exceeded() == true`, `is_valid() == false`)

Invalid inputs are rejected **before** the first detect (no mutation, no RNG).
Mid-cascade ERROR does **not** roll back prior steps; the board is not treated as safely continuable.

### Out of R-D scope

- PuzzleSession / Timer / Score / combo formula
- Drag release integration / UI / touch / Scene
- ROCK / LOCK / SLIME / Rescue / Animation
- Ads / Android export changes

---

## Phase R-E0 — Provisional Score / Timer Contract (docs only)

**Canonical spec:** [`SCORE_TIMER_CONTRACT.md`](SCORE_TIMER_CONTRACT.md)

### Score (provisional, Gate 1)

- Input: `CascadeResult.cleared_cell_count_per_step_snapshot()` only
- `step_index` is 1-based
- `base_score = cleared_cells * 100`
- `cascade_bonus = cleared_cells * 25 * (step_index - 1)`
- `move_score = sum(step_score)`
- Storage: signed **64-bit** int; `SCORE_MAX = 9,223,372,036,854,775,807`
- Never negative under normal scoring; invalid / guard-exceeded cascades award **0**
- Overflow on multiply/add past `SCORE_MAX`: **no wrap, no saturate**; do not add that move; keep prior session score; session → `ERROR` (input blocked)
- Do not call this “Combo”; use cascade step / depth
- Excluded: group count, route length, speed, color, specials, ROCK, Rescue, time bonus, stage, difficulty

### Timer

- Domain SoT unit: **integer milliseconds** (not float seconds)
- DEV default: **60000** ms; comparison set: **45000 / 60000 / 90000** ms
- `advance_time(elapsed_ms)`: `>0` applies; `0` no-op; `<0` reject/no-op
- Ticks in `IDLE` / `ROUTE_DRAG` only at the **domain** `advance_time` gate; paused in domain `RESOLVING` / `SESSION_OVER` / `ERROR` / `INVALID`
- **UI PRESENTING** (ResolutionPresenter busy) is **not** domain `RESOLVING`: after START, Session Timer keeps running during match/hit/gravity/refill/respawn/opening playback
- Move Timer remains `ROUTE_DRAG`-only (presentation never invents Move drain)
- Overshoot clamps to 0; expiry handled once
- Mid-drag expiry: forced release if swaps≥1 (no rollback); score on stable cascade; then `SESSION_OVER`
- Mid-presentation Session expiry → `SESSION_OVER`, finish current anim, block new input; no double resolve / score recompute

### Session states (R-E target)

`INVALID` / `IDLE` / `ROUTE_DRAG` / `RESOLVING` / `SESSION_OVER` / `ERROR`

### R-E0 code rule

**No** PuzzleSession / Score / Timer GDScript in R-E0. R-E must not start until this contract is COMPLETE.

---

## Phase R-E — PuzzleSession

### Ownership

- `PuzzleSession` privately owns `PuzzleBoard`, `OrbGenerator`, active `DragRoute`, `remaining_ms`, `session_score`, `state`
- No public mutable board/generator getters
- Read API: `state`, `score`, `remaining_ms`, `orb_at`, `board_snapshot`, active-drag accessors

### create_score_attack(width, height, seed, duration_ms)

- Empty board + **one** `OrbGenerator` → `fill_match_stable` → same instance kept for cascade refill
- Opening board must be match-stable; else `INVALID`
- Success → `IDLE`, score 0, `remaining_ms = duration_ms`
- Optional `max_cascade_steps` seam defaults to 128 (safety only)

### States

`INVALID` / `IDLE` / `ROUTE_DRAG` / `RESOLVING` / `SESSION_OVER` / `ERROR`

### Drag

- `begin_drag` only in `IDLE` with `remaining_ms > 0`
- `step_drag` delegates to `DragRoute.try_step`; rejected outside `ROUTE_DRAG` or after timer 0
- `release_drag`: 0 swaps → no cascade; ≥1 swap → resolve

### Score

- `PuzzleSession.compute_move_score` / `checked_mul` / `checked_add` — single formula (R-E0)
- Commit once after full move_score is computed; overflow → `ERROR`, prior score kept

### Timer

- `advance_time(elapsed_ms)` per R-E0; ticks only `IDLE`/`ROUTE_DRAG` (domain gate)
- Mid-drag expiry forced release; domain `RESOLVING` is sync and does not sticky-pause UI presentation time
- **R-F Dual Timer:** Session Timer + per-drag Move Timer (`MOVE_DURATION_MS = 2000` DEV)
  - `IDLE`: Session ticks; Move inactive (`move_remaining_ms() == 0`)
  - `ROUTE_DRAG`: both deduct the same `elapsed_ms` (including same-cell hold)
  - Domain `RESOLVING` / `SESSION_OVER` / `ERROR` / `INVALID`: both paused at `advance_time`
  - **UI presentation** (after resolve returns to `IDLE`): Session Timer continues; Move inactive; input blocked while busy
  - Move expiry (`swap_count >= 1`): forced release → resolve → Score → `IDLE` if Session remains
  - Move expiry (`swap_count == 0`): cancel-equivalent → no cascade → `IDLE` if Session remains
  - Session expiry during drag wins over Move (including simultaneous 0); one forced release; final `SESSION_OVER`
  - Session expiry during presentation: `SESSION_OVER`, anim may finish, no new moves
  - Next successful `begin_drag` resets Move to 2000 ms
  - SoT: `PuzzleSession` (`remaining_ms`, `move_remaining_ms`, expiry precedence, forced release)

### Out of R-E scope

- UI / Scene / Touch / Animation
- 45/60/90 final pick / ROCK / Save / Ads / legacy delete

---

## Phase R-F — Minimal Android Playable

### SoT

- `PuzzleSession` remains the only game-state owner
- UI renders `board_snapshot()`; never reimplements match/gravity/score
- Move Timer is domain SoT — UI does **not** measure 3s independently

### Input

- `BoardGeometry`: pixel ↔ cell
- `GridInputMapper`: pointer ownership (TOUCH vs MOUSE) + orthogonal interpolation
- Fast jumps expand to adjacent 4-dir steps (tie: X first when `|dx| >= |dy|`)
- Outside board during drag: no steps, keep route; outside release still `release_drag()` once
- Domain forced release (Move/Session expiry) clears pointer ownership in the view adapter

### Timer adapter

- Accumulate `delta*1000` fractional remainder; pass every whole millisecond via `advance_time(whole_ms)` while foreground-active
- **No per-frame gameplay cap** — active gameplay elapsed is never discarded
- Pause when app/window unfocused (no catch-up on resume)
- Startup / focus-return: skip a few frames, reset remainder, and drop at most one abnormal transition spike (>1s)
- Domain `RESOLVING` is synchronous inside `advance_time` / release — not a sticky UI pause
- **UI PRESENTING:** Session Timer **keeps running** after START (Score Attack tempo); Move Timer inactive; input blocked
- Presenter advances before Session clock in `_process`; presentation busy must not early-return past the Session clock

### DEV HUD

- Pre-session **READY** is UI-only (`_session == null`); **no** `PuzzleSession.State.READY`
- Launch shows START (default duration **60000** ms selected); duration buttons **select only**
- START / Restart create `PuzzleSession`; Session Timer starts only after that
- Pre-START: no board, no Session/Move countdown, board input disabled (UMP/ads cannot burn Score Attack time)
- `Session: X.Ys` from `remaining_ms()` after start
- `Move: X.Ys` only during `ROUTE_DRAG`; otherwise `Move: ---`
- Optional DEV note when Move/Session expiry forced a release

### DEV play

- Seed **42**, 6×6, 5 types, duration buttons 45000/60000/90000 ms
- Move budget DEV **2000** ms per drag (Gate 1 first evaluation: Session 60000 + Move 2000)
- Immediate post-resolve redraw (no cascade animation)

### Status

- **COMPLETE** — PR #16 merge-commit to `main` (`b9ed25c`); feature HEAD `f2d30f0`
- Gate 1: **PASS WITH FINDINGS** (Move 2.0s / Session 60s baseline accepted as Gate 1 DEV, not production final)
- Findings: replayability UNPROVEN; score agency WEAK; obstacle hypothesis UNVERIFIED

### Out of R-F scope

- ROCK / Save / Best Score / production art / complex animation / audio
- Production-final Move duration pick (2.0s remains Gate 1 DEV baseline)

---

## Phase R-G — Minimal ROCK Obstacle Vertical Slice

### Purpose

Hypothesis check for Gate 2: does a **falling** impassable ROCK (top→down gravity token)
improve route thinking / replayability without becoming pure annoyance?
**Not** a feature-complete obstacle framework. Not a fixed terrain wall.

### Domain

- `ObstacleType`: `NONE` / `ROCK` only (`scripts/puzzle/obstacle_type.gd`)
  — durability is **not** a separate ObstacleType
- `PuzzleCell`: optional orb + optional obstacle + `_obstacle_hp`; **ROCK ⇒ no orb**
- Initial ROCK: **HP = 2** (Gate 2 DEV; not production final)
- `PuzzleBoard`: `set_rock` / `place_rock_with_hp` / `move_occupant` / `clear_obstacle` /
  `rock_hp_at` / `damage_rock` / snapshots / `rock_count`
  — existing ROCK → `set_rock` fails (no silent HP heal)
  — gravity moves use `place_rock_with_hp` / `move_occupant` (HP preserved; never `set_rock`)
- Damage unit: **max 1 hit per ROCK per cascade step**
  (multi-adjacent matched cells in the same step still deal 1 damage)
- HP is **per-cell independent** (Test A: only adjacent ROCK takes damage)
- Cross-cascade-step damage in the same move is legal (step1 HP2→1, step2 HP1→0)
- Cascade order: detect → unique adjacent ROCK hits → destroy only HP=0 →
  clear matched orbs → **mixed occupant gravity** → refill skips living ROCK
- `GravityResolver`: per-column compact of Orb **and** ROCK together; top→bottom
  relative order preserved; no overtake; downward-only; same column only
- `GravityMoveTrace.Kind`: `ORB` | `ROCK` (orb_id or rock_hp); no upward / horizontal moves
- Neutral `CascadeStepTrace` (matched / rock_hits / gravity_moves / refills) for UI playback
- HP1 / HP2: both impassable, both gravity-affected falling tokens, both refill-skipped
- Score formula unchanged (no ROCK hit / break bonus)

### ROCK respawn (Gate 2 DEV)

- `TARGET_ROCK_COUNT = 3`
- Destroying rocks queues `_pending_rock_respawns`; **no spawn on the destroy move**
- Next valid move (`swap_count >= 1`, stable resolve, not SESSION_OVER/ERROR): spawn **at most 1**
- Obstacle RNG: `obstacle_seed = session_seed XOR 0x524F434B` (`OBSTACLE_RNG_SEED_XOR`)
  — independent of `OrbGenerator` stream
- Candidate: **top row only** (`y == 0`), no obstacle (orb may be present);
  replace with ROCK HP=2; mid-board spawn forbidden
- No eligible top cell → keep pending, no ERROR; retry next valid move
- **Gameplay respawn stays top-row drop** (distinct from Initial ROCK board-wide placement)

### Initial ROCK (standard ROCK mode)

- Count = 3, HP = 2; sample **3 unique cells from the full board** (`width × height`)
  via Obstacle RNG (`pick_unique_cells`); placement order sorted **y asc, then x asc**
- Same column may hold multiple ROCKs; same cell is forbidden; no fairness region constraints
- Flow: OrbGenerator match-stable fill → Obstacle RNG pick → replace Orbs with ROCK HP2 →
  MatchResolver re-check (fail-closed if invalid / matches)
- Does **not** consume Orb RNG; `obstacle_seed = session_seed XOR 0x524F434B` continues into respawn
- Same explicit session seed → same Orb board + same initial ROCK positions + same later Obstacle RNG

### Presentation

- `ResolutionPresenter` plays domain traces only
  (match → rock hit → clear → gravity Orb+ROCK downward → refill from above → respawn drop)
- Fall motion: smoothstep `_ease_fall` + distance-based duration
  (`FALL_BASE_MS`/`FALL_PER_CELL_MS`, clamped `FALL_MIN_MS`..`FALL_MAX_MS`)
- Gravity / refill / respawn: **continuous moving-token** layer (trace SoT → pixel lerp);
  static layer suppresses sources/targets until phase-end commit (no teleport / double-draw)
- Gravity / refill / respawn visuals are **top → down only** (no horizontal / upward / overshoot)
- DEV A/B: Obstacle **OFF (DEV/QA/Gate baseline)** | **ROCK** (product-standard candidate, default)
- ROCK: standard gameplay candidate for Gate 2 evaluation
- Obstacle OFF: control / baseline only — not the intended product-normal mode
- Normal START / Restart: **new Session seed** each round (`_session_seed_rng`); PuzzleSession stays deterministic per seed
- Explicit `start_session_with_seed(seed)` / `create_score_attack(..., seed)` for tests / Gate / reproduction
- **START board opening (ROCK ON and OFF):** presentation-only column settle of final Orb/ROCK
  occupants from above (`BOARD_OPENING`, ~450ms parallel drop). Same-column relative order preserved —
  ROCK must not pierce / overtake Orbs (and vice versa). Domain already holds the final board.
- **Pre-game:** OPENING + 3·2·1 countdown (`PRESTART_COUNTDOWN_MS=3000`) — Session Timer **frozen**; board input blocked
- **GO!** (`GO_OVERLAY_MS=400`, non-blocking): Session Timer **starts**; input enabled; mapper cleared (no touch carry-over)
- After RUNNING: `presentation_busy` blocks **input** only; Session Timer still runs (not a gameplay SoT)
- Render target: **60fps** (`application/run/max_fps=60` + `Engine.max_fps`); animations stay delta_ms-based
- DEV-only FPS overlay (`SHOW_DEV_FPS`, ~500ms sample) — not production UI
- Countdown overlay Label is created once and text-updated (not rebuilt each frame)
- DEV seed HUD shows `RANDOM` on READY and the live Session seed after START

### DEV A/B

- READY: Obstacle **OFF (DEV)** | **ROCK** (default ROCK = product-standard candidate)
- ROCK initial layout (Gate 2 DEV): **3 unique cells from the full 6×6 board** via Obstacle RNG
  (`pick_unique_cells`, sorted y then x for placement); all HP=2
  — same session seed → same positions; normal Restart uses a **new** Session seed
  — Initial = board-wide random; gameplay respawn remains top-row drop
- Explicit seed 42 remains available for tests / Gate comparison
- Session 60s / Move 2.0s / 6×6 / 5 OrbTypes
- HUD: `ROCK: N` remaining count; cells draw gray + `"R2"` / `"R1"`
- DEV seed line: live Session seed (not fixed 42 on normal play)
- DEV FPS: corner `FPS` / `Frame ms` (not production)

### Product direction (docs)

- Intended core: short Score Attack + Move Timer + **dynamic Obstacles** that shape route decisions
- Obstacle OFF is a measurement baseline, not the finished product mode
- If ROCK underperforms Gate 2, prefer Obstacle design iteration over deleting Obstacles
- Do **not** start LOCK / SLIME / Rescue before Gate 2

### Future — SLIME (docs only; not implemented)

Hypothesis only — do **not** add `ObstacleType.SLIME` / GDScript / tests in R-G:

- Does **not** steal Move Timer budget
- Not a hard impassable wall like ROCK
- Route traversal candidate: may convert the carried orb’s color (exact rule undecided)
- Intended as a route-decision tool, not pure annoyance
- Deferred until after R-G / Gate 2

### Status

- **COMPLETE** — PR #17 merge-commit to `main` (`635085f`); feature HEAD `67bd68c`
- Android PASS: board-wide Initial ROCK, Opening settle, Countdown, Continuous Fall, HP2,
  Gravity/Refill/Respawn, 58～60fps, crashなし
- Tests: **248 PASS**
- Prerelease: `phase-rg-boardwide-rock-test-67bd68c`
- Gate 2 product/eval contract: **Gate 2-A COMPLETE**; **Gate 2-B1 COMPLETE** (PR #19); **Gate 2-B2 NOT STARTED**
  — results template [`GATE2B_RESULTS.md`](GATE2B_RESULTS.md); eval APK `gate2b-rock-pressure-test-f327ee3`
- Note for Gate 2 / Score redesign: long cascade presentation consumes Score Attack time by design (after GO)
- Do **not** start LOCK / SLIME / Rescue before Gate 2 ends
- ROCK = 製品標準候補; Obstacle OFF = DEV / QA / Gate baseline

### Out of R-G scope

- LOCK / SLIME / Rescue / Stage Mode / Score redesign / production art
- Large obstacle event framework
- Production-final ROCK durability
