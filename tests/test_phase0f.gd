extends GutTest

## Phase 0-F: production baseline separation + ads/consent guards.


func test_phase0f_ads_config_blocks_production_without_ids() -> void:
	assert_false(AdsConfig.production_ids_configured())
	assert_eq(AdsConfig.resolve_banner_unit_id(false), "")
	assert_false(AdsConfig.can_request_banner(false))
	assert_true(AdsConfig.can_request_banner(true))
	assert_eq(
		AdsConfig.resolve_banner_unit_id(true),
		"ca-app-pub-3940256099942544/9214589741"
	)


func test_phase0f_consent_before_ads_blocks_request() -> void:
	assert_eq(
		ConsentGate.evaluate(false, true),
		ConsentGate.AdsDecision.BLOCKED_PRE_UPDATE
	)
	assert_false(ConsentGate.is_ads_allowed(ConsentGate.evaluate(false, true)))
	assert_false(ConsentGate.is_ads_allowed(ConsentGate.evaluate(true, false)))
	assert_true(ConsentGate.is_ads_allowed(ConsentGate.evaluate(true, true)))


func test_phase0f_allowed_to_blocked_requires_cleanup() -> void:
	assert_true(ConsentGate.should_cleanup_on_decision_change(true, false))
	assert_true(ConsentGate.should_cleanup_active_banner(false, true))
	assert_true(ConsentGate.should_discard_loaded_banner(false))
	assert_false(ConsentGate.should_discard_loaded_banner(true))


func test_phase0f_production_main_has_no_debug_ump_ui() -> void:
	var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	assert_true(main_src.find("DebugGeography") < 0)
	assert_true(main_src.find("DeviceHashEdit") < 0)
	assert_true(main_src.find("GeoOption") < 0)
	assert_true(main_src.find("AdsConsentService") >= 0)
	assert_true(main_src.find("use_test_ad_units = false") >= 0)

	var main_scene := FileAccess.get_file_as_string("res://scenes/main.tscn")
	assert_true(main_scene.find("GeoOption") < 0)
	assert_true(main_scene.find("DeviceHashEdit") < 0)
	assert_true(main_scene.find("AdsConsentService") >= 0)
	assert_true(main_scene.find("use_test_ad_units = false") >= 0)


func test_phase0f_regression_spike_scene_is_separate() -> void:
	assert_true(FileAccess.file_exists("res://scenes/regression/phase0e_ump_spike.tscn"))
	assert_true(FileAccess.file_exists("res://scripts/regression/phase0e_ump_spike.gd"))
	var project := FileAccess.get_file_as_string("res://project.godot")
	assert_true(project.find('run/main_scene="res://scenes/main.tscn"') >= 0)
	assert_true(project.find("phase0e_ump_spike") < 0)


func test_phase0f_service_exposes_gate_and_cleanup_apis() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ads/ads_consent_service.gd")
	assert_true(src.find("func begin_consent_update(") >= 0)
	assert_true(src.find("func request_banner_if_allowed(") >= 0)
	assert_true(src.find("func show_privacy_options_form(") >= 0)
	assert_true(src.find("func _remove_active_banner_if_any(") >= 0)
	assert_true(src.find("duplicate banner request ignored") >= 0)
	assert_true(src.find("delayed load while blocked") >= 0)
	assert_true(src.find("privacy options dismissed") >= 0)
