# Phase 0-D build verification (Cloud Agent)

Date: 2026-09-14

## Export

- APK: `build/android/phase0d-debug.apk` (~82M, gitignored) — **SUCCESS**
- AAB regression: `build/android/phase0c-debug.aab` (~32M, gitignored) — **SUCCESS**
- Gradle/AGP: overlay AGP 8.10.1, compileSdk/targetSdk 36, minSdk 24
- Export plugin loaded `android_export.cfg` with Google sample App ID (`is_real=false`)
- Android deps logged: `play-services-ads:24.9.0`, `appcompat:1.7.1`, `lifecycle-process:2.8.3`

## Manifest (aapt dump of APK)

- `com.google.android.gms.ads.APPLICATION_ID` = `ca-app-pub-3940256099942544~3347511713`
- `org.godotengine.plugin.v2.AdmobPlugin` → `org.godotengine.plugin.admob.AdmobPlugin`
- `com.google.android.gms.ads.AdActivity` present
- Permissions: INTERNET, ACCESS_NETWORK_STATE, AD_ID (+ GMS AD_ID / AdServices)

## Device (this environment)

- `adb devices`: empty (no Xperia attached)
- Runtime SDK init / banner load / banner display: **NOT verified in Cloud Agent**
- User must install `phase0d-debug.apk` on Xperia to close Phase 0-D to COMPLETE

## GUT

- 4/4 PASS (`test_phase0b` + `test_phase0d`)
