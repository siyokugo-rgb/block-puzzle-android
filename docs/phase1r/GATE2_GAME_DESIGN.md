# Gate 2 — Game Modes, Obstacle Progression, Evaluation

**Status:** Gate 2-A COMPLETE (docs / contracts only)
**Base:** `main` @ `11da3c5616e3e2b0ad71d08d78c64a2edcb9bdc1` (R-G COMPLETE)
**Scope of Gate 2-A:** documentation only. **No gameplay / Stage / Score / Obstacle code.**
**Gate 2-B:** NOT STARTED (paired-seed live eval; OFF / ROCK2 / ROCK3 / ROCK4)
**Market proof:** NOT CLAIMED — Gate 2 is design hypothesis / internal usability / tuning only.

Related: [`IMPLEMENTATION_NOTES.md`](IMPLEMENTATION_NOTES.md) (R-G ROCK slice), [`SCORE_TIMER_CONTRACT.md`](SCORE_TIMER_CONTRACT.md).

---

## 1. Purpose

Fix the **shipped product shape** and **how Obstacles sit at the core** before more Obstacle types or Stage runtime exist.

Gate 2 is **not** only “keep ROCK or delete ROCK.”

It evaluates whether dynamic Obstacles create:

- route thinking
- first-move planning (Countdown)
- intentional break decisions
- replayable board variation

…within acceptable frustration, under Session 60s / Move 2.0s.

---

## 2. Product modes (shipped direction)

Completed product carries **both**:

| Mode | Role |
| --- | --- |
| **A. Stage Clear** | Authored conditions / Obstacle layouts; sequential stages; teach each gimmick naturally |
| **B. Score Attack** | Player chooses Obstacle risk for higher Score potential |

Both modes share the **same Puzzle + Obstacle foundation**.
Do **not** fork a second match/gravity/obstacle engine per mode.

---

## 3. Stage Clear Mode

### 3.1 Role

Developer-authored Stage definitions control objectives and Obstacle pressure.
Players clear stages in order. Early stages teach gimmick meaning by play, not by long manuals.

### 3.2 Early rhythm (intro → practice)

Default cadence:

1. **Intro stage** — introduce one new gimmick
2. **Practice stage** — same gimmick alone, no re-lecture
3. Next gimmick intro → practice
4. After core gimmicks exist → **mixed** stages

Principle label: **intro → practice → next**.

Rules:

- Prefer one intro + one practice per gimmick
- Complex gimmicks may add extra practice stages
- **Do not** hard-require exactly two stages per gimmick forever

### 3.3 Intro stage presentation

Intro stages are **not** long text walls.

Goal: player learns by touching the board.

Optional short start tip (example wording only; not production copy lock):

- ROCK: impassable
- adjacent Match deals damage
- 2 hits break

Do not halt play with essay UI. **Runtime UI not implemented in Gate 2-A.**

### 3.4 Mid / late Stage design

**Mid:** combine ~2 already-learned gimmicks.
Difficulty must **not** be “Obstacle count ++ only.”

Variation candidates:

- Obstacle combination
- Initial layout
- Spawn / pressure counts
- Respawn policy
- Stage objective
- Duration
- Durability
- Board / Puzzle constraints

**Late:** richer mixes of known rules.
Priority: **judgment from rule combinations**, not bulk ROCK spam.

Forbidden progression model:

> Stage number ↑ ⇒ ROCK count ↑ only

### 3.5 Visible random durability (future Obstacles)

When an Obstacle takes multiple hits:

- Stage may randomize durability (example range: HP 1–3)
- **Remaining durability must always be visible to the player**

Forbidden: hidden internal HP (e.g. HP3) while UI shows nothing.

**Roll timing (when used):**

```
Stage start draw RNG
→ board generation
→ Opening
→ Countdown
→ play
```

Value is **fixed for that Stage**. Countdown lets the player read the board (including durability).

### 3.6 Stage Clear objective (MVP candidate)

First Stage Mode MVP candidate:

**Reach Target Score within the Stage time limit.**

Future objectives may include (not fixed now):

- break N ROCK
- clear N of a color
- cascade depth
- Rescue objective

**Concrete Stage quota numbers are NOT FIXED in Gate 2-A.**

### 3.7 Future Stage generation (cost control)

Prefer not hand-author every Stage forever.

Future candidate: **`StageDefinition`** fields such as:

- `stage_id`
- `duration`
- `objective`
- `obstacle_types` / counts
- `durability_range`
- `respawn`
- `rng_policy`

