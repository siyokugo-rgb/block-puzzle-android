# block-puzzle-android

Phase 0 spike for Godot 4.7.2 Android + automated GDScript tests + AdMob test banner + UMP consent gate.

Game systems (Board / Piece / Score / production Ads / etc.) are **not** implemented yet.

## Versions

- Godot **4.7.2** stable (Standard / GDScript)
- OpenJDK **17**
- Compatibility Renderer (`gl_compatibility`)
- Portrait
- Android Gradle Build
- Phase 0-A.1: AGP **8.10.1** + Gradle Wrapper **8.11.1** + compileSdk/targetSdk **36** + minSdk **24**
- Phase 0-B: GUT **9.7.1** (`v9.7.1` / Godot 4.7.x)
- Phase 0-C: Android App Bundle (`.aab`) export
- Phase 0-D: AdMob Test Banner via `godot-sdk-integrations/godot-admob` **v7.0** (Google test IDs only)
- Phase 0-E: UMP consent flow / ads-request gate spike (fail-closed; see API audit)

## Phase 0-E: UMP consent gate (Technical Spike)

API audit: `tooling/admob/UMP_API_AUDIT.md`  
Native patch reproducibility: `tooling/admob/native-patch/README.md`

- Consent update / status / form load-show / reset: available in v7.0
- Phase 0-E.1 patch adds: `can_request_ads`, privacy-options status/form + dismiss signal
- Ads requested only when native `canRequestAds()` is true after an update attempt completes
- `SPIKE_AUTO_START_ADS=false`
- UMP test device hash: runtime LineEdit only — never committed
- Google test App ID / Banner ID only
- Phase 0-E overall remains **FIX FIRST / not COMPLETE** until Xperia verification

## Phase 0-D: AdMob Test Banner (Technical Spike)

Provenance: `tooling/admob/PROVENANCE.md`  
Fallback comparison only: `tooling/admob/FALLBACK_COMPARISON.md`

- Sample App ID: `ca-app-pub-3940256099942544~3347511713`
- Anchored Adaptive Banner test unit: `ca-app-pub-3940256099942544/9214589741`
- Production AdMob IDs are forbidden
- Xperia runtime COMPLETE on Phase 0-D; Phase 0-E owns consent gate.

```bash
godot --headless --path . --import
godot --headless --path . --install-android-build-template
./tooling/android-gradle/apply_overlay.sh
godot --headless --path . --export-debug Android build/android/phase0d-debug.apk
```

Known upstream issue: [#124](https://github.com/godot-sdk-integrations/godot-admob/issues/124) (v7.0 init on Godot 4.7). Device verification required.

## Phase 0-B: GUT headless tests

Provenance: `tooling/gut/PROVENANCE.md`  
Upstream: https://github.com/bitwes/Gut/releases/tag/v9.7.1  
Compatibility: upstream README lists GUT 9.7.1 for Godot **4.7.x**.

```bash
# requires Godot 4.7.2 on PATH (or set GODOT_BIN)
./tooling/gut/run_tests.sh
```

Equivalent:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit -glog=1
```

Exit code: `0` = all pass, non-zero = failure.

Editor: enable plugin `Gut` (already in `project.godot`), open GUT panel, Run.

Minimal tests: `tests/test_phase0b.gd`, `tests/test_phase0d.gd`, `tests/test_phase0e.gd`.

## Debug AAB (Phase 0-C)

```bash
godot --headless --path . --import
godot --headless --path . --install-android-build-template
./tooling/android-gradle/apply_overlay.sh
godot --headless --path . --export-debug "Android AAB" build/android/phase0c-debug.aab
```

Uses export preset `Android AAB` (`gradle_build/export_format=1`).  
Signing for this spike: Godot/Gradle **debug** keystore only (not a Play upload key).  
Do not commit `.aab` / keystore / passwords.

## Debug APK (Phase 0-A / 0-D)

```bash
godot --headless --path . --import
godot --headless --path . --install-android-build-template
./tooling/android-gradle/apply_overlay.sh
godot --headless --path . --export-debug Android build/android/phase0e-debug.apk
```

`android/build/` is generated and gitignored. AGP pin lives in `tooling/android-gradle/`.  
Do not commit keystore / password / token / APK / AAB / production AdMob IDs / UMP device hashes.
