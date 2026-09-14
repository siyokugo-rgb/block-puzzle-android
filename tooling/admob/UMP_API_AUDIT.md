# UMP API audit — godot-admob v7.0 (Phase 0-E)

Audited against vendored sources:

- GDScript: `addons/AdmobPlugin/Admob.gd` (+ models)
- Native AAR: `addons/AdmobPlugin/bin/debug/AdmobPlugin-debug.aar`
  (`javap` on `org.godotengine.plugin.admob.AdmobPlugin`)

Date: 2026-09-14  
Plugin tag: **v7.0**  
Godot: **4.7.2**

## API matrix

| Capability | GDScript wrapper | Native singleton / AAR | Notes |
| --- | --- | --- | --- |
| `update_consent_info` | **YES** | **YES** | `ConsentRequestParameters` supports `debug_geography` + `test_device_hashed_ids` |
| `get_consent_status` | **YES** | **YES** | Returns string mapped to `UserConsent.Status` |
| `is_consent_form_available` | **YES** | **YES** | |
| `load_consent_form` | **YES** | **YES** | |
| `show_consent_form` | **YES** | **YES** | |
| `reset_consent_info` | **YES** | **YES** | |
| `canRequestAds` equivalent | **NO** | **NO** | Not in wrapper; not in public AAR methods/signals |
| Privacy options requirement status | **NO** | **NO** | Not exposed |
| Privacy options form show | **NO** | **NO** | Not exposed |

Related signals present: `consent_info_updated`, `consent_info_update_failed`, `consent_form_loaded`, `consent_form_failed_to_load`, `consent_form_dismissed`.

## Google current UMP expectations vs plugin

Google’s recommended Mobile Ads + UMP flow expects:

1. Consent info update
2. Form when required
3. **`ConsentInformation.canRequestAds()`** before requesting ads (including previous-session consent on update failure)
4. **Privacy options** entry point when `getPrivacyOptionsRequirementStatus() == REQUIRED`

v7.0 exposes (1)(2) and consent status / form APIs, but **does not expose (3) or (4)**.

## Spike policy (this repo)

- Do **not** invent / call missing APIs.
- On consent **update failure**: **fail-closed** (ads blocked). Without `canRequestAds`, previous-session consent cannot be safely trusted.
- On successful update: allow ads only for `NOT_REQUIRED` or `OBTAINED` from live `get_consent_status()` (never a local authoritative cache).
- Treat missing `canRequestAds` + privacy options as **High / FIX FIRST** for production UMP compliance.

## Demo reference

Upstream demo (`demo/Main.gd`) initializes Mobile Ads first, then branches on `UserConsent.Status` and loads ads for `NOT_REQUIRED` / `OBTAINED`. It also does **not** call `canRequestAds` or privacy-options APIs.
