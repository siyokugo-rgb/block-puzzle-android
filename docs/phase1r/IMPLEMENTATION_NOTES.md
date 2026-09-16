# Phase R-A — Implementation notes

Branch: `cursor/phase-ra-puzzle-board-b8da`  
Scope: `OrbType` / `PuzzleCell` / `PuzzleBoard` / `OrbGenerator` / match-stable initial fill only.

## Paths

| Type | Path |
| --- | --- |
| `OrbType` | `scripts/puzzle/orb_type.gd` |
| `PuzzleCell` | `scripts/puzzle/puzzle_cell.gd` |
| `PuzzleBoard` | `scripts/puzzle/puzzle_board.gd` |
| `OrbGenerator` | `scripts/puzzle/orb_generator.gd` |

Legacy `scripts/game/*` unchanged.

## Coordinates

- `x` left → right, `y` top → bottom, origin `(0,0)` top-left
- Domain APIs take `Vector2i` cells only (no pixels)

## Adjacency / swap (R-A)

- `PuzzleBoard.swap(a, b)` allows **orthogonal Manhattan distance 1** only
- Rejects: OOB, same cell, diagonal, distance > 1, either cell empty
- Failure is atomic (board unchanged)

## RNG

- Injected / owned `RandomNumberGenerator`
- `set_seed(int)` supported
- Picks use `randi_range(0, n - 1)` — **not** `randi() % n`
- No dependency on global `randi()`

## Initial fill order (RNG consumption order) — FIXED

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

## Out of scope (not in R-A)

DragRoute, PuzzleSession, Match/Gravity/Cascade resolvers, Timer, Score, Obstacles, UI, Ads.
