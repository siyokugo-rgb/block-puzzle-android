# Phase 1-R — Route-Drag Match Puzzle Redesign

**Status:** COMPLETE (docs / contracts only) — awaiting review  
**Branch:** `cursor/phase1r-route-match-redesign-b8da`  
**Base:** `main` @ `a5c1a339dc07f4296761f3a10b408c3b881ec6d3`  
**Scope of this phase:** documentation and boundary freeze only. **No new puzzle domain implementation in 1-R.**  
**Do not start Phase R-A until this PR is accepted.**

---

## 1. Purpose

Replace the superseded **Block Placement** vertical slice (Phase 1-A…1-D) with a **Route-Drag Match Puzzle** product direction.

Phase 1-R fixes:

- Core loop vocabulary
- Domain responsibilities
- Drag / match / gravity / refill / cascade contracts
- Timer / Score Attack first mode
- Obstacle roadmap attachment points (ROCK first)
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

### 2.2 Legacy domain (SUPERSEDED — keep until R-D playable COMPLETE)

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

**Phase 1-R rule:** do **not** delete these types. New puzzle domain is implemented **in parallel**. Legacy deletion is decided only after **R-D playable loop = COMPLETE**.

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
  → ROUTE_DRAG (orthogonal adjacent steps; swap as route grows)
  → pointer release
  → RESOLVING (input locked)
       loop while matches exist:
         detect simultaneous matches (≥3 orthogonal runs)
         clear matched orbs (+ ROCK damage hooks later)
         gravity per column
         refill from top via seeded generator
       end loop
  → if Score Attack timer expired → SESSION_OVER
  → else IDLE
