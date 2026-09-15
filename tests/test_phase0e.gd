extends GutTest

## Phase 0-E.1: canRequestAds-backed fail-closed gate + privacy status model.


func test_phase0e_initial_decision_blocks_before_update() -> void:
	var decision := ConsentGate.initial_decision()
	assert_eq(decision, ConsentGate.AdsDecision.BLOCKED_PRE_UPDATE)
	assert_false(ConsentGate.is_ads_allowed(decision))
	assert_eq(
		ConsentGate.evaluate(false, true),
		ConsentGate.AdsDecision.BLOCKED_PRE_UPDATE
	)


func test_phase0e_can_request_ads_true_allows_after_update() -> void:
	var decision := ConsentGate.evaluate(true, true)
	assert_eq(decision, ConsentGate.AdsDecision.ALLOWED_CAN_REQUEST_ADS)
	assert_true(ConsentGate.is_ads_allowed(decision))


func test_phase0e_can_request_ads_false_blocks_after_update_success_or_failure() -> void:
	var decision := ConsentGate.evaluate(true, false)
	assert_eq(decision, ConsentGate.AdsDecision.BLOCKED_CANNOT_REQUEST_ADS)
	assert_false(ConsentGate.is_ads_allowed(decision))


func test_phase0e_privacy_options_status_model() -> void:
	assert_eq(
		PrivacyOptionsRequirementStatus.new("REQUIRED").status,
		PrivacyOptionsRequirementStatus.Status.REQUIRED
	)
	assert_eq(
		PrivacyOptionsRequirementStatus.new("NOT_REQUIRED").status,
		PrivacyOptionsRequirementStatus.Status.NOT_REQUIRED
	)
	assert_eq(
		PrivacyOptionsRequirementStatus.new("UNKNOWN").status,
		PrivacyOptionsRequirementStatus.Status.UNKNOWN
	)
	assert_eq(
		PrivacyOptionsRequirementStatus.new("bogus").status,
		PrivacyOptionsRequirementStatus.Status.UNKNOWN
	)


func test_phase0e_auto_start_ads_disabled() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	assert_true(src.find("SPIKE_AUTO_START_ADS := false") >= 0)
	assert_true(src.find("SPIKE_AUTO_START_ADS := true") < 0)


func test_phase0e_uses_google_test_ids_only() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	assert_true(src.find("ca-app-pub-3940256099942544~3347511713") >= 0)
	assert_true(src.find("ca-app-pub-3940256099942544/9214589741") >= 0)


func test_phase0e_admob_wrapper_exposes_ump_current_apis() -> void:
	var src := FileAccess.get_file_as_string("res://addons/AdmobPlugin/Admob.gd")
	assert_true(src.find("func can_request_ads()") >= 0)
	assert_true(src.find("func get_privacy_options_requirement_status()") >= 0)
	assert_true(src.find("func show_privacy_options_form()") >= 0)
	assert_true(src.find("func get_ump_consent_snapshot()") >= 0)
	assert_true(src.find("signal privacy_options_form_dismissed") >= 0)
	# Regression: wrappers must call native UMP APIs directly (no method-existence probe).
	var can_fn_start := src.find("func can_request_ads()")
	var can_fn_end := src.find("func get_privacy_options_requirement_status()")
	assert_true(can_fn_start >= 0 and can_fn_end > can_fn_start)
	var can_fn_body := src.substr(can_fn_start, can_fn_end - can_fn_start)
	assert_true(can_fn_body.find("has_method") < 0)
	assert_true(can_fn_body.find("_plugin_singleton.can_request_ads()") >= 0)


func test_phase0e_debug_geography_label_uses_enum_value_not_keys_index() -> void:
	## OTHER=4 must not be labeled via keys()[4] (that incorrectly yields REGULATED_US_STATE).
	var keys: Array = ConsentRequestParameters.DebugGeography.keys()
	assert_eq(ConsentRequestParameters.DebugGeography.OTHER, 4)
	assert_eq(ConsentRequestParameters.DebugGeography.REGULATED_US_STATE, 3)
	assert_eq(keys[ConsentRequestParameters.DebugGeography.OTHER], "REGULATED_US_STATE")
	var resolved := ""
	for key in keys:
		if ConsentRequestParameters.DebugGeography[key] == ConsentRequestParameters.DebugGeography.OTHER:
			resolved = str(key)
			break
	assert_eq(resolved, "OTHER")
	var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	assert_true(main_src.find("DebugGeography.keys()[_selected_debug_geography()]") < 0)
	assert_true(main_src.find("func _debug_geography_name(") >= 0)


func test_phase0e_patched_aars_present() -> void:
	assert_true(FileAccess.file_exists("res://addons/AdmobPlugin/bin/debug/AdmobPlugin-debug.aar"))
	assert_true(FileAccess.file_exists("res://addons/AdmobPlugin/bin/release/AdmobPlugin-release.aar"))
