# Phase R-E0 — Provisional Score / Timer Contract

**Status:** COMPLETE (docs / contracts only) — implemented by Phase R-E `PuzzleSession`  
**Scope:** Lock Gate 1 Score Attack provisional scoring and domain timer/session contracts **before** R-E `PuzzleSession` implementation.  
**Code:** **No** GDScript gameplay changes in R-E0.

R-E must not start until this document is accepted.

---

## 1. Purpose

Phase 1-R left Score formula and session time unit open, with an explicit gate: provisional Score must be locked before R-E.

R-D delivered `CascadeResult.cleared_cell_count_per_step_snapshot()` as the neutral metric input.

R-E0 freezes:

- Provisional Score formula (signed 64-bit integer; cascade-depth bonus; fail-closed overflow)
- Timer unit = integer milliseconds
- DEV durations 45000 / 60000 / 90000 ms
- Timer ticking / pause states
- Mid-drag expiry + overshoot clamp
- Final forced-move scoring
- `PuzzleSession` state names and transitions

This is the **minimum** Score Attack loop for Gate 1 playability evaluation — not a final production economy.

---

## 2. Provisional Score formula (LOCKED)

### 2.1 Input

Use **only**:

```
CascadeResult.cleared_cell_count_per_step_snapshot() → Array[int]
```

Example: `[6, 3, 8]` means step 1 cleared 6 unique cells, step 2 cleared 3, step 3 cleared 8.

Step index is **1-based** in the formula (`step_index = 1` for the first cascade step).

### 2.2 Per-step scoring (integer only)

For each step with `cleared_cells` unique cleared cells:

```
base_score     = cleared_cells * 100
cascade_bonus  = cleared_cells * 25 * (step_index - 1)
step_score     = base_score + cascade_bonus
```

### 2.3 Move score

```
move_score = sum of all step_score values for that cascade
```

Session score accumulates `move_score` for each successfully resolved move.

### 2.4 Worked examples

| Per-step cleared | Computation | `move_score` |
| --- | --- | --- |
| `[3]` | step1: `3*100 + 3*25*0 = 300` | **300** |
| `[3, 3]` | step1: `300`; step2: `3*100 + 3*25*1 = 375` | **675** |
| `[5, 3, 4]` | step1: `500`; step2: `375`; step3: `4*100 + 4*25*2 = 600` | **1475** |

### 2.5 Vocabulary

- Call cascade progression **cascade step** / **cascade depth**
- Do **not** use the product name **"Combo"** for this provisional formula
- Match group counts are **not** part of Score in R-E0 / Gate 1 provisional

### 2.6 Explicitly excluded from Score (for now)

Do **not** add any of the following into provisional Score:

- match group count
- route length
- drag speed
- Orb color / type weighting
- special match shapes
- ROCK / LOCK / SLIME
- Rescue
- remaining time bonus
- Stage objective bonuses
- difficulty multipliers

Reason: Gate 1 needs a minimal readable score to evaluate core playability.

### 2.7 Score safety

| Rule | Detail |
| --- | --- |
| Storage type | Signed **64-bit** integer (`int64`) |
| `SCORE_MAX` | **9,223,372,036,854,775,807** (`INT64_MAX`) |
| Sign | Never negative under normal scoring |
| Eligible results | Award score **only** for `CascadeResult` that is **valid and stable** |
| Invalid cascade | `is_valid() == false` → **no** score add |
| Guard exceeded | `is_guard_exceeded() == true` → **no** score add; session → `ERROR` |

### 2.8 Overflow (LOCKED — fail-closed)

During **normal** score calculation, if a multiply or add is detected to exceed `SCORE_MAX`:

| Action | Required |
| --- | --- |
| Wrap / silent overflow | **Forbidden** |
| Saturate at `SCORE_MAX` | **Forbidden** |
| Add that move's `move_score` | **Do not add** |
| Prior session score | **Keep unchanged** |
| Session phase | → **`ERROR`** |
| Input | **Blocked** |

Detection must happen **before** mutating the stored session score (checked arithmetic on step/move accumulation and on `session_score + move_score`).

DEV 45/60/90s play is practically far below risk; the rule exists so longer sessions cannot ignore overflow.

---

## 3. Timer contract (LOCKED)

### 3.1 Domain time unit

| Rule | Value |
| --- | --- |
| SoT unit | **integer milliseconds** |
| Forbidden SoT | float seconds as session truth |
| DEV default duration | **60000** ms |
| Comparison set | **45000 / 60000 / 90000** ms |

Which of 45/60/90 becomes the shipped default remains an **R-F on-device comparison** product choice; the **unit and values** are fixed here for R-E implementation.

### 3.2 Domain API shape (normative intent)

```
advance_time(elapsed_ms: int) -> …
```

| `elapsed_ms` | Behavior |
| --- | --- |
| `> 0` | Apply tick (subject to ticking-state rules) |
| `== 0` | **no-op** |
| `< 0` | **reject / no-op** (no mutation) |

UI may display seconds; domain remaining time is always ms.

### 3.3 Ticking states

**Session Timer** advances in:

- `IDLE`
- `ROUTE_DRAG`

including while the UI `ResolutionPresenter` is busy (match / rock hit / gravity / refill / respawn / opening). Domain state is typically `IDLE` during that playback.

**Session Timer** does not advance in:

- Domain `RESOLVING` (synchronous resolve inside one call — not sticky UI presentation)
- `SESSION_OVER`
- `ERROR`
- `INVALID`
- Pre-session READY (no `PuzzleSession` yet)
- App background / focus out (UI adapter; no catch-up on focus in)

Domain `RESOLVING` duration is negligible (sync). **UI presentation duration intentionally consumes Session Timer** (Score Attack tempo). Move Timer stays `ROUTE_DRAG`-only.