```

**Player verb:** draw a route by dragging through orthogonally adjacent orbs; each step **swaps** the dragged orb with the entered neighbor (route-drag swap model).

**Resolve trigger:** **release only**. Mid-drag never starts match resolve.

---

## 4. Fixed development / product decisions

These are **locked for Phase 1-R contracts**. Values marked DEV are defaults for first playable, **not** final production freezes.

| Topic | Decision |
| --- | --- |
| DEV board size | **6×6** (not final production size) |
| DEV orb types | **5** distinct `OrbType`s (not final catalog) |
| Drag | Route drag |
| First adjacency | **4-direction** (up / down / left / right) only |
| Route effect | Swap with each newly entered adjacent orb along the route |
| Resolve start | On **release** |
| Match shape | Orthogonal runs of **≥3** same type (rows and columns) |
| Diagonal match | **None** |
| Clear | All current matches clear **simultaneously** |
| Gravity | **Per column** (cells fall down within column) |
| Refill | New orbs enter from the **top** of each column |
| Cascade | Repeat match→clear→gravity→refill until **no matches** |
| RNG | Seedable; same seed ⇒ reproducible sequences (see §9) |
| Input during resolve | **Forbidden** while resolver / cascade running |
| Session timer | Configurable duration |
| Timer during resolve | **Paused** for resolver / cascade |
| First playable mode | **Score Attack** |
| DEV timer default | **60s** — compare **45 / 60 / 90** later; **not** a final fixed value |
| First obstacle | **ROCK** (future attachment; not required in first R-A skeleton) |
| LOCK | Deferred |
| SLIME | Deferred further |
| Rescue Gauge | Deferred |
| Initial rescue | If needed: **auto Shuffle only** (no gauge) |
| Stage Mode | After Score Attack is complete |
| Explicitly out | RPG / gacha / stamina / online ranking |

---

## 5. Invariants

1. **PuzzleSession is Source of Truth** for board occupancy, orb identities, phase (IDLE / ROUTE_DRAG / RESOLVING / SESSION_OVER), score (when added), and timer remaining.
2. **UI never owns** match detection, gravity, refill, cascade, or game-over/session-over rules.
3. **Pixels never enter domain APIs.** Domain uses board cell coordinates `Vector2i` (x right, y down, origin top-left) consistent with Phase 1-A convention.
4. **Drag mutates only via explicit swap steps** recorded on `DragRoute`; release hands the post-drag board to resolve — or an equivalent session API that applies the route then resolves.
5. **Resolve is atomic from the player's perspective:** no input until cascade settles.
6. **Simultaneous clear:** within one detect pass, every matched cell is cleared once (union of row/column runs); no sequential clear order that would change gravity mid-pass.
7. **No diagonal matching** in any detect pass.
8. **Gravity is column-local:** orb in column `x` never moves to another column during gravity.
9. **Refill only fills empty cells after gravity**, top-down (or equivalent: empty slots at top after compact-down).
10. **Cascade stops** iff a full detect pass finds zero matches.
11. **Timer does not tick** while phase is `RESOLVING` (and any future pause states).
12. **Score Attack session ends** when timer reaches zero **after** returning to IDLE (i.e. do not cut off mid-cascade; finish current resolve, then apply expiry). Exact “expire mid-drag” policy: cancel drag without resolve, then SESSION_OVER if time already zero — see unresolved §14 if product wants otherwise.
13. **Legacy Block Placement domain remains compilable** until explicit deletion phase; new code must not require deleting it first.
14. **Phase 0 ads/consent path remains bootable** on production main.

---

## 6. Responsibility table (new domain candidates)

| Type | Responsibility | Must not do |
| --- | --- | --- |
| `OrbType` | Identity / equality of orb kinds (DEV: 5); later ROCK/meta flags attachment | Rendering; RNG |
| `PuzzleCell` | Cell contents at `(x,y)` — orb or empty; optional obstacle slot later | Match search; gravity of whole board |
| `PuzzleBoard` | Width/height grid of cells; swap two adjacent cells; queries | Cascade orchestration; timer |
| `OrbGenerator` | Seeded supply of `OrbType` for refill / initial fill | Board mutation policy; UI |
| `DragRoute` | Ordered cell path; validates orthogonal adjacency; records swaps | Match resolve; timer |
| `MatchResolver` | Find all orthogonal ≥3 runs; compute clear set (simultaneous) | Gravity; refill; input |
| `GravityResolver` | Per-column compact downward | Horizontal moves; match detect |
| `CascadeResolver` | Loop: match → clear → gravity → refill until stable | Player drag; ads |
| `PuzzleSession` | Mode/timer/phase; accepts drag begin/move/release; runs cascade; exposes read models | Pixel/hit-testing; AdMob |

**Naming note:** candidates above are the Phase 1-R vocabulary. R-A may adjust file layout under e.g. `scripts/puzzle/` without changing these contracts.

---

## 7. State transition

```
                 start Score Attack
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
        release / cancel │                          │
              ┌──────────┴──────────┐                │
              │                     │                │
         release              cancel/empty           │
              │               route                  │
              ▼                     │                │
     ┌─────────────────┐            │                │
     │   RESOLVING     │            │                │
     │ (input locked;  │            │                │
     │  timer paused)  │            │                │
     └────────┬────────┘            │                │
              │ cascade done        │                │
              ▼                     │                │
        timer remaining?────────────┼────────────────┘
              │ no
              ▼
     ┌─────────────────┐
     │  SESSION_OVER   │
     └─────────────────┘
