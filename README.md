# block-puzzle-android

Phase 0-A: Godot 4.7.2 stable + GDScript + Compatibility Renderer の Android Gradle Build 成立性確認。

ゲーム本体（Board / Piece / Score 等）は未実装。

## 基準バージョン

- Godot 4.7.2 stable（Standard / GDScript）
- OpenJDK 17
- Compatibility Renderer（`gl_compatibility`）
- Portrait
- Android Gradle Build

## Debug APK（環境が揃っている場合）

```bash
godot --headless --path . --import
godot --headless --path . --install-android-build-template --export-debug Android build/android/phase0a-debug.apk
```

Editor Settings に Java SDK Path（JDK 17）と Android SDK Path が必要。keystore / password / token はリポジトリに置かない。
