# Phase 0-E.1 build verification (Cloud Agent)

Date: 2026-09-15

- Upstream: godot-sdk-integrations/godot-admob `v7.0` / `4b4ddceab0be81f0dcb12a6313038dba6cf9eacf`
- Native patch applied + AAR rebuilt via `tooling/admob/native-patch/`
- Debug AAR SHA-256: `c36762992d6ddc8a6a16461f650633f4b48e36f8bcdc40680f97766d5357b12c`
- Release AAR SHA-256: `a975afc114fba1e2dbe8cc4681f77eac1fcd95eda8b0bda693a047e0601e03d9`
- Public methods present: `can_request_ads`, `get_privacy_options_requirement_status`, `show_privacy_options_form`
- GUT: 12/12 PASS
- APK: `build/android/phase0e-debug.apk` SUCCESS
- AAB regression: SUCCESS
- Xperia runtime: not verified in this environment
- Phase 0-E overall: still **FIX FIRST** (device scenarios pending; not COMPLETE)