### 3.3b Dual Timer — Move Timer (R-F gameplay lock)

| Rule | Value |
| --- | --- |
| `MOVE_DURATION_MS` | **2000** (Gate 1 DEV candidate; was 1500 / 3000; not production final) |
| Active | Only during `ROUTE_DRAG` (set on successful `begin_drag`) |
| Idle display | Domain reports inactive (`move_remaining_ms() == 0`); UI may show `---` |
| Tick | Same `elapsed_ms` deducted from Session + Move during `ROUTE_DRAG` |
| Hold | Same-cell / pointer-stopped still consumes Move |
| Pause | Domain `RESOLVING` / `SESSION_OVER` / `ERROR` / `INVALID` — both paused at `advance_time`. UI presentation (presenter busy while `IDLE`) does **not** pause Session Timer. |
| Move → 0, swaps ≥ 1 | Forced release → resolve → Score → `IDLE` if Session > 0 |
| Move → 0, swaps == 0 | Cancel-equivalent; no cascade; `IDLE` if Session > 0 |
| Session → 0 during drag | Session expiry wins (even if Move also 0 same tick); one forced release |
| Next drag | Successful `begin_drag` resets Move to 2000 |

SoT remains `PuzzleSession` — UI must not independently measure the 3s budget.

### 3.4 Overshoot clamp

Example: `remaining_ms = 100`, `advance_time(250)` → `remaining_ms = 0`.

- Never store negative remaining time
- Clamp at **0**
- Expiry side-effects fire **once** (idempotent after first expiry handling)

### 3.5 Mid-drag expiry (unchanged from Phase 1-R §12.1)

When `remaining_ms` reaches 0 during `ROUTE_DRAG`:

1. Stop accepting new route steps immediately
2. If `swap_count >= 1`: **forced release** → `RESOLVING` → run cascade to completion → if cascade **stable success**, award provisional Score for that move → `SESSION_OVER`
3. If `swap_count == 0`: no resolve → `SESSION_OVER`
4. **No route rollback**

### 3.6 Score vs timer on forced final move

- A mid-drag forced release that completes a **stable** cascade uses the **same** provisional Score formula as a normal release
- Timer does **not** tick during `RESOLVING`
- After cascade finishes, if timer is already 0 → `SESSION_OVER` (not return to `IDLE`)

---

## 4. Session states (LOCKED for R-E)

| State | Meaning |
| --- | --- |
| `INVALID` | Session failed construction / unusable |
| `IDLE` | Waiting for drag; timer may tick |
| `ROUTE_DRAG` | Active route; timer may tick |
| `RESOLVING` | Cascade running; input locked; timer paused |
| `SESSION_OVER` | Score Attack ended; input blocked for play |
| `ERROR` | Fail-closed (e.g. cascade guard / resolver failure); input blocked |

### 4.1 Transitions (normative)

| From | Event | To | Notes |
| --- | --- | --- | --- |
| — | successful Score Attack start | `IDLE` | Match-stable fill; score 0; no opening cascade |
| `IDLE` | begin drag success | `ROUTE_DRAG` | |
| `IDLE` | timer → 0 | `SESSION_OVER` | |
| `ROUTE_DRAG` | release with ≥1 swap | `RESOLVING` | no rollback |
| `ROUTE_DRAG` | release with 0 swaps | `IDLE` or `SESSION_OVER` | `SESSION_OVER` if timer already 0 |
| `ROUTE_DRAG` | timer → 0, swaps ≥1 | `RESOLVING` | forced release; then usually `SESSION_OVER` after cascade |
| `ROUTE_DRAG` | timer → 0, swaps 0 | `SESSION_OVER` | no resolve |
| `RESOLVING` | cascade stable, timer > 0 | `IDLE` | award `move_score` |
| `RESOLVING` | cascade stable, timer == 0 | `SESSION_OVER` | award `move_score` (includes forced final move) |
| `RESOLVING` | cascade error / guard / **score overflow** | `ERROR` | **no** score add for that move; prior session score kept; input blocked |
| `ERROR` / `SESSION_OVER` / `INVALID` | play input | ignored | |

Illegal input while `RESOLVING` is ignored.

---

## 5. Alignment with R-A…R-D

| Prior contract | R-E0 stance |
| --- | --- |
| R-D `CascadeResult` per-step cleared counts | **Sole** Score input |
| R-D guard exceeded / invalid | Not scored; session → `ERROR` when reached from resolve |
| R-D no Score fields on cascade types | Unchanged — Score lives in Session (R-E) |
| Phase 1-R mid-drag forced release | Affirmed; adds explicit Score-on-success |
| Phase 1-R timer pause in `RESOLVING` | Affirmed; unit fixed to ms |
| Phase 1-R “Score unresolved” | **Superseded** by this provisional formula |
| Phase 1-R “session time unit open” | **Superseded** — ms |
| Phase 1-R “45/60/90 open until comparison” | Values fixed in ms for DEV/API; **which default ships** still chosen after R-F device comparison |

No contradiction requiring R-D redesign.

---

## 6. Out of R-E0 scope

- Any `PuzzleSession` / Score / Timer GDScript
- UI / touch / scenes
- Changing R-A…R-D domain scripts
- Ads / Android export / Phase 0
- ROCK / Rescue / Stage Mode

---

## 7. R-E entry criteria

R-E implementation may start only when R-E0 is COMPLETE and this contract is the SoT for:

1. Provisional Score formula + safety
2. Timer ms unit + tick/pause + overshoot
3. Mid-drag expiry + forced final scoring
4. Session state machine names/transitions

Do **not** invent alternate Score or float-second SoT during R-E without a new contract revision.
