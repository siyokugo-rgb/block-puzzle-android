# Native UMP patch for godot-admob v7.0 (Phase 0-E.1)

## Purpose

Minimally extend **godot-sdk-integrations/godot-admob v7.0** Android plugin so Godot can call Google UMP APIs required by the current Mobile Ads consent flow:

- `ConsentInformation.canRequestAds()`
- `ConsentInformation.getPrivacyOptionsRequirementStatus()`
- `UserMessagingPlatform.showPrivacyOptionsForm()`

Plus dismiss signal:

- `privacy_options_form_dismissed(Dictionary)` (same `FormError` dictionary shape as `consent_form_dismissed`)

This is **not** a full plugin fork or plugin swap.

## Source of truth (pinned)

| Field | Value |
| --- | --- |
| Upstream | https://github.com/godot-sdk-integrations/godot-admob |
| Tag | `v7.0` |
| Commit SHA | `4b4ddceab0be81f0dcb12a6313038dba6cf9eacf` |
| Patch file | `godot-admob-v7.0-ump-current.patch` |
| Changed native file | `android/src/main/java/org/godotengine/plugin/admob/AdmobPlugin.java` |

Do **not** retarget `main` / other tags without a new Phase decision.

## Build (reproducible)

Requirements:

- JDK 17
- Android SDK (`ANDROID_HOME` / `ANDROID_SDK_ROOT`)
- network access once (Godot Android library download)

```bash
export ANDROID_HOME=/path/to/android-sdk
export ANDROID_SDK_ROOT="$ANDROID_HOME"
./tooling/admob/native-patch/build_android_plugin.sh
```

The script:

1. Clones upstream at the pinned SHA into a temp workdir (or reuses `ADMOB_SRC_DIR`)
2. Applies `godot-admob-v7.0-ump-current.patch`
3. Builds debug + release Android AARs via upstream `./script/build.sh -a -- ...`
4. Copies AARs into `addons/AdmobPlugin/bin/{debug,release}/`
5. Prints SHA-256 digests

## Expected AAR SHA-256 (this workspace build)

Recorded after successful Cloud Agent rebuild on 2026-09-15:

| Artifact | SHA-256 |
| --- | --- |
| `addons/AdmobPlugin/bin/debug/AdmobPlugin-debug.aar` | `c36762992d6ddc8a6a16461f650633f4b48e36f8bcdc40680f97766d5357b12c` |
| `addons/AdmobPlugin/bin/release/AdmobPlugin-release.aar` | `a975afc114fba1e2dbe8cc4681f77eac1fcd95eda8b0bda693a047e0601e03d9` |

If digests differ after a clean rebuild on the same SHA+patch, stop and investigate (toolchain drift / unclean tree).

## Added native surface

Methods (`@UsedByGodot`):

- `boolean can_request_ads()`
- `String get_privacy_options_requirement_status()` → `UNKNOWN` / `NOT_REQUIRED` / `REQUIRED`
- `void show_privacy_options_form()`

Signal:

- `privacy_options_form_dismissed` (`Dictionary` FormError payload; empty message/code=0 on normal dismiss)

## GDScript wrappers (repo)

In `addons/AdmobPlugin/`:

- `Admob.can_request_ads() -> bool`
- `Admob.get_privacy_options_requirement_status() -> PrivacyOptionsRequirementStatus`
- `Admob.show_privacy_options_form()`
- signal `privacy_options_form_dismissed(error_data: FormError)`

## Security

- No secrets / keystores / production AdMob IDs in this folder
- Do not vendor the full upstream tree into this repository
