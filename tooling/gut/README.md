# GUT runner (Phase 0-B)

## Headless (CI / Cloud Agent)

```bash
./tooling/gut/run_tests.sh
```

Requires Godot 4.7.2 on `PATH` (override with `GODOT_BIN`).

Config: `res://.gutconfig.json` (project-local, not user home).

## Editor

1. Project → Project Settings → Plugins → enable **Gut** (already enabled in `project.godot`).
2. Open the GUT bottom panel.
3. If no directories are listed, add `res://tests/`.
4. Run All — expect `test_one_plus_one_equals_two` to pass.

Editor panel settings may live under Godot `user://` on first use; headless always uses `.gutconfig.json`.

See `PROVENANCE.md` for upstream tag and compatibility evidence.
