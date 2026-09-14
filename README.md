# block-puzzle-android

Phase 0 spike for Godot 4.7.2 Android + automated GDScript tests.

Game systems (Board / Piece / Score / Ads / etc.) are **not** implemented yet.

## Versions

- Godot **4.7.2** stable (Standard / GDScript)
- OpenJDK **17**
- Compatibility Renderer (`gl_compatibility`)
- Portrait
- Android Gradle Build
- Phase 0-A.1: AGP **8.10.1** + Gradle Wrapper **8.11.1** + compileSdk/targetSdk **36** + minSdk **24**
- Phase 0-B: GUT **9.7.1** (`v9.7.1` / Godot 4.7.x)

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

Minimal test: `tests/test_phase0b.gd` (`1 + 1 == 2`).

## Debug APK (Phase 0-A)

```bash
godot --headless --path . --import
godot --headless --path . --install-android-build-template
./tooling/android-gradle/apply_overlay.sh
godot --headless --path . --export-debug Android build/android/phase0a-debug.apk
```

`android/build/` is generated and gitignored. AGP pin lives in `tooling/android-gradle/`.  
Do not commit keystore / password / token.
