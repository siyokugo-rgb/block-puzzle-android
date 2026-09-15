extends GutTest

## Phase 0-F: production baseline auto UMP / auto banner / UI / ID separation.


class FakeAdmob extends Admob:
	var update_consent_calls: int = 0
	var initialize_calls: int = 0
	var load_banner_calls: int = 0
	var remove_banner_calls: int = 0
	var banner_loaded_flag: bool = false
	var last_removed_id: String = ""
	var fake_can_request: bool = false
	var fake_privacy: String = "NOT_REQUIRED"

	func update_consent_info(_params: ConsentRequestParameters) -> void:
		update_consent_calls += 1

	func initialize() -> void:
		initialize_calls += 1

	func can_request_ads() -> bool:
		return fake_can_request

	func is_consent_form_available() -> bool:
		return false

	func get_consent_status() -> Variant:
		return null

	func get_privacy_options_requirement_status() -> PrivacyOptionsRequirementStatus:
		return PrivacyOptionsRequirementStatus.new(fake_privacy)

	func create_banner_ad_request() -> LoadAdRequest:
		return LoadAdRequest.new()

	func load_banner_ad(_request: LoadAdRequest) -> void:
		load_banner_calls += 1

	func is_banner_ad_loaded() -> bool:
		return banner_loaded_flag

	func remove_banner_ad(ad_id: String = "") -> void:
		remove_banner_calls += 1
		last_removed_id = ad_id
		banner_loaded_flag = false

	func show_privacy_options_form() -> void:
		pass

	func show_banner_ad(_ad_id: String) -> void:
		pass


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


func test_phase0f_production_main_has_no_update_consent_or_request_banner_buttons() -> void:
	var main_scene := FileAccess.get_file_as_string("res://scenes/main.tscn")
	assert_true(main_scene.find("UpdateConsentButton") < 0)
	assert_true(main_scene.find("RequestBannerButton") < 0)
	assert_true(main_scene.find("Update Consent") < 0)
	assert_true(main_scene.find("Request Banner") < 0)
	assert_true(main_scene.find("PrivacyOptionsButton") >= 0)
	assert_true(main_scene.find("Privacy Options") >= 0)

	var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	assert_true(main_src.find("_on_update_consent") < 0)
	assert_true(main_src.find("_on_request_banner") < 0)
	assert_true(main_src.find("_on_privacy_options_button_pressed") >= 0)


func test_phase0f_production_boot_starts_consent_update_automatically() -> void:
	var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	assert_true(main_src.find("_start_production_consent_update()") >= 0)
	assert_true(main_src.find("params.set_is_real(true)") >= 0)
	assert_true(main_src.find("begin_consent_update(params)") >= 0)
	assert_true(main_src.find("auto_request_banner = true") >= 0)
	# Production path must not configure debug geography / test device hash.
	var start_idx := main_src.find("func _start_production_consent_update")
	assert_true(start_idx >= 0)
	var start_body := main_src.substr(start_idx, 400)
	assert_true(start_body.find("DebugGeography") < 0)
	assert_true(start_body.find("test_device") < 0)
	assert_true(start_body.find("set_debug_geography") < 0)

	var main_scene := FileAccess.get_file_as_string("res://scenes/main.tscn")
	assert_true(main_scene.find("auto_request_banner = true") >= 0)


func test_phase0f_production_scene_clears_admob_node_sample_ids() -> void:
	## Banner/unit requests use AdsConfig; Manifest App ID comes from android_export.cfg.
	## Production scene must not embed Google sample unit/app IDs on the Admob node.
	var main_scene := FileAccess.get_file_as_string("res://scenes/main.tscn")
	assert_true(main_scene.find('android_debug_application_id = ""') >= 0)
	assert_true(main_scene.find('android_debug_banner_id = ""') >= 0)
	assert_true(main_scene.find("ca-app-pub-3940256099942544") < 0)

	var export_cfg := FileAccess.get_file_as_string(
		"res://addons/AdmobPlugin/android_export.cfg"
	)
	assert_true(export_cfg.find("ca-app-pub-3940256099942544~3347511713") >= 0)
	assert_true(export_cfg.find("is_real=false") >= 0)


