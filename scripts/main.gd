extends Control

## Phase 0-E.1 Technical Spike: UMP consent + canRequestAds gate + privacy options.
## Google test IDs only. No production AdMob IDs.
## Ads final authority: Admob.can_request_ads() (native UMP canRequestAds).

const SAMPLE_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const ANCHORED_ADAPTIVE_BANNER_TEST_UNIT_ID := "ca-app-pub-3940256099942544/9214589741"

## Phase 0-D unconditional auto ads start remains disabled.
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
@onready var _privacy_options_button: Button = $Buttons/PrivacyOptionsButton
@onready var _tap_button: Button = $Buttons/TapButton
@onready var _admob: Admob = $Admob

var _tap_count: int = 0
var _last_banner_ad_id: String = ""
var _sdk_initialized: bool = false
var _banner_requested: bool = false
var _consent_update_completed: bool = false
var _consent_update_succeeded: bool = false
var _form_available: bool = false
var _form_loaded: bool = false
var _form_shown: bool = false
var _form_dismissed: bool = false
var _consent_status_text: String = "UNKNOWN"
var _can_request_ads: bool = false
var _privacy_status_text: String = "UNKNOWN"
var _ads_decision: ConsentGate.AdsDecision = ConsentGate.initial_decision()


func _ready() -> void:
	_title.text = "Phase 0-E.1 UMP canRequestAds Spike"
	_device_hash_edit.placeholder_text = "UMP test device hash (runtime only, not saved)"
	_device_hash_edit.clear()
	_populate_geo_options()
	_show_form_button.disabled = true
	_request_banner_button.disabled = true
	_privacy_options_button.disabled = true
	_append_log(
		(
			"plugin=%s auto_ads=%s sample_app=%s"
			% [Engine.has_singleton("AdmobPlugin"), str(SPIKE_AUTO_START_ADS), SAMPLE_APP_ID]
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
	_admob.privacy_options_form_dismissed.connect(_on_privacy_options_form_dismissed)

	_refresh_gate_state("ready: update consent before any ad request")


func _populate_geo_options() -> void:
	_geo_option.clear()
	for key in ConsentRequestParameters.DebugGeography.keys():
		_geo_option.add_item(key)
	var eea_idx := ConsentRequestParameters.DebugGeography.keys().find("EEA")
	_geo_option.select(eea_idx if eea_idx >= 0 else 0)


func _selected_debug_geography() -> ConsentRequestParameters.DebugGeography:
	var key: String = _geo_option.get_item_text(_geo_option.selected)
	return ConsentRequestParameters.DebugGeography[key]


func _debug_geography_name(value: ConsentRequestParameters.DebugGeography) -> String:
	# Map by enum VALUE, never by keys()[numeric] (OTHER=4 is not keys index 4).
	for key in ConsentRequestParameters.DebugGeography.keys():
		if ConsentRequestParameters.DebugGeography[key] == value:
			return str(key)
	return "INVALID(%s)" % str(value)


func _on_update_consent_button_pressed() -> void:
	_request_consent_update()


func _on_show_form_button_pressed() -> void:
	if not _form_loaded:
		_set_status("loading consent form...")
		_admob.load_consent_form()
		return
	_set_status("showing consent form...")
	_form_shown = true
	_refresh_gate_state("form show requested")
	_admob.show_consent_form()


func _on_reset_consent_button_pressed() -> void:
	_consent_update_completed = false
	_consent_update_succeeded = false
	_form_available = false
	_form_loaded = false
	_form_shown = false
	_form_dismissed = false
	_banner_requested = false
	_last_banner_ad_id = ""
	_can_request_ads = false
	_privacy_status_text = "UNKNOWN"
	_ads_decision = ConsentGate.initial_decision()
	_request_banner_button.disabled = true
	_show_form_button.disabled = true
	_privacy_options_button.disabled = true
	_set_status("reset_consent_info()")
	_admob.reset_consent_info()
	_consent_status_text = _read_consent_status_text()
	_refresh_gate_state("consent reset")
	_append_log("consent reset; ads blocked until update completes + canRequestAds")


func _on_request_banner_button_pressed() -> void:
	_request_ads_if_allowed()


func _on_privacy_options_button_pressed() -> void:
	_set_status("showing privacy options form...")
	_append_log("show_privacy_options_form()")
	_admob.show_privacy_options_form()


func _on_tap_button_pressed() -> void:
	_tap_count += 1
	_tap_counter.text = "UI taps: %d" % _tap_count
	_append_log("ui interactive tap=%d" % _tap_count)


func _request_consent_update() -> void:
	if not Engine.has_singleton("AdmobPlugin"):
		_set_status("FAIL: AdmobPlugin singleton missing")
		_refresh_gate_state("no plugin")
		return

	_consent_update_completed = false
	_consent_update_succeeded = false
	_form_loaded = false
	_form_shown = false
	_form_dismissed = false
	_banner_requested = false
	_can_request_ads = false
	_ads_decision = ConsentGate.initial_decision()
	_request_banner_button.disabled = true
	_privacy_options_button.disabled = true
	_set_status("consent info update starting...")
	_refresh_gate_state("update starting")

	var params := ConsentRequestParameters.new()
	params.set_is_real(false)
	var ui_label: String = _geo_option.get_item_text(_geo_option.selected)
	var geo_value: ConsentRequestParameters.DebugGeography = _selected_debug_geography()
	var geo_name := _debug_geography_name(geo_value)
	params.set_debug_geography(geo_value)
	var raw_geo: Variant = params.get_raw_data().get(
		ConsentRequestParameters.DEBUG_GEOGRAPHY_PROPERTY, null
	)
	var device_hash := _device_hash_edit.text.strip_edges()
	if not device_hash.is_empty():
		params.add_test_device_hashed_id(device_hash)
		_append_log("using runtime test device hash (len=%d)" % device_hash.length())
	else:
		_append_log("no runtime test device hash provided")

	_append_log(
		(
			"update_consent_info is_real=false ui_label=%s gdscript_enum=%s raw_params=%s label=%s"
			% [ui_label, str(int(geo_value)), str(raw_geo), geo_name]
		)
	)
	_admob.update_consent_info(params)


func _on_consent_info_updated() -> void:
	_consent_update_succeeded = true
	_consent_update_completed = true
	_apply_ump_snapshot("consent update SUCCESS")
	_apply_post_update_actions()


func _on_consent_info_update_failed(error_data: FormError) -> void:
	_consent_update_succeeded = false
	_consent_update_completed = true
	var message := error_data.get_message() if error_data else "unknown"
	_apply_ump_snapshot("consent update FAILED: %s" % message)
	# Still use native canRequestAds as authority on failure.


func _apply_post_update_actions() -> void:
	_show_form_button.disabled = not _form_available
	if _form_available and _consent_status_text == "REQUIRED":
		_set_status("consent REQUIRED → loading form")
		_admob.load_consent_form()
	elif ConsentGate.is_ads_allowed(_ads_decision):
		_set_status("canRequestAds=true; banner request enabled")


func _on_consent_form_loaded() -> void:
	_form_loaded = true
	_show_form_button.disabled = false
	_set_status("consent form loaded → showing")
	_append_log("consent_form_loaded")
	_form_shown = true
	_refresh_gate_state("form loaded")
	_admob.show_consent_form()


func _on_consent_form_failed_to_load(error_data: FormError) -> void:
	_form_loaded = false
	var message := error_data.get_message() if error_data else "unknown"
	_set_status("consent form load FAILED: %s" % message)
	_append_log("consent_form_failed_to_load msg=%s" % message)
	_apply_ump_snapshot("form load failed")


func _on_consent_form_dismissed(error_data: FormError) -> void:
	_form_dismissed = true
	var message := error_data.get_message() if error_data else ""
	_apply_ump_snapshot("form dismissed msg=%s" % message)


func _on_privacy_options_form_dismissed(error_data: FormError) -> void:
	var message := error_data.get_message() if error_data else ""
	_append_log("privacy_options_form_dismissed msg=%s" % message)
	_apply_ump_snapshot("privacy options dismissed")


func _request_ads_if_allowed() -> void:
	_apply_ump_snapshot("pre-banner gate check")
	if not ConsentGate.is_ads_allowed(_ads_decision):
		_set_status("BLOCKED: refusing ad request (%s)" % ConsentGate.decision_name(_ads_decision))
		_append_log("ad request denied by canRequestAds gate")
		_request_banner_button.disabled = true
		return
	if _banner_requested:
		_set_status("BLOCKED: duplicate banner request prevented")
		_append_log("duplicate banner request ignored")
		return

	_banner_requested = true
	_request_banner_button.disabled = true
	_refresh_gate_state("ads allowed → init/load")
	if not _sdk_initialized:
		_set_status("canRequestAds=true → initializing Mobile Ads SDK")
		_append_log("initialize() after canRequestAds allow app_id=%s" % SAMPLE_APP_ID)
		_admob.initialize()
	else:
		_load_test_banner()


func _load_test_banner() -> void:
	_apply_ump_snapshot("before banner load")
	if not ConsentGate.is_ads_allowed(_ads_decision):
		_set_status("BLOCKED before banner load")
		_banner_requested = false
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
	_apply_ump_snapshot("sdk initialized")
	if ConsentGate.is_ads_allowed(_ads_decision):
		_load_test_banner()
	else:
		_set_status("SDK init completed but canRequestAds=false; no banner request")
		_banner_requested = false


func _on_banner_ad_loaded(ad_info: AdInfo, _response_info: ResponseInfo) -> void:
	_apply_ump_snapshot("banner loaded")
	if not ConsentGate.is_ads_allowed(_ads_decision):
		_append_log("banner loaded but canRequestAds false; not showing")
		return
	_last_banner_ad_id = ad_info.get_ad_id() if ad_info else ""
	_set_status("banner loaded id=%s → show" % _last_banner_ad_id)
	_append_log("banner_ad_loaded")
	if not _last_banner_ad_id.is_empty():
		_admob.show_banner_ad(_last_banner_ad_id)
	_refresh_gate_state("banner shown")


func _on_banner_ad_failed_to_load(ad_info: AdInfo, error_data: LoadAdError) -> void:
	var code := error_data.get_code() if error_data else -1
	var message := error_data.get_message() if error_data else "unknown"
	_set_status("banner load FAILED code=%s" % str(code))
	_append_log("banner_ad_failed_to_load code=%s msg=%s ad=%s" % [str(code), message, str(ad_info)])
	_banner_requested = false
	_request_banner_button.disabled = not ConsentGate.is_ads_allowed(_ads_decision)


func _on_banner_ad_impression(ad_info: AdInfo) -> void:
	_append_log("banner_ad_impression id=%s" % (ad_info.get_ad_id() if ad_info else ""))


func _apply_ump_snapshot(note: String) -> void:
	var native_snapshot: Dictionary = {}
	if Engine.has_singleton("AdmobPlugin"):
		native_snapshot = _admob.get_ump_consent_snapshot()
		if not native_snapshot.is_empty():
			_append_log(
				(
					"native_snapshot consent=%s(%s) can_request_ads=%s privacy=%s form=%s"
					% [
						str(native_snapshot.get("consent_status", "?")),
						str(native_snapshot.get("consent_status_code", "?")),
						str(native_snapshot.get("can_request_ads", "?")),
						str(native_snapshot.get("privacy_options_requirement_status", "?")),
						str(native_snapshot.get("is_consent_form_available", "?")),
					]
				)
			)

	_consent_status_text = _read_consent_status_text()
	_form_available = _admob.is_consent_form_available()
	_can_request_ads = false
	if Engine.has_singleton("AdmobPlugin"):
		_can_request_ads = _admob.can_request_ads()
	var privacy := _admob.get_privacy_options_requirement_status()
	_privacy_status_text = privacy.to_status_string() if privacy else "UNKNOWN"

	if not native_snapshot.is_empty():
		var native_can := bool(native_snapshot.get("can_request_ads", false))
		var native_status := str(native_snapshot.get("consent_status", ""))
		var native_privacy := str(native_snapshot.get("privacy_options_requirement_status", ""))
		if native_can != _can_request_ads or native_status != _consent_status_text or native_privacy != _privacy_status_text:
			_append_log(
				(
					"BRIDGE_MISMATCH native(can=%s status=%s privacy=%s) gdscript(can=%s status=%s privacy=%s)"
					% [
						str(native_can),
						native_status,
						native_privacy,
						str(_can_request_ads),
						_consent_status_text,
						_privacy_status_text,
					]
				)
			)

	_ads_decision = ConsentGate.evaluate(_consent_update_completed, _can_request_ads)
	_request_banner_button.disabled = (
		(not ConsentGate.is_ads_allowed(_ads_decision)) or _banner_requested
	)
	_privacy_options_button.disabled = (
		_privacy_status_text
		!= PrivacyOptionsRequirementStatus.status_to_string(
			PrivacyOptionsRequirementStatus.Status.REQUIRED
		)
	)
	_show_form_button.disabled = not (_form_available or _form_loaded)
	_set_status(
		(
			"%s | canRequestAds=%s privacy=%s decision=%s"
			% [note, str(_can_request_ads), _privacy_status_text, ConsentGate.decision_name(_ads_decision)]
		)
	)
	_refresh_gate_state(note)


func _read_consent_status_text() -> String:
	var consent := _admob.get_consent_status()
	if consent == null:
		return "UNKNOWN"
	return consent.to_status_string()


func _refresh_gate_state(note: String) -> void:
	_state.text = "\n".join(
		[
			"update_completed=%s update_ok=%s" % [str(_consent_update_completed), str(_consent_update_succeeded)],
			"consent_status=%s form_available=%s" % [_consent_status_text, str(_form_available)],
			"form_loaded=%s shown=%s dismissed=%s" % [str(_form_loaded), str(_form_shown), str(_form_dismissed)],
			"can_request_ads=%s privacy_options=%s" % [str(_can_request_ads), _privacy_status_text],
			"ads_decision=%s allowed=%s" % [ConsentGate.decision_name(_ads_decision), str(ConsentGate.is_ads_allowed(_ads_decision))],
			"sdk_initialized=%s banner_requested=%s" % [str(_sdk_initialized), str(_banner_requested)],
			"note=%s" % note,
		]
	)


func _set_status(text: String) -> void:
	_status.text = "Status: %s" % text
	print("[Phase0E] %s" % text)


func _append_log(text: String) -> void:
	var line := "[Phase0E] %s" % text
	print(line)
	_log.text = "%s\n%s" % [_log.text, line] if not _log.text.is_empty() else line