**Stage runtime is not implemented in Gate 2-A.**

### 3.8 Future Stage Validator (required if auto-gen)

Reject candidates such as:

- no legal opening moves
- impossible objective
- extreme Obstacle layouts
- invalid board
- unintended opening matches
- soft-lock / unprogressable
- fairness constraint violations

Gate 2-A records the **requirement only**.

---

## 4. Score Attack Mode

### 4.1 Role

Player opts into Obstacle risk to chase high Score.

**Gate 2 baseline timers (not production-final):**

| Knob | Baseline | Note |
| --- | --- | --- |
| Session | **60s** | Gate 2 baseline |
| Move | **2.0s** | Gate 2 baseline |
| 45s / 90s | DEV compare only | not production final |

### 4.2 Risk / reward direction

Higher Obstacle load → higher **Score multiplier** direction.

Concept:

| Load | Risk | Multiplier direction |
| --- | --- | --- |
| Low Obstacle | low risk | baseline multiplier |
| High Obstacle | high risk | higher multiplier |

**Concrete multipliers are NOT FIXED** (examples like ×1.00 / ×1.10 / ×1.25 are illustrative only).

### 4.3 Why multipliers wait for measurement

More Obstacles can **lower base Score**.
Picking multipliers without measuring that drop can force:

- high-difficulty only meta, or
- high-difficulty with no reward

→ **Set multipliers after play measurement (Gate 2-B+).**

### 4.4 ROCK count evaluation candidates (Gate 2-B)

Gate 2-B primary conditions (docs / optional later DEV):

- Obstacle **OFF** (control)
- Initial ROCK **2** (`initial = target = 2`)
- Initial ROCK **3** (baseline; `initial = target = 3`)
- Initial ROCK **4** (`initial = target = 4`)

**ROCK 5** is an optional post-result extension — **not** in the first comparison set.

Must keep **initial count = target count** per condition (no mid-session ease).

Comparison method: **paired-seed protocol** (§9). **No code change in Gate 2-A.**

### 4.5 Difficulty profile (future design principle)

If Score Attack exposes difficulty, a profile should own together:

- initial obstacle count
- target obstacle count (session pressure)
- respawn behavior
- Score multiplier

Anti-pattern example: `initial 5` + `target 3` silently eases after breaks.

Gate 2-A states the principle only — **no implementation**.

---

## 5. Obstacle OFF

| Role | Detail |
| --- | --- |
| **Control baseline** | DEV / QA / Gate measurement |
| **Not** | product-normal mode candidate |

Purpose: measure what Obstacles add.

If ROCK underperforms Gate 2:

1. Prefer **Obstacle design iteration**
2. Do **not** jump to “delete all Obstacles”

---

## 6. ROCK Gate 2 baseline (current shipped R-G)

Production-final **not** claimed. Gate 2 baseline:

| Item | Value |
| --- | --- |
| Board | 6×6 |
| OrbTypes | 5 |
| Initial ROCK count | **3** |
| Initial placement | **board-wide** unique cells |
| HP | **2** (R2→R1→break) |
| Traversal / grab | impassable / not grabable |
| Gravity | falling token (mixed column compact) |
| Gameplay respawn | **top-row** drop |
| Respawn grace | 1 valid move |
| Max respawn / move | 1 |
| Target ROCK count | 3 |
| Session | 60s |
| Move | 2.0s |
| Pre-game | Opening + Countdown 3s; clock starts at GO |
| Session seed | random on START / Restart; fixed-seed path for tests |
| Render | 60fps target |

Gameplay respawn remains top-row; Initial ROCK is board-wide — roles stay distinct.

---

## 7. Recorded positive finding (Android)

Board-wide random Initial ROCK made **Countdown (3s) meaningful for first-move planning**.

Formal Gate 2 **positive finding** — retain when judging ROCK value.

---

## 8. Gate 2 evaluation targets

Evaluate at least:

1. Route thinking load
2. First-move thinking (Countdown)
3. Intentional ROCK break decisions
4. Replayability
5. Dynamic board change
6. Frustration
7. Fit with Move 2.0s
8. Fit with Session 60s
9. Score agency
10. Fitness for future Stage Clear + Score Attack

Gate 2 is **not** market-success proof. User/self play ≠ market evidence.

---

## 9. Gate 2-A vs Gate 2-B

