extends Control

## Phase 0-E Technical Spike: UMP consent flow + ads-request gate.
## Google test IDs only. No production AdMob IDs.
## Official canRequestAds / privacy-options APIs are unavailable in godot-admob v7.0 —
## see tooling/admob/UMP_API_AUDIT.md. Ads use fail-closed status gating only.

const SAMPLE_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const ANCHORED_ADAPTIVE_BANNER_TEST_UNIT_ID := "ca-app-pub-3940256099942544/9214589741"

## Phase 0-D unconditional auto ads start is disabled for Phase 0-E.
const SPIKE_AUTO_START_ADS := false

@onready var _title: Label = $Title
@onready var _status: Label = $Status
@onready var _state: Label = $StatePanel
@onready var _log: Label = $Log
@onready var _tap_counter: Label = $TapCounter
@onready var _geo_option: OptionButton = $Buttons/GeoRow/GeoOption
@onready var _device_hash_edit: LineEdit = $Buttons/DeviceHashEdit
@onready var _update_button: Button = $Buttons/UpdateConsentButton
@onready var _show_form_button: Button = $Buttons/ShowFormButton
@onready var _reset_button: Button = $Buttons/ResetConsentButton
@onready var _request_banner_button: Button = $Buttons/RequestBannerButton
@onready var _privacy_probe_button: Button = $Buttons/PrivacyProbeButton
@onready var _tap_button: Button = $Buttons/TapButton
@onready var _admob: Admob = $Admob

var _tap_count: int = 0
var _last_banner_ad_id: String = ""
var _sdk_initialized: bool = false
var _banner_requested: bool = false
var _consent_update_succeeded: bool = false
var _consent_update_attempted: bool = false
var _form_available: bool = false
var _form_loaded: bool = false
var _form_shown: bool = false
var _form_dismissed: bool = false
var _consent_status_text: String = "UNKNOWN"
var _ads_decision: ConsentGate.AdsDecision = ConsentGate.initial_decision()
var _privacy_options_api_available: bool = false


func _ready() -> void:
	_title.text = "Phase 0-E UMP Consent Spike"
	_device_hash_edit.placeholder_text = "UMP test device hash (runtime only, not saved)"
	_device_hash_edit.secret = false
	_device_hash_edit.clear()
	_populate_geo_options()
	_show_form_button.disabled = true
	_request_banner_button.disabled = true
	_refresh_state_panel("idle: update consent before any ad request")
	_append_log(
		(
			"plugin=%s canRequestAds_api=false privacy_options_api=false auto_ads=%s"
			% [Engine.has_singleton("AdmobPlugin"), str(SPIKE_AUTO_START_ADS)]
		)
	)

	_admob.initialization_completed.connect(_on_initialization_completed)
	_admob.banner_ad_loaded.connect(_on_banner_ad_loaded)
	_admob.banner_ad_failed_to_load.connect(_on_banner_ad_failed_to_load)
	_admob.banner_ad_impression.connect(_on_banner_ad_impression)
	_admob.consent_info_updated.connect(_on_consent_info_updated)
	_admob.consent_info_update_failed.connect(_on_consent_info_update_failed)
	_admob.consent_form_loaded.connect(_on_consent_form_loaded)
	_admob.consent_form_failed_to_load.connect(_on_consent_form_failed_to_load)
	_admob.consent_form_dismissed.connect(_on_consent_form_dismissed)

	_privacy_options_api_available = _probe_privacy_options_api()
	_refresh_state_panel("ready")


func _populate_geo_options() -> void:
	_geo_option.clear()
	for key in ConsentRequestParameters.DebugGeography.keys():
		_geo_option.add_item(key)
	# Default EEA so Xperia can force a required form in debug UMP tests.
	var eea_idx := ConsentRequestParameters.DebugGeography.keys().find("EEA")
	_geo_option.select(eea_idx if eea_idx >= 0 else 0)


