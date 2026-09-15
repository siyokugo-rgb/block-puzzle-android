class_name AdsConsentService
extends Node

## Minimal shared AdMob / UMP baseline (Phase 0-F).
## Owns consent update, canRequestAds gate, privacy options, banner request,
## allowed→blocked banner cleanup, duplicate / delayed-load guards,
## and optional auto-banner after a completed update when IDs are configured.
## Debug geography and UMP test-device hash stay in the regression spike UI.

signal state_changed(note: String)
signal log_emitted(message: String)

@export var admob_path: NodePath
## Production baseline must keep this false (never fall back to Google test units).
@export var use_test_ad_units: bool = false
## When true, after consent update completes and ads are allowed, request banner once
## (only if AdsConfig has a banner unit for the current mode).
@export var auto_request_banner: bool = false

## Typed as Node so GUT can inject a lightweight duck-typed double.
## Production always binds an Admob node.
var _admob: Node

var consent_update_completed: bool = false
var consent_update_succeeded: bool = false
var consent_update_in_flight: bool = false
var form_available: bool = false
var form_loaded: bool = false
var consent_status_text: String = "UNKNOWN"
var can_request_ads: bool = false
var privacy_status_text: String = "UNKNOWN"
var ads_decision: ConsentGate.AdsDecision = ConsentGate.initial_decision()
var sdk_initialized: bool = false
var banner_requested: bool = false
var last_banner_ad_id: String = ""


func bind_admob(admob: Node) -> void:
	_admob = admob
	_connect_admob_signals()


func _ready() -> void:
	if _admob == null and admob_path != NodePath(""):
		_admob = get_node_or_null(admob_path)
	if _admob != null:
		_connect_admob_signals()


func _connect_admob_signals() -> void:
	if _admob == null:
		return
	# Real Admob exposes these signals; lightweight test doubles may omit them.
	if _admob.has_signal("initialization_completed"):
		_safe_connect(_admob.initialization_completed, _on_initialization_completed)
	if _admob.has_signal("banner_ad_loaded"):
		_safe_connect(_admob.banner_ad_loaded, _on_banner_ad_loaded)
	if _admob.has_signal("banner_ad_failed_to_load"):
		_safe_connect(_admob.banner_ad_failed_to_load, _on_banner_ad_failed_to_load)
	if _admob.has_signal("banner_ad_refreshed"):
		_safe_connect(_admob.banner_ad_refreshed, _on_banner_ad_refreshed)
	if _admob.has_signal("consent_info_updated"):
		_safe_connect(_admob.consent_info_updated, _on_consent_info_updated)
	if _admob.has_signal("consent_info_update_failed"):
		_safe_connect(_admob.consent_info_update_failed, _on_consent_info_update_failed)
	if _admob.has_signal("consent_form_loaded"):
		_safe_connect(_admob.consent_form_loaded, _on_consent_form_loaded)
	if _admob.has_signal("consent_form_failed_to_load"):
		_safe_connect(_admob.consent_form_failed_to_load, _on_consent_form_failed_to_load)
	if _admob.has_signal("consent_form_dismissed"):
		_safe_connect(_admob.consent_form_dismissed, _on_consent_form_dismissed)
	if _admob.has_signal("privacy_options_form_dismissed"):
		_safe_connect(_admob.privacy_options_form_dismissed, _on_privacy_options_form_dismissed)


func _safe_connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)


func is_ads_allowed() -> bool:
	return ConsentGate.is_ads_allowed(ads_decision)


func is_privacy_options_required() -> bool:
	return (
		privacy_status_text
		== PrivacyOptionsRequirementStatus.status_to_string(
			PrivacyOptionsRequirementStatus.Status.REQUIRED
		)
	)


func begin_consent_update(params: ConsentRequestParameters) -> void:
	if _admob == null:
		_emit_log("FAIL: Admob node missing")
		state_changed.emit("no admob")
		return
	if consent_update_in_flight:
		_emit_log("consent update already in flight; duplicate begin ignored")
		return
	consent_update_in_flight = true
	consent_update_completed = false
	consent_update_succeeded = false
	form_loaded = false
	can_request_ads = false
	_apply_ads_decision(ConsentGate.initial_decision(), "consent update starting")
	_emit_log("update_consent_info()")
	_admob.update_consent_info(params)
	state_changed.emit("update starting")


