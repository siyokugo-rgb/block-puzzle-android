# block-puzzle-android

Phase 0 production baseline for Godot 4.7.2 Android + GUT + AdMob/UMP.

Phase 1-A…1-C added a UI-free **Block Placement** domain (`BoardState` / tray / `GameSession`).  
Phase 1-D (PR #8) attempted a playable placement slice — **SUPERSEDED** by product redesign (closed unmerged).

**Phase 1-R** freezes the new **Route-Drag Match Puzzle** contracts (docs only): see [`docs/phase1r/README.md`](docs/phase1r/README.md).

Legacy Block Placement types remain on `main` until post–**R-F** cleanup. Phase 0 Ads/UMP/Android/GUT must not be broken.

## Status

| Phase | Result |
| --- | --- |
| 0-A Android APK | COMPLETE |
| 0-B GUT | COMPLETE |
| 0-C AAB | COMPLETE |
| 0-D AdMob test banner | COMPLETE |
| 0-E UMP consent gate | COMPLETE — Android reference-device scenarios A–E PASS |
| 0-F Production baseline closeout | COMPLETE |
| 1-A Block placement game core | COMPLETE (legacy; SUPERSEDED direction) |
| 1-B Piece supply / tray / placement search | COMPLETE (legacy; SUPERSEDED direction) |
| 1-C Game session / tray lifecycle / Game Over | COMPLETE (legacy; SUPERSEDED direction) |
| 1-D Minimal playable placement slice | SUPERSEDED / REDESIGN — PR #8 closed unmerged |
| 1-R Route-drag match redesign (docs) | COMPLETE |
| R-A PuzzleBoard / Orb / stable initial fill | COMPLETE (Draft PR) |

Xperia was the **reference test device** for Phase 0-E. The implementation itself is **Android-generic** (no Sony/Xperia-only APIs or branches).

## Phase 1-A game core

UI-free domain model only (no tray / score / input / drawing):

| Type | Path |
| --- | --- |
| `PieceShape` | `scripts/game/piece_shape.gd` |
| `BoardState` | `scripts/game/board_state.gd` |
| `LineClearResult` | `scripts/game/line_clear_result.gd` |

Contract:

- Cell coordinates: x left→right, y top→bottom, origin top-left `(0,0)`
- Occupied: binary occupancy grid backed by `PackedByteArray` rows (`0` empty / `1` occupied); no pixel / UI coords
- Invalid pieces are rejected (`is_valid() == false`), never silently accepted
- `place()` is atomic: validate all cells, then commit; failure leaves the board unchanged
- Line clear detects all full rows/columns first, then clears the cell union once (intersections counted once)
- Board size is constructor input (not hard-coded); tests use small boards. Final playable board size is **not** finalized in Phase 1-A.

## Phase 1-B piece supply

| Type | Path |
| --- | --- |
| `PieceCatalog` | `scripts/game/piece_catalog.gd` |
| `PieceGenerator` | `scripts/game/piece_generator.gd` |
| `PieceTray` | `scripts/game/piece_tray.gd` |
| `PlacementSearch` | `scripts/game/placement_search.gd` |

Contract:

- Tray has exactly **3** slots; `consume(index)` empties one slot; no auto-refill in Phase 1-B
- Generator uses injected `RandomNumberGenerator` (seedable); uniform pick from catalog (not production weighting)
- Same seed + same catalog → reproducible sequence
- Placement search derives origin bounds from piece min/max offsets (supports negative / translated offsets); `BoardState.can_place` is SoT
- `PlacementSearch.has_any_placeable_piece` checks remaining tray pieces only — **not** a Game Over API
- Production piece catalog / board size / rotation / refill lifecycle remain unspecified

## Phase 1-C game session

| Type | Path |
| --- | --- |
| `GameSession` | `scripts/game/game_session.gd` |
| `MoveResult` | `scripts/game/move_result.gd` |

Contract:

- Initial tray = `generate_three()` (3 pieces)
- Refill **only** when all 3 slots are consumed (not one-for-one)
- Move order: validate → `place` → `clear_completed_lines` → `consume` → maybe refill → Game Over check
- Failed moves mutate nothing (board / tray / refill)
- Game Over = remaining tray pieces exist and **none** are placeable (`PlacementSearch.has_any_placeable_piece`); empty tray is not Game Over (refill runs first)
- Session states: `INVALID` / `ACTIVE` / `GAME_OVER`
- No Score / UI / final board size / production catalog in this phase

## Phase 1-R route-drag match redesign

Normative contracts (docs only in Phase 1-R):

| Doc | Path |
| --- | --- |
| Phase 1-R specification | [`docs/phase1r/README.md`](docs/phase1r/README.md) |

Summary of locked direction:

- DEV board **6×6**, DEV **5** orb types (not production finals)
- **Match-stable** initial board (no opening cascade / score); seedable
- Route drag, **4-dir**, **revisit allowed**; swap on **new cell enter** only; resolve on **release**
- Orthogonal ≥3 match; no diagonal; simultaneous clear; column gravity; top refill; cascade with **finite safety guard**
- Seedable RNG; no input + timer pause during resolve
- Mid-drag timer=0 → stop steps; ≥1 swap forced release→resolve→SESSION_OVER; 0 swaps→SESSION_OVER (**no rollback**)
- First mode: **Score Attack** (DEV default **60s**; 45/60/90 until device compare)
- Provisional **Score formula required before R-E implementation starts**
- `OrbType` = orbs only; obstacles (`ROCK`/`LOCK`/`SLIME`) separate on `PuzzleCell` (ROCK after Gate 1)
- Legacy Block Placement domain kept until **R-F** playable COMPLETE

Roadmap (post–1-R): **R-A** board/fill → **R-B** DragRoute → **R-C** MatchResolver → **R-D** gravity/refill/cascade → **R-E** PuzzleSession/timer/score → **R-F** UI/Android playable → **Gate 1**

**Do not start R-A until Phase 1-R docs PR is accepted.**

## Phase R-A puzzle board foundation

| Type | Path |
| --- | --- |
| `OrbType` | `scripts/puzzle/orb_type.gd` |
| `PuzzleCell` | `scripts/puzzle/puzzle_cell.gd` |
| `PuzzleBoard` | `scripts/puzzle/puzzle_board.gd` |
| `OrbGenerator` | `scripts/puzzle/orb_generator.gd` |
| Notes | [`docs/phase1r/IMPLEMENTATION_NOTES.md`](docs/phase1r/IMPLEMENTATION_NOTES.md) |

- Match-stable initial fill: row-major `y` outer / `x` inner; left-2 / up-2 exclusion; seeded `randi_range`; **empty-board precondition**
- `PuzzleCell.with_orb(invalid)` → `null` (not silent empty)
- Match detection is **not** on `PuzzleBoard` (test-side helper only; MatchResolver = R-C)
- Legacy `scripts/game/*` untouched
- Drag / Match / Gravity / Cascade / Timer / Score / Obstacles / UI: **not** in R-A

## Versions

- Godot **4.7.2** stable (Standard / GDScript)
- OpenJDK **17**
- Compatibility Renderer (`gl_compatibility`)
- Portrait
- Android Gradle Build
- AGP **8.10.1** + Gradle Wrapper **8.11.1** + compileSdk/targetSdk **36** + minSdk **24**
- arm64-v8a
- GUT **9.7.1**
- AdMob plugin `godot-sdk-integrations/godot-admob` **v7.0** + Phase 0-E.1 UMP native patch

## Production baseline (Phase 0-F)

| Piece | Path |
| --- | --- |
| Default main scene | `scenes/main.tscn` + `scripts/main.gd` |
| Shared ads/consent service | `scripts/ads/ads_consent_service.gd` |
| Ad unit config | `scripts/ads/ads_config.gd` |
| Consent gate helpers | `scripts/consent_gate.gd` |
| Phase 0-E regression spike | `scenes/regression/phase0e_ump_spike.tscn` |

### Boot policy

1. After `main._ready()`, production builds `ConsentRequestParameters` with `set_is_real(true)` (no debug geography, no UMP test-device hash) and calls `AdsConsentService.begin_consent_update()` automatically.
2. Duplicate in-flight consent updates are ignored.
3. If a UMP form is required, the service loads/shows it as before.
4. On update success **or** failure, ads follow native `canRequestAds` (SoT) after the update completes.
5. When `auto_request_banner` is enabled (production main), after an allowed decision the service requests a banner **once** — only if production banner unit IDs are configured in `AdsConfig`.
6. Phase 0-F keeps production IDs **empty**, so no banner request is issued yet.

### Production UI

- No **Update Consent** button (auto on launch)
- No **Request Banner** button (auto when allowed + IDs set)
- **Privacy Options** remains when status is `REQUIRED`

### Test ID separation

| ID role | Source | Notes |
| --- | --- | --- |
| AndroidManifest `APPLICATION_ID` | `addons/AdmobPlugin/android_export.cfg` | Required for debug APK/AAB export. Plugin prefers this file over scene Admob node fields when present. Uses Google sample App ID with `is_real=false` for Phase 0 debug builds. |
| Banner **unit** ID for requests | `AdsConfig` (`scripts/ads/ads_config.gd`) | Production constants empty → no request. Google test banner unit is used only when `use_test_ad_units=true` (regression spike). |
| Scene Admob node app/banner fields on production main | Cleared (`""`) | Not required for Manifest App ID (export cfg wins). Not used by `AdsConsentService` banner loads (unit ID comes from `AdsConfig`). |

Google sample App/Banner IDs on the **Admob node** and manual A–E controls stay on the **regression spike only**. Do not describe Manifest App ID as “regression only” — debug export still needs `android_export.cfg`.

## Phase 0-E regression spike

Keep using the regression scene for future AdMob/UMP SDK re-checks (scenarios A–E):

`scenes/regression/phase0e_ump_spike.tscn`

It still includes debug geography, runtime-only UMP test-device hash, and manual Update Consent / Request Banner / Reset / Privacy Options buttons.

Native patch notes: `tooling/admob/native-patch/README.md`  
API audit: `tooling/admob/UMP_API_AUDIT.md`

## GUT

```bash
./tooling/gut/run_tests.sh
```

Tests: `tests/test_phase0b.gd`, `tests/test_phase0d.gd`, `tests/test_phase0e.gd`, `tests/test_phase0f.gd`, `tests/test_phase1a.gd`, `tests/test_phase1b.gd`, `tests/test_phase1c.gd`, `tests/test_phase_ra.gd`.

## Debug APK / AAB

```bash
godot --headless --path . --import
godot --headless --path . --install-android-build-template
./tooling/android-gradle/apply_overlay.sh
godot --headless --path . --export-debug Android build/android/phase0f-debug.apk
godot --headless --path . --export-debug "Android AAB" build/android/phase0c-debug.aab
```

Do not commit APK / AAB / keystores / production AdMob IDs / UMP device hashes.

### Phase 1-A / 1-B / 1-C AAB re-export

AAB re-export was **skipped** for Phase 1-A through 1-C closeout for these reasons:

- No Android Gradle configuration changes
- No `export_presets.cfg` changes
- No AdMob / native plugin changes
- Changes are GDScript game-domain only
- Debug APK export **PASS**
- Under phase completion criteria, AAB re-export was judged unnecessary
