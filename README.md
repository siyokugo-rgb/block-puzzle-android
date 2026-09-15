# block-puzzle-android

Phase 0 production baseline for Godot 4.7.2 Android + GUT + AdMob/UMP.

Phase 1-A adds a UI-free block-placement **game core** (Board / Piece / place / line clear).
Phase 1-B adds **piece supply** (catalog / seeded generator / 3-slot tray / placement search).
Phase 1-C adds **GameSession** (move transaction / 3-clear refill / Game Over).
Phase 1-D adds a **minimal playable vertical slice** (board/tray render, touch drag, place via GameSession).
Score, Adaptive Difficulty, production catalogs, and final board size are **not** implemented yet.

## Status

| Phase | Result |
| --- | --- |
| 0-A Android APK | COMPLETE |
| 0-B GUT | COMPLETE |
| 0-C AAB | COMPLETE |
| 0-D AdMob test banner | COMPLETE |
| 0-E UMP consent gate | COMPLETE — Android reference-device scenarios A–E PASS |
| 0-F Production baseline closeout | COMPLETE |
| 1-A Block placement game core | COMPLETE |
| 1-B Piece supply / tray / placement search | COMPLETE |
| 1-C Game session / tray lifecycle / Game Over | COMPLETE |
| 1-D Minimal playable vertical slice | in progress (Draft PR) |

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

## Phase 1-D playable slice

| Type | Path |
| --- | --- |
| Game view scene | `scenes/game/game.tscn` |
| `GameView` | `scripts/game_ui/game_view.gd` |
| `BoardView` / `PieceView` | `scripts/game_ui/board_view.gd`, `piece_view.gd` |
| `BoardCoords` | `scripts/game_ui/board_coords.gd` |
| `PlacementDrag` | `scripts/game_ui/placement_drag.gd` |
| Dev play config | `scripts/game_ui/dev_play_config.gd` |

Contract:

- `GameSession` remains Source of Truth; UI does not own board occupancy / refill / Game Over
- Placement preview uses read-only `GameSession.can_place_from_slot` (no mutation)
- Commit uses `place_from_slot` only on pointer release; `MoveResult.success` is SoT
- Pixel↔cell conversion is centralized in `BoardCoords` (Session never receives pixels)
- Drag preview is offset upward by `DevPlayConfig.DEV_DRAG_FINGER_OFFSET_CELLS` × cell size
- **Development** board size (`DEV_BOARD_WIDTH` / `DEV_BOARD_HEIGHT`) and **development catalog** only — not production / final
- Score / restart / clear animation / production AdMob IDs are out of scope

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

Tests: `tests/test_phase0b.gd`, `tests/test_phase0d.gd`, `tests/test_phase0e.gd`, `tests/test_phase0f.gd`, `tests/test_phase1a.gd`, `tests/test_phase1b.gd`, `tests/test_phase1c.gd`, `tests/test_phase1d.gd`.

## Debug APK / AAB

```bash
godot --headless --path . --import
godot --headless --path . --install-android-build-template
./tooling/android-gradle/apply_overlay.sh
godot --headless --path . --export-debug Android build/android/phase0f-debug.apk
godot --headless --path . --export-debug "Android AAB" build/android/phase0c-debug.aab
```

Do not commit APK / AAB / keystores / production AdMob IDs / UMP device hashes.

### Phase 1-A / 1-B / 1-C / 1-D AAB re-export

AAB re-export was **skipped** for Phase 1-A through 1-D closeout for these reasons:

- No Android Gradle configuration changes
- No `export_presets.cfg` changes
- No AdMob / native plugin changes
- Changes are GDScript / scene only (domain + UI slice)
- Debug APK export **PASS** (when built for the phase)
- Under phase completion criteria, AAB re-export was judged unnecessary