```

| From | Event | To | Notes |
| --- | --- | --- | --- |
| — | `PuzzleSession.start_score_attack(seed, duration)` | IDLE | Initial fill via generator; no opening match cascade unless product later requires “stable deal” (unresolved §14) |
| IDLE | pointer down on orb | ROUTE_DRAG | |
| ROUTE_DRAG | move to orthogonal neighbor | ROUTE_DRAG | swap; extend route |
| ROUTE_DRAG | release with ≥1 swap (or ≥2 cells in route — see §8) | RESOLVING | |
| ROUTE_DRAG | cancel / release with no mutation | IDLE | |
| RESOLVING | cascade stable | IDLE or SESSION_OVER | SESSION_OVER if timer already expired |
| IDLE | timer hits 0 while idle | SESSION_OVER | |
| any | illegal input while RESOLVING | ignored | |

---

## 8. Drag contract

1. **Start:** press on a cell that contains a swappable orb (not empty; ROCK policy later).
2. **Step:** enter an **edge-adjacent** (4-dir) cell; if valid, **swap** the orb under the “head” with that neighbor and append the cell to `DragRoute`.
3. **Revisit:** first implementation **rejects** re-entering a cell already on the route (no self-crossing). If playtests demand otherwise, treat as unresolved change — default is **no revisit**.
4. **Release:**  
   - If the board changed (at least one swap): enter `RESOLVING` and run cascade.  
   - If no swap occurred: return `IDLE` with no resolve.
5. **UI preview** may show the route; domain SoT remains `DragRoute` + board after swaps.
6. **Mouse** may share the same session APIs for editor testing; Android touch is the primary target.

---

## 9. Match / clear / gravity / refill / cascade contracts

### 9.1 Match

- Scan all rows: contiguous same `OrbType` length ≥ 3 → mark those cells.
- Scan all columns: same.
- **Union** marked cells = clear set.
- Empty cells and (future) non-matching obstacles do not extend runs.
- **No diagonals.**

### 9.2 Clear

- Remove all orbs in the clear set in one pass.
- Future: ROCK adjacent-to-clear or ROCK-in-clear damage hooks attach **here** without changing match geometry.

### 9.3 Gravity

- For each column independently: occupied orbs fall toward **higher y** (bottom), preserving order; empties bubble to top.

### 9.4 Refill

- For each empty cell after gravity, assign a new orb from `OrbGenerator` in a **deterministic column order** (recommended: left→right `x`, and within column top→bottom `y` for empties). Document the exact nested loop in R-A tests and keep it stable.

### 9.5 Cascade

```
repeat:
  matches = MatchResolver.detect(board)
  if matches empty: break
  clear(matches)
  GravityResolver.apply(board)
  refill(board, generator)
