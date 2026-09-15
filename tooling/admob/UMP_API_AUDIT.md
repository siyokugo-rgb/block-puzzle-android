# UMP API audit — godot-admob v7.0 + Phase 0-E.1 native patch

Audited against:

- Upstream tag `v7.0` / SHA `4b4ddceab0be81f0dcb12a6313038dba6cf9eacf`
- Vendored GDScript: `addons/AdmobPlugin/Admob.gd`
- Patched native AAR rebuilt via `tooling/admob/native-patch/`

## API matrix (after Phase 0-E.1 patch)

| Capability | GDScript | Native AAR | Notes |
| --- | --- | --- | --- |
| `update_consent_info` | YES | YES | stock v7.0 |
| `get_consent_status` | YES | YES | stock v7.0 |
| `is_consent_form_available` | YES | YES | stock v7.0 |
| `load_consent_form` / `show_consent_form` | YES | YES | stock v7.0 |
| `reset_consent_info` | YES | YES | stock v7.0 |
| `can_request_ads` | YES | YES | **added in Phase 0-E.1** |
| `get_privacy_options_requirement_status` | YES | YES | **added in Phase 0-E.1** |
| `show_privacy_options_form` | YES | YES | **added in Phase 0-E.1** |
| `privacy_options_form_dismissed` | YES | YES | **added in Phase 0-E.1** |

## Gate policy

- Pre-update: ads blocked (`ConsentGate.BLOCKED_PRE_UPDATE`)
- After update success **or** failure: call native `can_request_ads()`
- `true` → allow Test Banner request
- `false` → block
- Consent status remains diagnostic only (not final ads authority)
- Duplicate banner requests are prevented until reset / failed load retry

## Privacy options

- Spike exposes a test button enabled only when status == `REQUIRED`
- `UNKNOWN` does not auto-enable ads or privacy UI
- Production Settings screen is out of scope for Phase 0-E
