# Phase 1-R — Route-Drag Match Puzzle Redesign

**Status:** COMPLETE (docs / contracts only)  
**Branch:** `cursor/phase1r-route-match-redesign-b8da`  
**Base:** `main` @ `a5c1a339dc07f4296761f3a10b408c3b881ec6d3`  
**Scope of this phase:** documentation and boundary freeze only. **No new puzzle domain implementation in 1-R.**  
**Do not start Phase R-A until this PR is accepted and merged (or explicitly greenlit).**

---

## 1. Purpose

Replace the superseded **Block Placement** vertical slice (Phase 1-A…1-D) with a **Route-Drag Match Puzzle** product direction.

Phase 1-R fixes:

- Core loop vocabulary
- Domain responsibilities
- Drag / match / gravity / refill / cascade contracts
- Initial match-stable board contract
- Timer / Score Attack first mode (including mid-drag expiry)
- Obstacle roadmap attachment points (ROCK first; **not** via `OrbType`)
- Legacy migration order
- Gate 1 kill criteria

Implementation phases (R-A onward) are **out of scope** here.

---

## 2. Boundary with legacy Block Placement

### 2.1 Superseded product (do not merge)

| Artifact | Disposition |
| --- | --- |
| PR [#8](https://github.com/siyokugo-rgb/block-puzzle-android/pull/8) | **SUPERSEDED / REDESIGN** — closed unmerged (product change, not engineering failure) |
| Branch `cursor/phase1d-playable-slice-b8da` @ `8c67caa…` | Kept as evidence |
| Prerelease `phase1d-test-8c67caa` | Kept as evidence |

### 2.2 Legacy domain (SUPERSEDED — keep until R-F playable COMPLETE)

| Legacy type | Path (today) |
| --- | --- |
| `BoardState` | `scripts/game/board_state.gd` |
| `PieceShape` | `scripts/game/piece_shape.gd` |
| `PieceCatalog` | `scripts/game/piece_catalog.gd` |
| `PieceGenerator` | `scripts/game/piece_generator.gd` |
| `PieceTray` | `scripts/game/piece_tray.gd` |
| `PlacementSearch` | `scripts/game/placement_search.gd` |
| `GameSession` | `scripts/game/game_session.gd` |
| `MoveResult` | `scripts/game/move_result.gd` |
| Phase 1-D UI | `scripts/game_ui/*`, `scenes/game/game.tscn` (on PR #8 branch only; **not on main**) |

**Phase 1-R rule:** do **not** delete these types. New puzzle domain is implemented **in parallel**. Legacy deletion is decided only after **R-F Android playable Score Attack = COMPLETE**.

### 2.3 Untouchable baseline (Phase 0)

**Change-prohibited in Phase 1-R and early R-\* unless a separate Phase 0 regression ticket says otherwise:**

- AdMob plugin / native UMP patch
- `AdsConsentService` / `AdsConfig` / ConsentGate boot policy
- Android Gradle overlay / export_presets / minSdk·targetSdk·ABI policy
- GUT harness itself

`main` scene may later host a new PuzzleView **as a child** the same way 1-D proposed — without rewriting Ads/UMP.

---

## 3. New core loop

```
IDLE (player may drag)
  → pointer down on orb cell
  → ROUTE_DRAG (orthogonal adjacent steps; swap on newly entered cells)
  → pointer release  OR  timer hits 0 mid-drag (forced release if swaps≥1)
  → RESOLVING (input locked; timer paused)
       cascade loop with finite safety guard:
         detect simultaneous matches (≥3 orthogonal runs)
         clear matched orbs (+ future Obstacle damage hooks)
         gravity per column
         refill from top via seeded generator
       end when stable OR fail-closed on guard breach
  → if timer already expired → SESSION_OVER
  → else IDLE
```

**Player verb:** draw a route by dragging through orthogonally adjacent orbs; each **new cell enter** **swaps** with that neighbor.

**Resolve trigger:** player **release**, or **forced release** when the timer expires during `ROUTE_DRAG` after ≥1 swap. Mid-drag never starts resolve except via that forced-release path.

---

## 4. Fixed development / product decisions

These are **locked for Phase 1-R contracts**. Values marked DEV are defaults for first playable, **not** final production freezes.

| Topic | Decision |
| --- | --- |
| DEV board size | **6×6** (not final production size) |
| DEV orb types | **5** distinct `OrbType`s (not final catalog) |
| Initial board | **Match-stable** (see §8) — no opening cascade; no opening score |
| Drag | Route drag |
| First adjacency | **4-direction** (up / down / left / right) only |
| Route revisit | **Allowed** (including immediate backtrack); swap only on **new cell enter** |
| Route effect | Swap when entering a new adjacent cell |
| Resolve start | On **release** (or forced release on timer expiry mid-drag with swaps) |
| Match shape | Orthogonal runs of **≥3** same type (rows and columns) |
| Diagonal match | **None** |
| Clear | All current matches clear **simultaneously** |
| Gravity | **Per column** (cells fall down within column) |
| Refill | New orbs enter from the **top** of each column |
| Cascade | Repeat until **no matches**, with **finite safety guard** (see §10.5) |
| RNG | Seedable; same seed ⇒ reproducible sequences (see §11) |
| Input during resolve | **Forbidden** while resolver / cascade running |
| Session timer | Configurable duration |
| Timer during resolve | **Paused** for resolver / cascade |
| Timer mid-drag expiry | Force-release path — **no route rollback** (see §12) |
| First playable mode | **Score Attack** |
| DEV timer default | **60s** — compare **45 / 60 / 90** on device later; **not** a final fixed value |
| Score formula | Unresolved in 1-R; **provisional formula mandatory before R-E implementation starts** |
| First obstacle | **ROCK** as `ObstacleType` (not an `OrbType`) — only after **Gate 1** |
| LOCK | Deferred |
| SLIME | Deferred further |
| Rescue Gauge | Deferred |
| Initial rescue | If needed: **auto Shuffle only** (no gauge) |
| Stage Mode | After Score Attack is complete |
| Explicitly out | RPG / gacha / stamina / online ranking |

---

## 5. Invariants

1. **PuzzleSession is Source of Truth** for board occupancy, orb identities, optional obstacles, phase (`IDLE` / `ROUTE_DRAG` / `RESOLVING` / `SESSION_OVER` / error), score (when added), and timer remaining.
2. **UI never owns** match detection, gravity, refill, cascade, or session-over rules.
3. **Pixels never enter domain APIs.** Domain uses board cell coordinates `Vector2i` (x right, y down, origin top-left) consistent with Phase 1-A convention.
4. **Drag mutates only via explicit swap steps** on **new cell enter**; pointer jitter inside the same cell must not re-swap.
5. **Resolve is atomic from the player's perspective:** no input until cascade settles (or fail-closed error).
6. **Simultaneous clear:** within one detect pass, every matched cell is cleared once (union of row/column runs).
7. **No diagonal matching** in any detect pass.
8. **Gravity is column-local:** orb in column `x` never moves to another column during gravity.
9. **Refill only fills empty cells after gravity**, empties at top after compact-down.
10. **Cascade** stops when a detect pass finds zero matches **or** the safety guard trips (fail-closed — not “stable success”).
11. **Timer does not tick** while phase is `RESOLVING` (and any future pause states).
12. **Initial board is match-stable** for DEV 6×6 / 5 types: no horizontal/vertical ≥3 at fill complete; **no** initial cascade; **no** initial score from generation.
13. **`OrbType` is normal orb identity only** — never ROCK/LOCK/SLIME.
14. **Obstacles (when added)** live beside orbs on `PuzzleCell`, not inside `OrbType`.
15. **Legacy Block Placement domain remains compilable** until explicit deletion phase.
16. **Phase 0 ads/consent path remains bootable** on production main.

---

## 6. Responsibility table (new domain candidates)

| Type | Responsibility | Must not do |
| --- | --- | --- |
| `OrbType` | Identity / equality of **normal orb** kinds only (DEV: 5) | Obstacles; ROCK/meta flags; rendering; RNG |
| `ObstacleType` | Future enum/identity: **ROCK** / **LOCK** / **SLIME** (docs only now) | Be folded into `OrbType` |
| `PuzzleCell` | At `(x,y)`: optional `OrbType` **and/or** optional `Obstacle` | Match search; whole-board gravity |
| `PuzzleBoard` | Width/height grid; adjacent swaps; queries | Cascade orchestration; timer |
| `OrbGenerator` | Seeded supply of `OrbType` for initial fill / refill; match-stable initial fill helper | Obstacle placement policy; UI |
| `DragRoute` | Ordered cell path; 4-dir adjacency; revisit allowed; swap-on-new-enter | Match resolve; timer |
| `MatchResolver` | Find all orthogonal ≥3 runs; simultaneous clear set | Gravity; refill; input |
| `GravityResolver` | Per-column compact downward | Horizontal moves; match detect |
| `CascadeResolver` | Loop match→clear→gravity→refill with **finite guard**; returns success or error result | Player drag; ads |
| `PuzzleSession` | Mode/timer/phase; drag begin/move/release; forced timer expiry; runs cascade; read models | Pixel/hit-testing; AdMob |

**Naming note:** candidates above are the Phase 1-R vocabulary. R-A may adjust file layout under e.g. `scripts/puzzle/` without changing these contracts. **No Obstacle GDScript in Phase 1-R.**

---

## 7. State transition

```
                 start Score Attack
                 (match-stable fill)
                         │
                         ▼
              ┌─────────────────────┐
              │        IDLE         │◄───────────────┐
              └──────────┬──────────┘                │
           press valid orb│                          │
                         ▼                          │
              ┌─────────────────────┐                │
              │     ROUTE_DRAG      │                │
              └──────────┬──────────┘                │
        release / timer=0│                          │
              ┌──────────┴──────────┐                │
              │                     │                │
     release/forced          release/forced          │
     with ≥1 swap            with 0 swaps            │
              │                     │                │
              ▼                     ▼                │
     ┌─────────────────┐   SESSION_OVER              │
     │   RESOLVING     │   (no rollback)             │
     │ (input locked;  │                             │
     │  timer paused)  │                             │
     └────────┬────────┘                             │
              │ cascade done (ok)                    │
              ▼                                      │
        timer remaining?─────────────────────────────┘
              │ no
              ▼
     ┌─────────────────┐
     │  SESSION_OVER   │
     └─────────────────┘

Cascade guard breach → session error / input blocked (not IDLE).
```

| From | Event | To | Notes |
| --- | --- | --- | --- |
| — | `start_score_attack(seed, duration)` | IDLE | Match-stable initial fill; **no** opening cascade; **no** opening score |
| IDLE | pointer down on orb | ROUTE_DRAG | |
| ROUTE_DRAG | move to new orthogonal neighbor | ROUTE_DRAG | swap on new enter; revisit OK |
| ROUTE_DRAG | pointer jitter in same cell | ROUTE_DRAG | **no** re-swap |
| ROUTE_DRAG | timer → 0 | (see §12) | stop accepting new steps; forced release or SESSION_OVER |
| ROUTE_DRAG | release with ≥1 swap | RESOLVING | **no** rollback |
| ROUTE_DRAG | release with 0 swaps | IDLE | |
| RESOLVING | cascade stable | IDLE or SESSION_OVER | SESSION_OVER if timer already expired |
| RESOLVING | cascade guard breach | error / input blocked | fail-closed |
| IDLE | timer hits 0 | SESSION_OVER | |
| any | illegal input while RESOLVING | ignored | |

---

## 8. Initial board contract (match-stable)

**Locked:** initial board for Score Attack (and any mode using the same deal) is **match-stable**.

For **DEV 6×6 / 5 `OrbType`**:

1. After initial fill completes, there must be **no** horizontal or vertical run of length **≥ 3** of the same `OrbType`.
2. Generation **must not** run the cascade resolver to “clean up” matches.
3. Generation **must not** award Score for any initial configuration.
4. Generation is **seedable**: same seed ⇒ same initial board.
5. **Do not** use unbounded regenerate-entire-board retry loops.

**Allowed construction approach (normative intent):** when filling each cell in a deterministic scan order, exclude `OrbType`s that would complete a ≥3 run with the **two cells immediately left** and/or the **two cells immediately above** (edge-aware). Pick uniformly (or via RNG) among remaining legal types. If a cell somehow has zero legal types (should be rare with 5 types on 6×6), fail the deal construction with a deterministic error — **not** an infinite retry. R-A must prove with tests that the exclusion method yields a legal board for the DEV parameters under normal seeds.

Refill during cascade is **not** required to be match-stable cell-by-cell (cascades may create new matches by design). Match-stable applies to **initial fill only**.

---

## 9. Drag contract

1. **Start:** press on a cell that contains a swappable orb (not empty; future obstacles may block entry — obstacle phase).
2. **Step:** move into an **edge-adjacent** (4-dir) cell. **Revisit** of previously visited cells is **allowed**, including **immediate backtrack**.
3. **Swap rule:** perform a swap **only when newly entering a cell** (cell identity changes). Pointer motion that stays inside the same cell (**jitter**) must **not** cause another swap.
4. **Release:**  
   - If ≥1 swap occurred: enter `RESOLVING` and run cascade. **No route rollback.**  
   - If 0 swaps: return `IDLE` with no resolve.
5. **UI preview** may show the route; domain SoT remains `DragRoute` + board after swaps.
6. **Mouse** may share the same session APIs for editor testing; Android touch is the primary target.

---

## 10. Match / clear / gravity / refill / cascade contracts

### 10.1 Match

- Scan all rows: contiguous same `OrbType` length ≥ 3 → mark those cells.
- Scan all columns: same.
- **Union** marked cells = clear set.
- Empty cells and (future) obstacles do not extend orb runs.
- **No diagonals.**

### 10.2 Clear

- Remove all orbs in the clear set in one pass.
- Future: Obstacle (ROCK) damage hooks attach **here** without changing match geometry and without making ROCK an `OrbType`.

### 10.3 Gravity

- For each column independently: orbs fall toward **higher y** (bottom), preserving order; empties bubble to top.
- Future obstacles may act as blockers — defined in obstacle phase.

### 10.4 Refill

- For each empty cell after gravity, assign a new orb from `OrbGenerator` in a **deterministic order** (recommended: left→right `x`, within column top→bottom `y`). Fix exact loop in R-A tests and keep it stable.

### 10.5 Cascade + safety guard

```
steps = 0
repeat:
  matches = MatchResolver.detect(board)
  if matches empty:
    return CascadeResult.ok(stable)
  clear(matches)
  GravityResolver.apply(board)
  refill(board, generator)
  steps += 1
  if steps > MAX_CASCADE_STEPS:
    return CascadeResult.error(guard_exceeded)  # fail-closed
```

| Rule | Detail |
| --- | --- |
| Purpose of `MAX_CASCADE_STEPS` | **Implementation safety** against abnormal infinite loops — **not** a gameplay combo cap |
| Example constant | `128` (R-D may tune the number; **finite guard is mandatory**) |
| On exceed | **Not** treated as normal stable success |
| On exceed | `CascadeResult` error; `PuzzleSession` enters error / **input blocked** |
| On exceed | Must be **detectable in tests** |

---

## 11. RNG contract

1. `OrbGenerator` accepts an injected `RandomNumberGenerator` (or seed int that creates one).
2. **Same seed + same consumption sequence ⇒ same orb stream and same initial board.**
3. Consumption occurs on: initial board fill and every refill cell.
4. Player drag / swaps **do not** consume RNG.
5. Match-stable exclusion narrows candidates but must remain a **deterministic function** of seed + fill order + exclusion rules.
6. Tests must use ≥2 distinguishable orb types so mono-catalog collapse cannot fake reproducibility.
7. Do not assert Godot RNG internal numeric tables — only session-level reproducibility.

---

## 12. Timer contract

| Rule | Detail |
| --- | --- |
| Mode | Score Attack first |
| DEV default duration | 60 seconds (**not** final) |
| Comparison set | 45 / 60 / 90 — **remain open until on-device comparison** |
| Ticking | Only while phase is `IDLE` or `ROUTE_DRAG` |
| Paused | Entire `RESOLVING` (match/clear/gravity/refill/cascade) |
| Expiry mid-resolve | Finish cascade (or fail-closed); then `SESSION_OVER` |
| UI | May display remaining time; domain owns remaining seconds / ms |

### 12.1 Timer expiry during `ROUTE_DRAG` (locked)

When the timer reaches **0** while phase is `ROUTE_DRAG`:

1. **Stop accepting new route steps** immediately (held finger cannot add further moves).
2. If **≥1 swap** has already occurred on this route:  
   **forced release** of the current route (board stays as swapped — **no rollback**) → enter `RESOLVING` → run cascade to completion → then `SESSION_OVER`.
3. If **0 swaps**: go directly to `SESSION_OVER` (no resolve).

Former “cancel / revert-or-keep unresolved” language is **abolished**.

Score formulas remain unresolved in 1-R (§15); timer end still ends the session even if score is stubbed.

---

## 13. Orb / Obstacle separation (locked)

| Concept | Rule |
| --- | --- |
| `OrbType` | Normal playable orb identity **only** (DEV: 5 kinds). **No** ROCK/meta flags on `OrbType`. |
| `PuzzleCell` | May hold an optional orb **and** an optional obstacle (future). |
| `ObstacleType` candidates | **ROCK**, **LOCK**, **SLIME** |
| ROCK | First obstacle to implement later; **never** modeled as an `OrbType` |
| Phase 1-R code | **No** Obstacle GDScript yet — docs / attachment points only |

### 13.1 ROCK future attachment

| Hook | Intent |
| --- | --- |
| `PuzzleCell.obstacle` | Optional ROCK (then LOCK/SLIME) |
| Clear pass | Damage / break rules when affected by a clear (TBD in obstacle phase) |
| Drag | ROCK not route-enterable (expected; confirm later) |
| Gravity | Blocker vs crushable — TBD |
| LOCK / SLIME / Rescue Gauge | Explicitly later |

**Initial soft-lock rescue (if needed before gauge):** auto **Shuffle** only, domain-owned, seeded.

---

## 14. Legacy migration plan (current roadmap)

| Step | Phase | Action |
| --- | --- | --- |
| 0 | 1-R | Docs + contracts; PR #8 superseded |
| 1 | **R-A** | `OrbType` / `PuzzleCell` / `PuzzleBoard` / `OrbGenerator` / match-stable initial fill |
| 2 | **R-B** | `DragRoute` / 4-direction swap semantics only — **no** match resolve |
| 3 | **R-C** | `MatchResolver` / orthogonal ≥3 detection / simultaneous clear set |
| 4 | **R-D** | `GravityResolver` / refill / `CascadeResolver` / finite safety guard |
| 5 | **R-E** | `PuzzleSession` / timer / mid-drag forced release / provisional Score — **Score formula locked before R-E starts** |
| 6 | **R-F** | Minimal Puzzle UI / Android touch / playable Score Attack / 45·60·90 device comparison |
| 7 | **Gate 1** | After **R-F Android playable COMPLETE** |
| 8 | Post R-F | Decide legacy Block Placement deletion in a dedicated cleanup PR |
| 9 | Post Gate 1 | ROCK → later LOCK / SLIME / Rescue Gauge → Stage Mode |

**Parallel rule:** new tests must not delete or rewrite Phase 1-A/B/C tests until legacy removal PR. Legacy tests may remain green on unused code.

---

## 15. Unresolved specification

- Final board size (production)
- Final orb type count / art / colorblind palette
- **Score / combo formula** — may stay open through 1-R; **must lock a provisional formula before R-E implementation starts**
- **45 / 60 / 90** second duration choice — open until **on-device comparison** (R-F)
- ROCK damage numbers / break animation (post Gate 1)
- LOCK / SLIME semantics
- Rescue Gauge thresholds
- Stage Mode structure
- Production AdMob unit IDs
- Animation / juice / SFX / BGM / haptics
- Exact refill nested-loop order (must be fixed in R-D with tests)
- Session time unit (whole seconds vs ms)
- Exact `MAX_CASCADE_STEPS` numeric value (example 128; finite guard mandatory)

---

## 16. QA plan (for later R-\* phases; not executed in 1-R)

### Domain / GUT (minimum)

- Match-stable initial board for DEV 6×6 / 5 types; same seed ⇒ same board; no opening cascade/score
- Board swap adjacency validation
- Match detect: row, column, simultaneous union, no diagonal
- Gravity per column order preservation
- Refill top + seed reproducibility across two sessions
- Cascade terminates; no matches left; **guard exceed → error** (testable)
- Drag: 4-dir; revisit/backtrack; swap only on new cell enter; jitter no re-swap
- Timer pauses during resolve; mid-drag expiry forced-release / zero-swap SESSION_OVER
- Input ignored while RESOLVING
- Session over after expiry at IDLE

### Android (R-F)

- Route drag feel; release resolve; cascade readable
- Timer pause visibly during resolve; mid-drag expiry behavior
- 45 / 60 / 90 device comparison
- Portrait; no crash; Phase 0 consent/privacy regression

### Gate artifacts

- GUT all green including new puzzle tests
- Debug APK when UI exists
- Device checklist signed off for **R-F COMPLETE** → Gate 1

---

## 17. Gate 1 kill criteria

Stop or redesign **before** investing in Stage Mode / obstacles / economy if any of the following hold after first playable (**R-F** / Gate 1):

1. Route-drag swap is not understandable within ~10 seconds for new players in informal tests.
2. Cascades frequently feel unfair or unreadable (player cannot tell why clears happened).
3. 45/60/90 comparison shows **no** duration yields a satisfying Score Attack loop (always too short or endless stall).
4. Soft-locks require more than rare auto-Shuffle on DEV 6×6 / 5 types (board/type model considered broken).
5. Orthogonal-only matching is too weak/strong vs fun after tuning attempts.
6. Parallel legacy + new domain cost blocks shipping while Phase 0 ads baseline is at risk (process failure).

If Gate 1 fails → **REDESIGN** or **KILL** direction; do not paper over with meta (gacha/RPG).

---

## 18. Phase 1-R completion checklist

| Criterion | Met? |
| --- | --- |
| Boundary with old Block Placement clear (PR #8 SUPERSEDED) | YES |
| Puzzle domain responsibilities fixed | YES (§6) |
| Initial match-stable board fixed | YES (§8) |
| Drag contract fixed (incl. revisit) | YES (§9) |
| Match contract fixed | YES (§10.1–10.2) |
| Gravity / refill / cascade + safety guard fixed | YES (§10.3–10.5) |
| Timer contract fixed (incl. mid-drag expiry) | YES (§12) |
| Orb / Obstacle separation fixed | YES (§13) |
| ROCK future attachment points fixed | YES (§13.1) |
| Legacy migration order fixed | YES (§14) |
| Score deadline before R-E noted | YES (§15) |
| No Critical/High spec contradictions in locked decisions | YES |
| Implementation of new puzzle **not** started | YES |
| R-A **not** auto-started | YES |

---

## 19. Document index

| Doc | Role |
| --- | --- |
| This file (`docs/phase1r/README.md`) | Normative Phase 1-R contracts |
| Root `README.md` | Status pointer + Phase 0 / legacy note |

R-A should add `docs/phase1r/IMPLEMENTATION_NOTES.md` only when code lands.
