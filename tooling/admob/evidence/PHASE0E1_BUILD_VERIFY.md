# Phase 0-E.1 build verification (Cloud Agent)

Date: 2026-09-15 (Scenario A FIX FIRST rebuild)

- Upstream: godot-sdk-integrations/godot-admob `v7.0` / `4b4ddceab0be81f0dcb12a6313038dba6cf9eacf`
- Native patch applied + AAR rebuilt via `tooling/admob/native-patch/`
- APK UMP: `user-messaging-platform` 3.2.0 / `play-services-ads` 24.9.0
- Debug AAR SHA-256: `d0489086af10646029655c368faaf6c538551bb0b0defd49c0978152e7448a91`
- Release AAR SHA-256: `97af716412b28596961da8a333a703327ec4d0e53bb2fa3cdcef44921555df77`
- Public methods present: `can_request_ads`, `get_privacy_options_requirement_status`, `show_privacy_options_form`, `get_ump_consent_snapshot`
- Wrapper: removed Android `has_method` fail-closed gate on new UMP APIs
- Debug geo: fixed `keys()[enum_value]` mislabel (`OTHER` vs `REGULATED_US_STATE`)
- Fail-closed ads gate retained (`canRequestAds=false` still blocks banner)
- Phase 0-E overall: **FIX FIRST** until Xperia Scenario A re-verified

## Cloud regression (Scenario A fix)

- GUT: **13/13 PASS** (0-B / 0-D / 0-E)
- APK: `build/android/phase0e-debug.apk` SUCCESS
  - SHA-256: `0f9a05076ac5dabbe6a86fabd6ecb065483f5e0f48feeeb8658a83f5fbefc4bd`
- AAB: `build/android/phase0c-debug.aab` SUCCESS (regression)
- Dex contains: `can_request_ads`, `get_ump_consent_snapshot`