func test_phase0f_regression_spike_scene_is_separate() -> void:
	assert_true(FileAccess.file_exists("res://scenes/regression/phase0e_ump_spike.tscn"))
	assert_true(FileAccess.file_exists("res://scripts/regression/phase0e_ump_spike.gd"))
	var project := FileAccess.get_file_as_string("res://project.godot")
	assert_true(project.find('run/main_scene="res://scenes/main.tscn"') >= 0)
	assert_true(project.find("phase0e_ump_spike") < 0)


func test_phase0f_regression_spike_keeps_manual_a_e_ui() -> void:
	var spike := FileAccess.get_file_as_string("res://scenes/regression/phase0e_ump_spike.tscn")
	assert_true(spike.find("UpdateConsentButton") >= 0)
	assert_true(spike.find("RequestBannerButton") >= 0)
	assert_true(spike.find("ResetConsentButton") >= 0)
	assert_true(spike.find("PrivacyOptionsButton") >= 0)
	assert_true(spike.find("GeoOption") >= 0)
	assert_true(spike.find("DeviceHashEdit") >= 0)
	assert_true(spike.find("ca-app-pub-3940256099942544") >= 0)


func test_phase0f_service_exposes_gate_and_cleanup_apis() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ads/ads_consent_service.gd")
	assert_true(src.find("func begin_consent_update(") >= 0)
	assert_true(src.find("func request_banner_if_allowed(") >= 0)
	assert_true(src.find("func show_privacy_options_form(") >= 0)
	assert_true(src.find("func _remove_active_banner_if_any(") >= 0)
	assert_true(src.find("consent_update_in_flight") >= 0)
	assert_true(src.find("auto_request_banner") >= 0)
	assert_true(src.find("duplicate banner request ignored") >= 0)
	assert_true(src.find("delayed load while blocked") >= 0)
	assert_true(src.find("privacy options dismissed") >= 0)


func test_phase0f_service_blocks_banner_when_production_ids_empty() -> void:
	var svc := AdsConsentService.new()
	add_child_autoqfree(svc)
	var fake := FakeAdmob.new()
	add_child_autoqfree(fake)
	svc.bind_admob(fake)
	svc.use_test_ad_units = false
	svc.auto_request_banner = true
	svc.consent_update_completed = true
	svc.can_request_ads = true
	svc.ads_decision = ConsentGate.AdsDecision.ALLOWED_CAN_REQUEST_ADS

	assert_false(svc.request_banner_if_allowed())
	assert_eq(fake.initialize_calls, 0)
	assert_eq(fake.load_banner_calls, 0)
	assert_false(svc.banner_requested)


func test_phase0f_service_blocks_banner_when_can_request_ads_false() -> void:
	var svc := AdsConsentService.new()
	add_child_autoqfree(svc)
	var fake := FakeAdmob.new()
	add_child_autoqfree(fake)
	svc.bind_admob(fake)
	svc.use_test_ad_units = true
	svc.consent_update_completed = true
	svc.can_request_ads = false
	svc.ads_decision = ConsentGate.AdsDecision.BLOCKED_CANNOT_REQUEST_ADS

	assert_false(svc.request_banner_if_allowed())
	assert_eq(fake.initialize_calls, 0)
	assert_false(svc.banner_requested)


func test_phase0f_service_blocks_banner_before_consent_update() -> void:
	var svc := AdsConsentService.new()
	add_child_autoqfree(svc)
	var fake := FakeAdmob.new()
	add_child_autoqfree(fake)
	svc.bind_admob(fake)
	svc.use_test_ad_units = true
	svc.consent_update_completed = false
	svc.can_request_ads = true
	svc.ads_decision = ConsentGate.AdsDecision.BLOCKED_PRE_UPDATE

	assert_false(svc.request_banner_if_allowed())
	assert_eq(fake.initialize_calls, 0)


