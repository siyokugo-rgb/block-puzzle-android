# block-puzzle-android

Phase 0 production baseline for Godot 4.7.2 Android + GUT + AdMob/UMP.

Game systems (Board / Piece / Score / Adaptive Difficulty / etc.) are **not** implemented yet.

## Status

| Phase | Result |
| --- | --- |
| 0-A Android APK | COMPLETE |
| 0-B GUT | COMPLETE |
| 0-C AAB | COMPLETE |
| 0-D AdMob test banner | COMPLETE |
| 0-E UMP consent gate | COMPLETE — Android reference-device scenarios A–E PASS |
| 0-F Production baseline closeout | **COMPLETE** |

Xperia was the **reference test device** for Phase 0-E. The implementation itself is **Android-generic** (no Sony/Xperia-only APIs or branches).

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

Tests: `tests/test_phase0b.gd`, `tests/test_phase0d.gd`, `tests/test_phase0e.gd`, `tests/test_phase0f.gd`.

## Debug APK / AAB

```bash
godot --headless --path . --import
godot --headless --path . --install-android-build-template
./tooling/android-gradle/apply_overlay.sh
godot --headless --path . --export-debug Android build/android/phase0f-debug.apk
godot --headless --path . --export-debug "Android AAB" build/android/phase0c-debug.aab
```

Do not commit APK / AAB / keystores / production AdMob IDs / UMP device hashes.
