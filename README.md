# block-puzzle-android

Phase 0-A: Godot 4.7.2 stable + GDScript + Compatibility Renderer の Android Gradle Build 成立性確認。

ゲーム本体（Board / Piece / Score 等）は未実装。

## 基準バージョン

- Godot 4.7.2 stable（Standard / GDScript）
- OpenJDK 17
- Compatibility Renderer（`gl_compatibility`）
- Portrait
- Android Gradle Build
- Phase 0-A.1: AGP **8.10.1** + Gradle Wrapper **8.11.1** + compileSdk/targetSdk **36** + minSdk **24**

## Debug APK（環境が揃っている場合）

```bash
godot --headless --path . --import
godot --headless --path . --install-android-build-template
./tooling/android-gradle/apply_overlay.sh   # AGP 8.10.1 を android/build/config.gradle へ適用
godot --headless --path . --export-debug Android build/android/phase0a-debug.apk
```

`android/build/` は Godot 生成物のため Git 管理外。AGP ピンは `tooling/android-gradle/` の overlay で再現する（詳細は同ディレクトリ README）。

Editor Settings に Java SDK Path（JDK 17）と Android SDK Path が必要。keystore / password / token はリポジトリに置かない。
