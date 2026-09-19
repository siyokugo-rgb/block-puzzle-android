# Gate 2-B Results Template

**Status:** empty template — Gate 2-B2 LIVE EVALUATION **NOT STARTED**
**Protocol:** [`GATE2_GAME_DESIGN.md`](GATE2_GAME_DESIGN.md) §9A
**Harness:** Gate 2-B1 **COMPLETE** (PR #19) — APK `gate2b-rock-pressure-test-f327ee3` @ `f327ee3`

Do **not** swap seeds, condition order, or trial ids after adoption.

---

## Fixed seeds

| Id | Seed |
| --- | --- |
| S1 | 104729 |
| S2 | 130363 |
| S3 | 196613 |
| S4 | 262147 |
| S5 | 524287 |

## Fixed session variables

| Variable | Value |
| --- | --- |
| Board | 6×6 |
| OrbTypes | 5 |
| Session | 60000 ms |
| Move | 2000 ms |
| ROCK HP | 2 |
| Countdown | 3 s |
| Score | raw / base only |
| Multiplier | NONE |

## Condition order (do not reorder)

| Seed | Order |
| --- | --- |
| S1 | OFF → R2 → R3 → R4 |
| S2 | R2 → R3 → R4 → OFF |
| S3 | R3 → R4 → OFF → R2 |
| S4 | R4 → OFF → R2 → R3 |
| S5 | R2 → OFF → R4 → R3 |

## 20-trial schedule (fixed)

| trial | seed | condition | initial | target | raw score | resolved moves | ROCK breaks | targeted ROCK | route change | Countdown planning | Move 2s | frustration | notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T01 | S1 104729 | OFF | 0 | 0 |  |  |  |  |  |  |  |  |  |
| T02 | S1 104729 | ROCK2 | 2 | 2 |  |  |  |  |  |  |  |  |  |
| T03 | S1 104729 | ROCK3 | 3 | 3 |  |  |  |  |  |  |  |  |  |
| T04 | S1 104729 | ROCK4 | 4 | 4 |  |  |  |  |  |  |  |  |  |
| T05 | S2 130363 | ROCK2 | 2 | 2 |  |  |  |  |  |  |  |  |  |
| T06 | S2 130363 | ROCK3 | 3 | 3 |  |  |  |  |  |  |  |  |  |
| T07 | S2 130363 | ROCK4 | 4 | 4 |  |  |  |  |  |  |  |  |  |
| T08 | S2 130363 | OFF | 0 | 0 |  |  |  |  |  |  |  |  |  |
| T09 | S3 196613 | ROCK3 | 3 | 3 |  |  |  |  |  |  |  |  |  |
| T10 | S3 196613 | ROCK4 | 4 | 4 |  |  |  |  |  |  |  |  |  |
| T11 | S3 196613 | OFF | 0 | 0 |  |  |  |  |  |  |  |  |  |
| T12 | S3 196613 | ROCK2 | 2 | 2 |  |  |  |  |  |  |  |  |  |
| T13 | S4 262147 | ROCK4 | 4 | 4 |  |  |  |  |  |  |  |  |  |
| T14 | S4 262147 | OFF | 0 | 0 |  |  |  |  |  |  |  |  |  |
| T15 | S4 262147 | ROCK2 | 2 | 2 |  |  |  |  |  |  |  |  |  |
| T16 | S4 262147 | ROCK3 | 3 | 3 |  |  |  |  |  |  |  |  |  |
| T17 | S5 524287 | ROCK2 | 2 | 2 |  |  |  |  |  |  |  |  |  |
| T18 | S5 524287 | OFF | 0 | 0 |  |  |  |  |  |  |  |  |  |
| T19 | S5 524287 | ROCK4 | 4 | 4 |  |  |  |  |  |  |  |  |  |
| T20 | S5 524287 | ROCK3 | 3 | 3 |  |  |  |  |  |  |  |  |  |

## Subjective field enums (manual)

- targeted ROCK: YES / NO / SOMETIMES
- route change: YES / NO
- Countdown planning: YES / NO
- Move 2s: TOO TIGHT / OK / TOO LOOSE
- frustration: LOW / MEDIUM / HIGH

Internal playtest only — **not** market proof.