func reset_consent() -> void:
	if _admob == null:
		return
	consent_update_in_flight = false
	consent_update_completed = false
	consent_update_succeeded = false
	form_available = false
	form_loaded = false
	can_request_ads = false
	privacy_status_text = "UNKNOWN"
	_apply_ads_decision(ConsentGate.initial_decision(), "consent reset")
	_admob.reset_consent_info()
	consent_status_text = _read_consent_status_text()
	_emit_log("consent reset; ads blocked until update completes + canRequestAds")
	state_changed.emit("consent reset")


func show_privacy_options_form() -> void:
	if _admob == null:
		return
	_emit_log("show_privacy_options_form()")
	_admob.show_privacy_options_form()


func request_banner_if_allowed() -> bool:
	# Use core refresh so we do not re-enter auto-request from this path.
	_refresh_from_native_core("pre-banner gate check")
	if not consent_update_completed:
		_emit_log("ad request denied: consent update not completed")
		return false
	if not is_ads_allowed():
		_emit_log("ad request denied by canRequestAds gate")
		return false
	if not AdsConfig.can_request_banner(use_test_ad_units):
		_emit_log("ad request denied: banner unit id not configured for this mode")
		return false
	if banner_requested:
		_emit_log("duplicate banner request ignored")
		return false

	banner_requested = true
	state_changed.emit("ads allowed → init/load")
	if not sdk_initialized:
		_emit_log("initialize() after canRequestAds allow")
		_admob.initialize()
	else:
		_load_banner()
	return true


func refresh_from_native(note: String) -> void:
	_refresh_from_native_core(note)
	_maybe_auto_request_banner(note)


func _refresh_from_native_core(note: String) -> void:
	if _admob == null:
		return
	consent_status_text = _read_consent_status_text()
	form_available = _admob.is_consent_form_available()
	# On-device SoT is native can_request_ads(). Without the plugin (editor/GUT),
	# keep the caller-provided can_request_ads so gate logic stays testable.
	if Engine.has_singleton("AdmobPlugin"):
		can_request_ads = _admob.can_request_ads()
	var privacy: Variant = _admob.get_privacy_options_requirement_status()
	privacy_status_text = privacy.to_status_string() if privacy else "UNKNOWN"
	_apply_ads_decision(
		ConsentGate.evaluate(consent_update_completed, can_request_ads),
		note
	)
	state_changed.emit(note)


func _maybe_auto_request_banner(note: String) -> void:
	if not auto_request_banner:
		return
	if not consent_update_completed:
		return
	if not is_ads_allowed():
		return
	# Empty production IDs: never request (expected Phase 0-F baseline).
	if not AdsConfig.can_request_banner(use_test_ad_units):
		return
	if banner_requested:
		return
	_emit_log("auto banner request after %s" % note)
	request_banner_if_allowed()


func _on_consent_info_updated() -> void:
	consent_update_succeeded = true
	consent_update_completed = true
	consent_update_in_flight = false
	refresh_from_native("consent update SUCCESS")
	if form_available and consent_status_text == "REQUIRED":
		_admob.load_consent_form()


func _on_consent_info_update_failed(error_data: FormError) -> void:
	consent_update_succeeded = false
	consent_update_completed = true
	consent_update_in_flight = false
	var message := error_data.get_message() if error_data else "unknown"
	refresh_from_native("consent update FAILED: %s" % message)


func _on_consent_form_loaded() -> void:
	form_loaded = true
	_emit_log("consent_form_loaded")
	_admob.show_consent_form()
	state_changed.emit("form loaded")


func _on_consent_form_failed_to_load(error_data: FormError) -> void:
	form_loaded = false
	var message := error_data.get_message() if error_data else "unknown"
	_emit_log("consent_form_failed_to_load msg=%s" % message)
	refresh_from_native("form load failed")


func _on_consent_form_dismissed(error_data: FormError) -> void:
	var message := error_data.get_message() if error_data else ""
	refresh_from_native("form dismissed msg=%s" % message)


func _on_privacy_options_form_dismissed(error_data: FormError) -> void:
	var message := error_data.get_message() if error_data else ""
	_emit_log("privacy_options_form_dismissed msg=%s" % message)
	refresh_from_native("privacy options dismissed")


func _on_initialization_completed(_status_data: InitializationStatus) -> void:
	sdk_initialized = true
	_emit_log("initialization_completed")
	refresh_from_native("sdk initialized")
	if is_ads_allowed() and AdsConfig.can_request_banner(use_test_ad_units):
		_load_banner()
	else:
		banner_requested = false
		_emit_log("SDK init completed; banner not requested (gate or missing unit id)")


