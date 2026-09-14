extends GutTest

## Phase 0-D: guardrails for Google test IDs only (no production AdMob IDs).

const SAMPLE_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const ANCHORED_ADAPTIVE_BANNER_TEST_UNIT_ID := "ca-app-pub-3940256099942544/9214589741"


func test_phase0d_google_sample_app_id_only() -> void:
	assert_eq(SAMPLE_APP_ID, "ca-app-pub-3940256099942544~3347511713")
	assert_true(SAMPLE_APP_ID.begins_with("ca-app-pub-3940256099942544~"))


func test_phase0d_anchored_adaptive_banner_test_unit() -> void:
	assert_eq(ANCHORED_ADAPTIVE_BANNER_TEST_UNIT_ID, "ca-app-pub-3940256099942544/9214589741")


func test_phase0d_admob_plugin_files_present() -> void:
	assert_true(FileAccess.file_exists("res://addons/AdmobPlugin/plugin.cfg"))
	assert_true(FileAccess.file_exists("res://addons/AdmobPlugin/bin/debug/AdmobPlugin-debug.aar"))
	assert_true(FileAccess.file_exists("res://addons/AdmobPlugin/bin/release/AdmobPlugin-release.aar"))
	assert_true(FileAccess.file_exists("res://addons/AdmobPlugin/android_export.cfg"))