| Slice | Scope | Status |
| --- | --- | --- |
| **Gate 2-A** | Docs: modes, progression, risk/reward, ROCK baseline, **paired-seed eval protocol** | **COMPLETE** (this document) |
| **Gate 2-B** | Live paired-seed play: OFF / ROCK2 / ROCK3 / ROCK4 | **NOT STARTED** |

---

## 9A. Gate 2-B Paired-Seed Evaluation Protocol

### 9A.1 Why paired seeds

Normal START / Restart uses a **random Session seed**. Comparing different seeds across conditions mixes:

- Orb initial board
- ROCK placement
- refill sequence
- Obstacle RNG stream

…into the ROCK-count effect. Gate 2-B cannot separate “ROCK pressure” from “lucky/unlucky board.”

**Principle:** reuse the **same Session seed** across conditions; change **condition only**.

```
Seed A: OFF, ROCK2, ROCK3, ROCK4
Seed B: OFF, ROCK2, ROCK3, ROCK4
…
```

Condition **execution order** must **vary by seed** (see §9A.6) — do not always run OFF→R2→R3→R4.

### 9A.2 Seed count (Phase 1 → optional expand)

| Phase | Seeds | Conditions | Sessions |
| --- | --- | --- | --- |
| First Gate 2-B | **5** fixed seeds | 4 | **20** |
| Expand if ambiguous | up to **10** | 4 | up to **40** |

Do not start with a huge measurement campaign.

**Expand 5 → 10 when** (examples):

- condition gaps are inconsistent across seeds
- Score variance is large
- ROCK2/3/4 feel ambiguous
- 1–2 seeds alone reverse the trend

If trends are clear after 5 seeds, **do not** require 10. Gate 2 is an **internal tuning gate**, not a statistics study.

### 9A.3 Seed selection

- Gate 2-B seeds are **explicit fixed integers**, recorded in docs/notes when Gate 2-B starts
- Once a comparison set is adopted: **no cherry-picking / swapping seeds after seeing results**

### 9A.4 Fixed session variables (all conditions)

| Variable | Value |
| --- | --- |
| Board | 6×6 |
| OrbTypes | 5 |
| Session | 60000 ms |
| Move | 2000 ms |
| ROCK HP | 2 |
| Countdown | 3 s |
| FPS target | 60 |
| Score formula | current raw / base Score |
| Score multiplier | **NONE** |
| Difficulty bonus | **NONE** |
| New Obstacle types | **NONE** |

Primary independent variable: **ROCK pressure / count**.

### 9A.5 Conditions

| Id | Condition | initial ROCK | target ROCK |
| --- | --- | --- | --- |
| A | Obstacle **OFF** | 0 | 0 |
| B | **ROCK2** | **2** | **2** |
| C | **ROCK3** (baseline) | **3** | **3** |
| D | **ROCK4** | **4** | **4** |

Optional later: **ROCK5** only after first-set results — not in the initial 4.

**Forbidden:** `initial 4` + `target 3` (or any profile that silently eases mid-session). Respawn pressure stays on the **same difficulty profile**.

ROCK rules held constant except count:

- HP2, impassable, not grabable
- board-wide initial random
- gameplay respawn top-row
- 1 valid-move grace; max 1 respawn/move
- falling gravity; 2-hit break

**OFF** remains DEV / QA / Gate **control** — not a product-normal candidate. High OFF Score must **not** alone conclude “delete Obstacles.” Measure impact on route judgment, Score, frustration, replayability.

### 9A.6 Condition order (order-effect control)

Do **not** use the same order every seed (e.g. always OFF → R2 → R3 → R4).

Vary order per seed so the same condition is not always first/last. Full factorial counterbalance is **not** required.

Example pattern (illustrative):

| Seed | Order |
| --- | --- |
| A | OFF → R2 → R3 → R4 |
| B | R4 → R3 → R2 → OFF |
| C | R2 → OFF → R4 → R3 |
| D | R3 → R4 → OFF → R2 |
| E | R2 → R3 → R4 → OFF |

Controls: learning, fatigue, focus drift.

### 9A.7 Valid vs forbidden comparisons

**Unit of comparison:** same-seed condition deltas, then trends across seeds.

**Forbidden:** judging ROCK4 “worse” from Seed A ROCK2 Score vs Seed B ROCK4 Score alone (cross-seed, cross-condition raw mix).

### 9A.8 Score recording

Record **raw / base Score only**. No difficulty multiplier during Gate 2-B.

Reason: measure how Obstacle pressure itself moves Base Score **before** designing Score Attack multipliers.

After Gate 2-B, use Base Score drop trends to design multipliers that:

- compensate difficulty without forcing high-difficulty-only or low-difficulty-only metas

Concrete multipliers remain **NOT FIXED** in Gate 2-A.

### 9A.9 Per-session minimum record fields

| Field | Notes |
| --- | --- |
| trial id | unique row id |
| session seed | fixed paired seed |
| condition | OFF / ROCK2 / ROCK3 / ROCK4 |
| initial ROCK count | |
| target ROCK count | must match initial for ROCK conditions |
| final raw/base score | no multiplier |
| resolved move count | separates lower Score vs fewer moves vs break investment |
| ROCK breaks | avoid-only vs intentional targeting |
| intentionally targeted ROCK? | YES / NO / SOMETIMES |
| ROCK forced route change? | YES / NO |
| planned first move during Countdown? | YES / NO |
| Move 2.0s felt too tight? | TOO TIGHT / OK / TOO LOOSE |
| frustration | LOW / MEDIUM / HIGH |
| notes / anomaly | free text |

Subjective fields are **internal playtest**, not market proof. Do not over-precision score them.

### 9A.10 Optional future telemetry (Gate 2-B DEV only; not Gate 2-A)

If cheap during minimal DEV: move count, cleared cells, cascade steps, ROCK hits, ROCK breaks.
**No** large telemetry framework in Gate 2-A. **No implementation here.**

### 9A.11 Interpretation (not Score-max alone)

Watch the balance:

ROCK ↑ → route thinking ↑ / replayability ↑
vs
Score ↓ / frustration ↑ / move count ↓

### 9A.12 Links to Stage Clear / Score Attack

Gate 2-B ROCK pressure results inform both modes later, e.g. candidates:

- ROCK2 → early Stage pressure
- ROCK3 → mid / baseline
- ROCK4 → high pressure

Do **not** production-fix Stage layouts before Gate 2-B ends.

### 9A.13 Market proof

Paired-seed Gate 2-B still does **not** prove market demand or retention. It confirms gameplay hypothesis, internal usability, and relative tuning only.

---

## 10. Outcome labels (not binary only)

Paired-seed evidence required for these labels:

| Label | Meaning |
| --- | --- |
| **PASS** | Across multiple paired seeds, ROCK clearly increases route judgment; frustration acceptable |
| **PASS WITH FINDINGS** | Obstacle direction valid; tune count / target / respawn / score incentive / etc. |
| **FIX FIRST** | Concept valid; current pressure values clearly inappropriate |
| **REDESIGN** | Even under paired comparison, ROCK barely adds route judgment; mostly soft-lock / unfairness |

---

## 11. After Gate 2 (choose from results; do not auto-start)

Candidates (order undecided until Gate 2 finishes):

1. Freeze ROCK baseline temporarily
2. Stage Mode foundation design
3. Score Attack difficulty profile design
4. Second Obstacle design

Do **not** start these from Gate 2-A alone.

---

## 12. Next Obstacles (NOT STARTED before Gate 2 ends)

Do **not** implement before Gate 2 completes.

| Candidate | Role hypothesis (undecided detail) |
| --- | --- |
| **ROCK** | Avoid / break (current) |
| **SLIME** | Traversable + possible Orb color convert (usable Obstacle) |
| **LOCK** | Restraint / lock candidate |
| **Rescue** | Soft-lock / stuck-board relief candidate |

Exact rules **not production-final**.

---

## 13. Explicitly out of Gate 2-A

No implementation of:

- Stage runtime / select / save
- Score multiplier tables
- Difficulty selector UI
- SLIME / LOCK / Rescue / new Obstacle types
- production UI / art / audio
- `PuzzleSession` / Score formula changes
- Android / Ads / UMP / `project.godot` changes

---

## 14. Source of truth notes

- R-G COMPLETE contracts remain unless this doc **resolves a contradiction**
- Obstacle OFF = control; ROCK = product-standard **candidate**
- Multipliers and Stage quotas remain **unfixed** until measured

---

## 15. Gate 2-A completion checklist

- [x] Stage Clear role
- [x] Score Attack role
- [x] intro → practice progression
- [x] later mixed Obstacle principle
- [x] visible random durability
- [x] Score multiplier after measurement
- [x] OFF = control
- [x] ROCK baseline
- [x] Gate 2 evaluation fields
- [x] PASS / FIX / REDESIGN criteria
- [x] future Validator requirement
- [x] Gate 2-B paired-seed protocol (same seed × conditions; order variation; raw Score; initial=target; 5→10 rule)
- [x] no gameplay implementation in this phase