until stable
```

---

## 10. RNG contract

1. `OrbGenerator` accepts an injected `RandomNumberGenerator` (or seed int that creates one).
2. **Same seed + same consumption sequence ⇒ same orb stream.**
3. Consumption occurs on: initial board fill and every refill cell.
4. Player drag / swaps **do not** consume RNG.
5. Tests must use ≥2 distinguishable orb types so mono-catalog collapse cannot fake reproducibility.
6. Do not assert Godot RNG internal numeric tables — only session-level reproducibility.

---

## 11. Timer contract

| Rule | Detail |
| --- | --- |
| Mode | Score Attack first |
| DEV default duration | 60 seconds (not final) |
| Comparison set | 45 / 60 / 90 later |
| Ticking | Only while phase is `IDLE` or `ROUTE_DRAG` |
| Paused | Entire `RESOLVING` (match/clear/gravity/refill/cascade) |
| Expiry mid-drag | Cancel drag (revert or keep? → **revert route swaps** preferred for fairness); then SESSION_OVER |
| Expiry mid-resolve | Finish cascade; then SESSION_OVER |
| UI | May display remaining time; domain owns remaining seconds / ms |

Score formulas are **unresolved** (§14); timer end still ends the session even if score is stubbed.

---

## 12. ROCK future attachment (not implemented in 1-R)

| Hook | Intent |
| --- | --- |
| `PuzzleCell` obstacle field | Optional ROCK (and later LOCK/SLIME) beside / instead of orb |
| Clear pass | Damaging ROCK when adjacent to a cleared match (exact rule TBD in obstacle phase) |
| Drag | ROCK not route-enterable (expected); confirm in obstacle phase |
| Gravity | ROCK static blocker vs crushable — TBD with ROCK phase |
| LOCK / SLIME / Rescue Gauge | Explicitly later; do not encode into 1-R APIs beyond optional reserved enums |

**Initial soft-lock rescue (if needed before gauge):** auto **Shuffle** only, domain-owned, seeded.

---

## 13. Legacy migration plan

| Step | Phase | Action |
| --- | --- | --- |
| 0 | 1-R (this) | Docs + contracts; PR #8 superseded |
| 1 | R-A | Implement puzzle domain (+ GUT) **alongside** legacy `scripts/game/*` |
| 2 | R-B | Headless session loop: drag → resolve → cascade → timer |
| 3 | R-C | Minimal UI render + route drag input (PuzzleView); main hosts child without breaking Ads/UMP |
| 4 | R-D | Playable Score Attack loop on device; COMPLETE gate |
| 5 | Post R-D | Decide legacy deletion (`BoardState`…`GameSession`, 1-D UI) in a dedicated cleanup PR |
| 6 | Later | ROCK → LOCK → SLIME → Rescue Gauge → Stage Mode |

**Parallel rule:** new tests must not delete or rewrite Phase 1-A/B/C tests until legacy removal PR. Legacy tests may remain green on unused code.

---

## 14. Unresolved specification

- Final board size (production)
- Final orb type count / art / colorblind palette
- Score / combo formula for Score Attack
- Whether initial deal must be match-stable (no auto-resolve on start)
- Exact mid-drag timer expiry UX copy
- ROCK damage numbers / break animation
- LOCK / SLIME semantics
- Rescue Gauge thresholds
- Stage Mode structure
- Production AdMob unit IDs
- Animation / juice / SFX / BGM / haptics
- Whether route may revisit cells (default: no)
- Exact refill nested-loop order (must be fixed in R-A with tests)
- Session time unit (whole seconds vs ms)

---

## 15. QA plan (for later R-\* phases; not executed in 1-R)

### Domain / GUT (minimum)

- Board swap adjacency validation
- Match detect: row, column, simultaneous union, no diagonal
- Gravity per column order preservation
- Refill top + seed reproducibility across two sessions
- Cascade terminates; no matches left
- Drag route: 4-dir only; swap sequence; release triggers one resolve
- Input ignored while RESOLVING
- Timer pauses during resolve; DEV 60s configurable
- Session over after expiry at IDLE

### Android (R-D)

- Route drag feel; release resolve; cascade readable
- Timer pause visibly during resolve
- Portrait; no crash; Phase 0 consent/privacy regression

### Gate artifacts

- GUT all green including new puzzle tests
- Debug APK when UI exists
- Device checklist signed off for R-D COMPLETE

---

## 16. Gate 1 kill criteria

Stop or redesign **before** investing in Stage Mode / obstacles / economy if any of the following hold after first playable (R-D):

1. Route-drag swap is not understandable within ~10 seconds for new players in informal tests.
2. Cascades frequently feel unfair or unreadable (player cannot tell why clears happened).
3. 45/60/90 comparison shows **no** duration yields a satisfying Score Attack loop (always too short or endless stall).
4. Soft-locks require more than rare auto-Shuffle on DEV 6×6 / 5 types (board/type model considered broken).
5. Orthogonal-only matching is too weak/strong vs fun after tuning attempts.
6. Parallel legacy + new domain cost blocks shipping while Phase 0 ads baseline is at risk (process failure).

If Gate 1 fails → **REDESIGN** or **KILL** direction; do not paper over with meta (gacha/RPG).

---

## 17. Phase 1-R completion checklist

| Criterion | Met? |
| --- | --- |
| Boundary with old Block Placement clear (PR #8 SUPERSEDED) | YES |
| Puzzle domain responsibilities fixed | YES (§6) |
| Drag contract fixed | YES (§8) |
| Match contract fixed | YES (§9.1–9.2) |
| Gravity / refill / cascade fixed | YES (§9.3–9.5) |
| Timer contract fixed | YES (§11) |
| ROCK future attachment points fixed | YES (§12) |
| Legacy migration order fixed | YES (§13) |
| No Critical/High spec contradictions in locked decisions | YES (open items listed as unresolved, not contradictions) |
| Implementation of new puzzle **not** started | YES |
| R-A **not** auto-started | YES |

---

## 18. Document index

| Doc | Role |
| --- | --- |
| This file (`docs/phase1r/README.md`) | Normative Phase 1-R contracts |
| Root `README.md` | Status pointer + Phase 0 / legacy note |

R-A should add `docs/phase1r/IMPLEMENTATION_NOTES.md` only when code lands.
