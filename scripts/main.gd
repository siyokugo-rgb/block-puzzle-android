extends Control

## Phase 0-F production baseline shell + Phase R-F Score Attack child view.
## Keeps Admob / AdsConsentService / Privacy Options. Game state lives in PuzzleSession.

@onready var _title: Label = $Title
@onready var _status: Label = $Status
@onready var _privacy_button: Button = $Buttons/PrivacyOptionsButton
@onready var _admob: Admob = $Admob
@onready var _ads: AdsConsentService = $AdsConsentService
@onready var _game_container: Control = $GameContainer


func _ready() -> void:
	_title.text = "Block Puzzle"
	_privacy_button.disabled = true
	_ads.use_test_ad_units = false
	_ads.auto_request_banner = true
	_ads.bind_admob(_admob)
	_ads.state_changed.connect(_on_ads_state_changed)
	_ads.log_emitted.connect(_on_ads_log)
	_mount_game_view()
	_start_production_consent_update()


func _mount_game_view() -> void:
	for child in _game_container.get_children():
		child.queue_free()
	var view := PuzzleGameView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_container.add_child(view)


func _start_production_consent_update() -> void:
	var params := ConsentRequestParameters.new()
	params.set_is_real(true)
	# No debug geography and no test-device hash on the production path.
	_set_status("auto consent update starting (production path)")
	_ads.begin_consent_update(params)


func _on_privacy_options_button_pressed() -> void:
	_ads.show_privacy_options_form()


func _on_ads_state_changed(note: String) -> void:
	_privacy_button.disabled = not _ads.is_privacy_options_required()
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
	_status.text = "Ads: %s" % text
	print("[Main] %s" % text)
