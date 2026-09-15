extends Control

## Phase 0-F production baseline shell.
## No debug geography UI, no UMP test-device hash field, no spike log wall.
## Ads/consent logic lives in AdsConsentService. Game systems are not started here.

@onready var _title: Label = $Title
@onready var _status: Label = $Status
@onready var _hint: Label = $Hint
@onready var _update_button: Button = $Buttons/UpdateConsentButton
@onready var _privacy_button: Button = $Buttons/PrivacyOptionsButton
@onready var _banner_button: Button = $Buttons/RequestBannerButton
@onready var _admob: Admob = $Admob
@onready var _ads: AdsConsentService = $AdsConsentService


func _ready() -> void:
	_title.text = "Block Puzzle"
	_hint.text = (
		"Phase 0 production baseline.\n"
		+ "Regression spike: scenes/regression/phase0e_ump_spike.tscn\n"
		+ "Production AdMob IDs are not configured yet — ads stay blocked."
	)
	_privacy_button.disabled = true
	_banner_button.disabled = true
	_ads.use_test_ad_units = false
	_ads.bind_admob(_admob)
	_ads.state_changed.connect(_on_ads_state_changed)
	_ads.log_emitted.connect(_on_ads_log)
	_set_status("ready: run consent update before any ad request")


func _on_update_consent_button_pressed() -> void:
	var params := ConsentRequestParameters.new()
	params.set_is_real(true)
	_set_status("consent update starting (production path, no debug geography)")
	_ads.begin_consent_update(params)


func _on_privacy_options_button_pressed() -> void:
	_ads.show_privacy_options_form()


func _on_request_banner_button_pressed() -> void:
	if not AdsConfig.can_request_banner(false):
		_set_status("BLOCKED: production banner unit id not configured")
		return
	_ads.request_banner_if_allowed()


func _on_ads_state_changed(note: String) -> void:
	_privacy_button.disabled = not _ads.is_privacy_options_required()
	_banner_button.disabled = (
		(not _ads.is_ads_allowed())
		or _ads.banner_requested
		or not AdsConfig.can_request_banner(false)
	)
	_set_status(
		(
			"%s | canRequestAds=%s decision=%s privacy=%s"
			% [
				note,
				str(_ads.can_request_ads),
				ConsentGate.decision_name(_ads.ads_decision),
				_ads.privacy_status_text,
			]
		)
	)


func _on_ads_log(message: String) -> void:
	print("[AdsBaseline] %s" % message)


func _set_status(text: String) -> void:
	_status.text = "Status: %s" % text
	print("[Main] %s" % text)