func _selected_debug_geography() -> ConsentRequestParameters.DebugGeography:
	var key: String = _geo_option.get_item_text(_geo_option.selected)
	return ConsentRequestParameters.DebugGeography[key]


func _probe_privacy_options_api() -> bool:
	# Do not guess method names beyond audited surface.
	if not Engine.has_singleton("AdmobPlugin"):
		return false
	var singleton := Engine.get_singleton("AdmobPlugin")
	for method_name in [
		"get_privacy_options_requirement_status",
		"show_privacy_options_form",
		"is_privacy_options_required",
		"can_request_ads",
	]:
		if singleton.has_method(method_name):
			_append_log("unexpected method present: %s" % method_name)
			return true
	return false


func _on_update_consent_button_pressed() -> void:
	_request_consent_update()


func _on_show_form_button_pressed() -> void:
	if not _form_loaded:
		_set_status("loading consent form...")
		_admob.load_consent_form()
		return
	_set_status("showing consent form...")
	_form_shown = true
	_refresh_state_panel("form show requested")
	_admob.show_consent_form()


func _on_reset_consent_button_pressed() -> void:
	_consent_update_succeeded = false
	_consent_update_attempted = false
	_form_available = false
	_form_loaded = false
	_form_shown = false
	_form_dismissed = false
	_banner_requested = false
	_last_banner_ad_id = ""
	_ads_decision = ConsentGate.initial_decision()
	_request_banner_button.disabled = true
	_show_form_button.disabled = true
	_set_status("reset_consent_info()")
	_admob.reset_consent_info()
	_consent_status_text = _read_consent_status_text()
	_refresh_state_panel("consent reset")
	_append_log("consent reset; ads remain blocked until successful update")


func _on_request_banner_button_pressed() -> void:
	_request_ads_if_allowed()


func _on_privacy_probe_button_pressed() -> void:
	_privacy_options_api_available = _probe_privacy_options_api()
	_set_status(
		(
			"privacy options API available=%s (v7.0 expected false)"
			% str(_privacy_options_api_available)
		)
	)
	_refresh_state_panel("privacy probe")


func _on_tap_button_pressed() -> void:
	_tap_count += 1
	_tap_counter.text = "UI taps: %d" % _tap_count
	_append_log("ui interactive tap=%d" % _tap_count)


func _request_consent_update() -> void:
	if not Engine.has_singleton("AdmobPlugin"):
		_set_status("FAIL: AdmobPlugin singleton missing")
		_ads_decision = ConsentGate.AdsDecision.BLOCKED_UPDATE_FAILED
		_refresh_state_panel("no plugin")
		return

	_consent_update_attempted = true
	_consent_update_succeeded = false
	_form_loaded = false
	_form_shown = false
	_form_dismissed = false
	_ads_decision = ConsentGate.AdsDecision.BLOCKED_NO_UPDATE
	_request_banner_button.disabled = true
	_set_status("consent info update starting...")
	_refresh_state_panel("update starting")

	var params := ConsentRequestParameters.new()
	params.set_is_real(false)
	params.set_debug_geography(_selected_debug_geography())
	var device_hash := _device_hash_edit.text.strip_edges()
	if not device_hash.is_empty():
		# Runtime-only. Never written to disk / git / scene.
		params.add_test_device_hashed_id(device_hash)
		_append_log("using runtime test device hash (len=%d)" % device_hash.length())
	else:
		_append_log("no runtime test device hash provided")

	_append_log(
		(
			"update_consent_info geo=%s is_real=false"
			% ConsentRequestParameters.DebugGeography.keys()[_selected_debug_geography()]
		)
	)
	_admob.update_consent_info(params)


