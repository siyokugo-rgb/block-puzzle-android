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
| 0-E UMP consent gate | **COMPLETE** — Android reference-device scenarios A–E PASS |
| 0-F Production baseline closeout | in progress on this branch |

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

Rules:

- Production main has **no** debug geography UI and **no** UMP test-device hash field
- `AdsConsentService.use_test_ad_units = false` on the production scene
- Production AdMob IDs are **empty** → no banner request until configured
- Google test App/Banner IDs remain available only for the regression spike
- Ads are blocked before consent update completes and when `canRequestAds` is false
- Allowed → blocked removes any active banner (`remove_banner_ad`)

## Phase 0-E regression spike

Keep using the regression scene for future AdMob/UMP SDK re-checks (scenarios A–E):

`scenes/regression/phase0e_ump_spike.tscn`

It still includes debug geography controls and a runtime-only UMP test-device hash field (never committed / never persisted).

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