func _load_banner() -> void:
	_refresh_from_native_core("before banner load")
	if not is_ads_allowed():
		banner_requested = false
		return
	if not AdsConfig.can_request_banner(use_test_ad_units):
		banner_requested = false
		_emit_log("banner load skipped: unit id not configured")
		return
	var unit_id := AdsConfig.resolve_banner_unit_id(use_test_ad_units)
	_emit_log("load_banner unit=%s" % unit_id)
	var request: LoadAdRequest = _admob.create_banner_ad_request()
	request.set_ad_unit_id(unit_id)
	request.set_ad_size(LoadAdRequest.RequestedAdSize.ADAPTIVE)
	request.set_ad_position(LoadAdRequest.AdPosition.BOTTOM)
	_admob.load_banner_ad(request)


func _on_banner_ad_loaded(ad_info: AdInfo, _response_info: ResponseInfo) -> void:
	var loaded_id := ad_info.get_ad_id() if ad_info else ""
	if not loaded_id.is_empty():
		last_banner_ad_id = loaded_id
	refresh_from_native("banner loaded")
	if ConsentGate.should_discard_loaded_banner(is_ads_allowed()):
		_emit_log("banner loaded while blocked; discard without show id=%s" % loaded_id)
		_remove_active_banner_if_any("delayed load while blocked")
		state_changed.emit("blocked delayed banner discarded")
		return
	_emit_log("banner_ad_loaded")
	if not last_banner_ad_id.is_empty():
		_admob.show_banner_ad(last_banner_ad_id)
	state_changed.emit("banner shown")


func _on_banner_ad_failed_to_load(ad_info: AdInfo, error_data: LoadAdError) -> void:
	var code := error_data.get_code() if error_data else -1
	var message := error_data.get_message() if error_data else "unknown"
	_emit_log(
		"banner_ad_failed_to_load code=%s msg=%s ad=%s" % [str(code), message, str(ad_info)]
	)
	banner_requested = false
	state_changed.emit("banner load failed")


func _on_banner_ad_refreshed(ad_info: AdInfo, _response_info: ResponseInfo) -> void:
	var refreshed_id := ad_info.get_ad_id() if ad_info else ""
	_emit_log("banner_ad_refreshed id=%s" % refreshed_id)
	if is_ads_allowed():
		if not refreshed_id.is_empty():
			last_banner_ad_id = refreshed_id
		return
	if not refreshed_id.is_empty():
		last_banner_ad_id = refreshed_id
	_remove_active_banner_if_any("banner refreshed while blocked")
	state_changed.emit("blocked refresh discarded")


func _has_tracked_or_loaded_banner() -> bool:
	if not last_banner_ad_id.is_empty():
		return true
	if _admob == null:
		return false
	return _admob.is_banner_ad_loaded()


func _apply_ads_decision(new_decision: ConsentGate.AdsDecision, reason: String) -> void:
	var was_allowed := ConsentGate.is_ads_allowed(ads_decision)
	var had_banner := _has_tracked_or_loaded_banner()
	ads_decision = new_decision
	var now_allowed := ConsentGate.is_ads_allowed(ads_decision)
	if (
		ConsentGate.should_cleanup_on_decision_change(was_allowed, now_allowed)
		or ConsentGate.should_cleanup_active_banner(now_allowed, had_banner)
	):
		_remove_active_banner_if_any(reason)


func _remove_active_banner_if_any(reason: String) -> void:
	if _admob == null:
		last_banner_ad_id = ""
		banner_requested = false
		return
	var id := last_banner_ad_id
	var removed := false
	if not id.is_empty():
		_emit_log("remove_banner_ad id=%s reason=%s" % [id, reason])
		_admob.remove_banner_ad(id)
		removed = true
	var guard := 0
	while _admob.is_banner_ad_loaded() and guard < 16:
		_emit_log("remove_banner_ad cache_remainder reason=%s" % reason)
		_admob.remove_banner_ad()
		removed = true
		guard += 1
	last_banner_ad_id = ""
	banner_requested = false
	if removed:
		_emit_log("active banner removed (%s)" % reason)
	else:
		_emit_log("no active banner to remove (%s)" % reason)


func _read_consent_status_text() -> String:
	var consent: Variant = _admob.get_consent_status()
	if consent == null:
		return "UNKNOWN"
	return consent.to_status_string()


func _emit_log(message: String) -> void:
	log_emitted.emit(message)