func _on_consent_info_updated() -> void:
	_consent_update_succeeded = true
	_consent_status_text = _read_consent_status_text()
	_form_available = _admob.is_consent_form_available()
	_ads_decision = _reevaluate_ads_decision()
	_set_status("consent update SUCCESS status=%s" % _consent_status_text)
	_append_log("consent_info_updated form_available=%s" % str(_form_available))
	_refresh_state_panel("update success")
	_apply_post_update_actions()


func _on_consent_info_update_failed(error_data: FormError) -> void:
	_consent_update_succeeded = false
	_consent_status_text = _read_consent_status_text()
	_form_available = false
	# Fail-closed: no canRequestAds() to honor previous-session consent safely.
	_ads_decision = ConsentGate.evaluate(false, UserConsent.Status.UNKNOWN)
	_request_banner_button.disabled = true
	var message := error_data.get_message() if error_data else "unknown"
	_set_status("consent update FAILED (fail-closed): %s" % message)
	_append_log("consent_info_update_failed msg=%s" % message)
	_refresh_state_panel("update failed")


func _apply_post_update_actions() -> void:
	_show_form_button.disabled = not _form_available
	_request_banner_button.disabled = not ConsentGate.is_ads_allowed(_ads_decision)

	if _ads_decision == ConsentGate.AdsDecision.BLOCKED_CONSENT_REQUIRED:
		if _form_available:
			_set_status("consent REQUIRED → loading form")
			_admob.load_consent_form()
		else:
			_set_status("consent REQUIRED but form unavailable; ads blocked")
	elif ConsentGate.is_ads_allowed(_ads_decision):
		_set_status("ads ALLOWED (%s); banner request enabled" % ConsentGate.decision_name(_ads_decision))


func _on_consent_form_loaded() -> void:
	_form_loaded = true
	_show_form_button.disabled = false
	_set_status("consent form loaded → showing")
	_append_log("consent_form_loaded")
	_form_shown = true
	_refresh_state_panel("form loaded")
	_admob.show_consent_form()


func _on_consent_form_failed_to_load(error_data: FormError) -> void:
	_form_loaded = false
	var message := error_data.get_message() if error_data else "unknown"
	_set_status("consent form load FAILED: %s" % message)
	_append_log("consent_form_failed_to_load msg=%s" % message)
	_ads_decision = _reevaluate_ads_decision()
	_request_banner_button.disabled = not ConsentGate.is_ads_allowed(_ads_decision)
	_refresh_state_panel("form load failed")


func _on_consent_form_dismissed(error_data: FormError) -> void:
	_form_dismissed = true
	var message := error_data.get_message() if error_data else ""
	_consent_status_text = _read_consent_status_text()
	_form_available = _admob.is_consent_form_available()
	_ads_decision = _reevaluate_ads_decision()
	_request_banner_button.disabled = not ConsentGate.is_ads_allowed(_ads_decision)
	_set_status(
		(
			"form dismissed status=%s ads=%s msg=%s"
			% [_consent_status_text, ConsentGate.decision_name(_ads_decision), message]
		)
	)
	_append_log("consent_form_dismissed")
	_refresh_state_panel("form dismissed")


func _request_ads_if_allowed() -> void:
	_ads_decision = _reevaluate_ads_decision()
	if not ConsentGate.is_ads_allowed(_ads_decision):
		_set_status("BLOCKED: refusing ad request (%s)" % ConsentGate.decision_name(_ads_decision))
		_append_log("ad request denied by consent gate")
		_request_banner_button.disabled = true
		return

	_banner_requested = true
	_refresh_state_panel("ads allowed → init/load")
	if not _sdk_initialized:
		_set_status("ads allowed → initializing Mobile Ads SDK")
		_append_log("initialize() after consent gate allow app_id=%s" % SAMPLE_APP_ID)
		_admob.initialize()
	else:
		_load_test_banner()