func test_phase0f_service_requests_banner_once_when_allowed_and_ids_set() -> void:
	var svc := AdsConsentService.new()
	add_child_autoqfree(svc)
	var fake := FakeAdmob.new()
	add_child_autoqfree(fake)
	svc.bind_admob(fake)
	# use_test_ad_units stands in for "IDs configured" (production constants stay empty).
	svc.use_test_ad_units = true
	svc.auto_request_banner = true
	svc.consent_update_completed = true
	svc.can_request_ads = true
	svc.ads_decision = ConsentGate.AdsDecision.ALLOWED_CAN_REQUEST_ADS
	svc.sdk_initialized = true

	assert_true(svc.request_banner_if_allowed())
	assert_eq(fake.load_banner_calls, 1)
	assert_true(svc.banner_requested)

	assert_false(svc.request_banner_if_allowed())
	assert_eq(fake.load_banner_calls, 1)


func test_phase0f_service_duplicate_consent_update_ignored() -> void:
	var svc := AdsConsentService.new()
	add_child_autoqfree(svc)
	var fake := FakeAdmob.new()
	add_child_autoqfree(fake)
	svc.bind_admob(fake)
	var params := ConsentRequestParameters.new()
	params.set_is_real(true)

	svc.begin_consent_update(params)
	assert_eq(fake.update_consent_calls, 1)
	assert_true(svc.consent_update_in_flight)

	svc.begin_consent_update(params)
	assert_eq(fake.update_consent_calls, 1)


func test_phase0f_service_allowed_to_blocked_cleans_banner() -> void:
	var svc := AdsConsentService.new()
	add_child_autoqfree(svc)
	var fake := FakeAdmob.new()
	add_child_autoqfree(fake)
	svc.bind_admob(fake)
	svc.consent_update_completed = true
	svc.can_request_ads = true
	svc.ads_decision = ConsentGate.AdsDecision.ALLOWED_CAN_REQUEST_ADS
	svc.last_banner_ad_id = "banner-tracked"
	svc.banner_requested = true
	fake.banner_loaded_flag = true

	svc.can_request_ads = false
	svc.refresh_from_native("allowed→blocked")
	assert_eq(svc.ads_decision, ConsentGate.AdsDecision.BLOCKED_CANNOT_REQUEST_ADS)
	assert_true(fake.remove_banner_calls >= 1)
	assert_eq(svc.last_banner_ad_id, "")
	assert_false(svc.banner_requested)


func test_phase0f_service_auto_request_after_refresh_when_ids_configured() -> void:
	var svc := AdsConsentService.new()
	add_child_autoqfree(svc)
	var fake := FakeAdmob.new()
	add_child_autoqfree(fake)
	svc.bind_admob(fake)
	svc.use_test_ad_units = true
	svc.auto_request_banner = true
	svc.consent_update_completed = true
	svc.can_request_ads = true
	svc.sdk_initialized = true

	svc.refresh_from_native("post-update auto")
	assert_true(svc.banner_requested)
	assert_eq(fake.load_banner_calls, 1)


func test_phase0f_service_auto_request_skips_when_production_ids_empty() -> void:
	var svc := AdsConsentService.new()
	add_child_autoqfree(svc)
	var fake := FakeAdmob.new()
	add_child_autoqfree(fake)
	svc.bind_admob(fake)
	svc.use_test_ad_units = false
	svc.auto_request_banner = true
	svc.consent_update_completed = true
	svc.can_request_ads = true

	svc.refresh_from_native("post-update no ids")
	assert_false(svc.banner_requested)
	assert_eq(fake.load_banner_calls, 0)
	assert_eq(fake.initialize_calls, 0)


func test_phase0f_privacy_options_required_helper() -> void:
	var svc := AdsConsentService.new()
	add_child_autoqfree(svc)
	svc.privacy_status_text = "REQUIRED"
	assert_true(svc.is_privacy_options_required())
	svc.privacy_status_text = "NOT_REQUIRED"
	assert_false(svc.is_privacy_options_required())
