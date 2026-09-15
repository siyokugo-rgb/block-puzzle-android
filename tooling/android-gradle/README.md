# Android Gradle AGP overlay (Phase 0-A.1)

Godot 4.7.2 stable の Android source template（`android_source.zip`）は
`config.gradle` で `androidGradlePlugin: '8.6.1'` を定義する。

AGP 8.6.1 は Android 公式上 API 35 までの対応であり、compileSdk/targetSdk 36
との組み合わせを Phase 0-A の正式完了条件にできない。

## 変更内容

| 項目 | 値 |
| --- | --- |
| AGP | 8.10.1（API 36 対応が公式リリースノートで明示、必要 Gradle 8.11.1） |
| Gradle Wrapper | 8.11.1（Godot 4.7.2 template 既定のまま維持） |
| compileSdk | 36 |
| targetSdk | 36 |
| minSdk | 24 |

## なぜ `android/build/` を Git 管理しないか

`android/build/` は Godot が Export Template から展開する生成物であり、
リポジトリでは ignore している（約数百 MB、再生成可能）。

`gradle_build/android_source_template` に差し替え zip を渡す方法もあるが、
Godot 同梱 `android_source.zip` は約 205MB のため Git 永続化には不適。

## 最小の永続化方法（採用候補）

1. Godot で Android Build Template をインストール（`android/build/` 生成）
2. 本ディレクトリの `apply_overlay.sh` を実行し、`config.gradle` だけを上書き
3. その後に Debug export / Gradle build

これにより Cloud Agent 再作成後も、AGP 8.10.1 ピンを再現できる。
`android/build/` 全体は Git に入れない。
