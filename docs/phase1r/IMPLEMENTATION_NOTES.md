# Phase R-A / R-B / R-C / R-D / R-E0 — Implementation notes

## Roadmap alignment (post Phase 1-R)

| Phase | Scope |
| --- | --- |
| **R-A** | OrbType / PuzzleCell / PuzzleBoard / OrbGenerator / stable initial fill |
| **R-B** | DragRoute / 4-direction swap semantics only (no match resolve) |
| **R-C** | MatchResolver / orthogonal ≥3 / simultaneous clear set |
| **R-D** | GravityResolver / refill / CascadeResolver / finite safety guard |
| **R-E0** | Provisional Score / Timer / Session-state contracts (**docs only**; gate before R-E) |
| **R-E** | PuzzleSession / timer / mid-drag forced release / provisional Score (**requires R-E0**) |
| **R-F** | Minimal Puzzle UI / Android touch / playable Score Attack / 45·60·90 device comparison |
| **Gate 1** | After R-F Android playable COMPLETE |
| Post R-F | Legacy Block Placement deletion decision |
| Post Gate 1 | ROCK (then LOCK / SLIME / …) |

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
- Obstacles / ROCK segment gravity are **out of scope** (post Gate 1)

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
- Integer only; never negative; invalid / guard-exceeded cascades award **0**
- Do not call this “Combo”; use cascade step / depth
- Excluded: group count, route length, speed, color, specials, ROCK, Rescue, time bonus, stage, difficulty

### Timer

- Domain SoT unit: **integer milliseconds** (not float seconds)
- DEV default: **60000** ms; comparison set: **45000 / 60000 / 90000** ms
- `advance_time(elapsed_ms)`: `>0` applies; `0` no-op; `<0` reject/no-op
- Ticks in `IDLE` / `ROUTE_DRAG` only; paused in `RESOLVING` / `SESSION_OVER` / `ERROR` / `INVALID`
- Overshoot clamps to 0; expiry handled once
- Mid-drag expiry: forced release if swaps≥1 (no rollback); score on stable cascade; then `SESSION_OVER`

### Session states (R-E target)

`INVALID` / `IDLE` / `ROUTE_DRAG` / `RESOLVING` / `SESSION_OVER` / `ERROR`

### R-E0 code rule

**No** PuzzleSession / Score / Timer GDScript in R-E0. R-E must not start until this contract is COMPLETE.