func _load_test_banner() -> void:
	if not ConsentGate.is_ads_allowed(_ads_decision):
		_set_status("BLOCKED before banner load")
		return
	_set_status("loading anchored adaptive test banner...")
	_append_log("load_banner unit=%s" % ANCHORED_ADAPTIVE_BANNER_TEST_UNIT_ID)
	var request: LoadAdRequest = _admob.create_banner_ad_request()
	request.set_ad_unit_id(ANCHORED_ADAPTIVE_BANNER_TEST_UNIT_ID)
	request.set_ad_size(LoadAdRequest.RequestedAdSize.ADAPTIVE)
	request.set_ad_position(LoadAdRequest.AdPosition.BOTTOM)
	_admob.load_banner_ad(request)


func _on_initialization_completed(status_data: InitializationStatus) -> void:
	_sdk_initialized = true
	var tags: Array = status_data.get_network_tags() if status_data else []
	_set_status("SDK initialized networks=%d" % tags.size())
	_append_log("initialization_completed")
	_refresh_state_panel("sdk initialized")
	if ConsentGate.is_ads_allowed(_ads_decision):
		_load_test_banner()
	else:
		_set_status("SDK init completed but ads now blocked; no banner request")


func _on_banner_ad_loaded(ad_info: AdInfo, _response_info: ResponseInfo) -> void:
	if not ConsentGate.is_ads_allowed(_ads_decision):
		_append_log("banner loaded but gate blocked; not showing")
		return
	_last_banner_ad_id = ad_info.get_ad_id() if ad_info else ""
	_set_status("banner loaded id=%s → show" % _last_banner_ad_id)
	_append_log("banner_ad_loaded")
	if not _last_banner_ad_id.is_empty():
		_admob.show_banner_ad(_last_banner_ad_id)
	_refresh_state_panel("banner shown")


func _on_banner_ad_failed_to_load(ad_info: AdInfo, error_data: LoadAdError) -> void:
	var code := error_data.get_code() if error_data else -1
	var message := error_data.get_message() if error_data else "unknown"
	_set_status("banner load FAILED code=%s" % str(code))
	_append_log("banner_ad_failed_to_load code=%s msg=%s ad=%s" % [str(code), message, str(ad_info)])


func _on_banner_ad_impression(ad_info: AdInfo) -> void:
	_append_log("banner_ad_impression id=%s" % (ad_info.get_ad_id() if ad_info else ""))


func _reevaluate_ads_decision() -> ConsentGate.AdsDecision:
	# Always re-read plugin status; do not treat prior decision as authority.
	var consent := _admob.get_consent_status()
	var status := consent.status if consent else UserConsent.Status.UNKNOWN
	_consent_status_text = UserConsent.status_to_string(status)
	return ConsentGate.evaluate(_consent_update_succeeded, status)


func _read_consent_status_text() -> String:
	var consent := _admob.get_consent_status()
	if consent == null:
		return "UNKNOWN"
	return consent.to_status_string()


func _refresh_state_panel(note: String) -> void:
	_state.text = "\n".join(
		[
			"update_attempted=%s update_ok=%s" % [str(_consent_update_attempted), str(_consent_update_succeeded)],
			"consent_status=%s form_available=%s" % [_consent_status_text, str(_form_available)],
			"form_loaded=%s shown=%s dismissed=%s" % [str(_form_loaded), str(_form_shown), str(_form_dismissed)],
			"ads_decision=%s allowed=%s" % [ConsentGate.decision_name(_ads_decision), str(ConsentGate.is_ads_allowed(_ads_decision))],
			"sdk_initialized=%s banner_requested=%s" % [str(_sdk_initialized), str(_banner_requested)],
			"privacy_options_api=%s note=%s" % [str(_privacy_options_api_available), note],
		]
	)


func _set_status(text: String) -> void:
	_status.text = "Status: %s" % text
	print("[Phase0E] %s" % text)


func _append_log(text: String) -> void:
	var line := "[Phase0E] %s" % text
	print(line)
	_log.text = "%s\n%s" % [_log.text, line] if not _log.text.is_empty() else line
