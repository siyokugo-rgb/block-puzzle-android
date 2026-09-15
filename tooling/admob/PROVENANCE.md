# AdMob plugin provenance (Phase 0-D)

## Selected plugin (first candidate)

| Field | Value |
| --- | --- |
| Repository | https://github.com/godot-sdk-integrations/godot-admob |
| Tag / version | **v7.0** (latest stable as of 2026-09-14 research) |
| Release URL | https://github.com/godot-sdk-integrations/godot-admob/releases/tag/v7.0 |
| Published | 2026-05-27 |
| Asset used | `AdmobPlugin-Android-v7.0.zip` |
| Asset SHA-256 | `ce38b75aeb4bb870fda8b74e1513d807696d8485d237c263b7b7a9613493aee8` |
| Debug AAR SHA-256 | `2bcbe8a39720f8898464fa83c686d8daa96594532b3646e5fbb5ce09ee8e9314` |
| Release AAR SHA-256 | `85ff6247e6f78f15aa4e20c26bd7c8db7d385e3923e4e9174e7786d7ea75be07` |
| Installed path | `res://addons/AdmobPlugin` (+ `res://addons/GMPShared`) |
| License | MIT (see `tooling/admob/LICENSE`) |
| Author | Cengiz / Godot Engine Community SDK Integrations |
| Godot compatibility (upstream) | Release notes: **tested against / supports Godot 4.7** |
| Project Godot | **4.7.2.stable** |

## Pinned Android dependencies (from plugin source `AdmobPlugin.gd`)

Do not float these for Phase 0-D:

- `com.google.android.gms:play-services-ads:24.9.0`
- `androidx.appcompat:appcompat:1.7.1`
- `androidx.lifecycle:lifecycle-process:2.8.3`

## Known issues checked before install

| Issue | Status | Relevance |
| --- | --- | --- |
| [#124](https://github.com/godot-sdk-integrations/godot-admob/issues/124) “Version 7.0 not initializing on godot 4.7” | **Open** | Reporter: AAR not found by editor; workaround copy AAR into `android/build/bin`. Must verify on device; do not assume “supports 4.7” means init works. |
| [#122](https://github.com/godot-sdk-integrations/godot-admob/issues/122) missing AAR / Godot 4.6.2 | Closed context | v7.0 targets Godot **4.7+**; missing `addons/AdmobPlugin/bin/debug/AdmobPlugin-debug.aar` breaks Gradle metadata. We vendor both debug/release AARs. |

## Google test IDs only (Phase 0-D)

| Purpose | ID |
| --- | --- |
| Sample App ID | `ca-app-pub-3940256099942544~3347511713` |
| Anchored Adaptive Banner test unit | `ca-app-pub-3940256099942544/9214589741` |

Production AdMob App / Ad Unit IDs are **forbidden** in this spike.

## Fallback research only (not installed)

See `tooling/admob/FALLBACK_COMPARISON.md` for Poing Studios comparison material.
If v7.0 init fails on device, do **not** auto-migrate; stop and decide next.
