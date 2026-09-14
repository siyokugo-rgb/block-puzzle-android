# Fallback comparison only (Phase 0-D)

Poing Studios AdMob is **not installed** in this branch. Recorded only if
`godot-sdk-integrations/godot-admob` v7.0 fails initialization / banner load.

| Field | Value |
| --- | --- |
| Repository | https://github.com/poingstudios/godot-admob-plugin |
| Latest release researched | **v5.1.0** (2026-09-13) |
| Godot note (release body) | minimum export 4.4+; **testing through 4.7.2** |
| Android compileSdk (release note) | 35 (our spike targets 36 via AGP overlay — extra risk) |
| Android companion | https://github.com/poingstudios/godot-admob-android |
| License | MIT (upstream) |

## Decision rule

1. Stay on godot-sdk-integrations v7.0 unless device evidence shows init/load failure.
2. On failure: save logcat, compare to issue #124, report FIX FIRST / BLOCKED.
3. Do **not** silently switch plugins in Phase 0-D.
