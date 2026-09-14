extends Control

## Phase 0-D Technical Spike: AdMob Test Banner feasibility.
## Not production ads. Not UMP. Do not treat boot-time unconditional init as final design.
## Phase 0-E will own: consent → optional form → whether ads SDK may run.

const SAMPLE_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const ANCHORED_ADAPTIVE_BANNER_TEST_UNIT_ID := "ca-app-pub-3940256099942544/9214589741"

## Spike-only: auto-run after scene ready so a headless/manual device smoke can observe logs.
## Explicitly NOT a production boot contract. Flip false to require the Init button only.
const SPIKE_AUTO_START_ADS := true

@onready var _title: Label = $Title
@onready var _status: Label = $Status
@onready var _log: Label = $Log
@onready var _tap_counter: Label = $TapCounter
@onready var _init_button: Button = $Buttons/InitButton
@onready var _load_button: Button = $Buttons/LoadButton
@onready var _show_button: Button = $Buttons/ShowButton
@onready var _tap_button: Button = $Buttons/TapButton
@onready var _admob: Admob = $Admob

var _tap_count: int = 0
var _last_banner_ad_id: String = ""
var _sdk_initialized: bool = false


func _ready() -> void:
	_title.text = "Phase 0-D AdMob Test Banner"
	_set_status("idle: waiting for explicit spike init (not production boot path)")
	_append_log("plugin present=%s platform=%s" % [Engine.has_singleton("AdmobPlugin"), OS.get_name()])
	_load_button.disabled = true
	_show_button.disabled = true

	_admob.initialization_completed.connect(_on_initialization_completed)
	_admob.banner_ad_loaded.connect(_on_banner_ad_loaded)
	_admob.banner_ad_failed_to_load.connect(_on_banner_ad_failed_to_load)
	_admob.banner_ad_impression.connect(_on_banner_ad_impression)

	if SPIKE_AUTO_START_ADS:
		# Deferred so first frame UI remains interactive during load.
		call_deferred("_spike_start_ads")


func _spike_start_ads() -> void:
	_request_initialize()


func _on_init_button_pressed() -> void:
	_request_initialize()


func _on_load_button_pressed() -> void:
	_request_load_banner()


func _on_show_button_pressed() -> void:
	_request_show_banner()


func _on_tap_button_pressed() -> void:
	_tap_count += 1
	_tap_counter.text = "UI taps while ads load/show: %d" % _tap_count
	_append_log("ui still interactive (tap=%d)" % _tap_count)


func _request_initialize() -> void:
	_set_status("initializing SDK (spike)...")
	_append_log("initialize() called is_real=%s app_id=%s" % [str(_admob.is_real), SAMPLE_APP_ID])
	if not Engine.has_singleton("AdmobPlugin"):
		_set_status("FAIL: AdmobPlugin singleton missing (desktop OK; Android needs AAR)")
		_append_log("compare issue #124 if Android also missing singleton / AAR")
		return
	_admob.initialize()


func _request_load_banner() -> void:
	if not _sdk_initialized:
		_set_status("blocked: initialize first")
		return
	_set_status("loading anchored adaptive test banner...")
	_append_log("load_banner unit=%s size=ADAPTIVE pos=BOTTOM" % ANCHORED_ADAPTIVE_BANNER_TEST_UNIT_ID)
	var request: LoadAdRequest = _admob.create_banner_ad_request()
	request.set_ad_unit_id(ANCHORED_ADAPTIVE_BANNER_TEST_UNIT_ID)
	request.set_ad_size(LoadAdRequest.RequestedAdSize.ADAPTIVE)
	request.set_ad_position(LoadAdRequest.AdPosition.BOTTOM)
	_admob.load_banner_ad(request)


func _request_show_banner() -> void:
	if _last_banner_ad_id.is_empty():
		_set_status("blocked: no loaded banner id")
		return
	_set_status("showing banner id=%s" % _last_banner_ad_id)
	_append_log("show_banner_ad(%s)" % _last_banner_ad_id)
	_admob.show_banner_ad(_last_banner_ad_id)


func _on_initialization_completed(status_data: InitializationStatus) -> void:
	_sdk_initialized = true
	_load_button.disabled = false
	var tags: Array = status_data.get_network_tags() if status_data else []
	_set_status("SDK initialization completed networks=%d" % tags.size())
	_append_log("initialization_completed tags=%s" % str(tags))
	# Spike convenience: load banner after init without requiring a second tap.
	_request_load_banner()


func _on_banner_ad_loaded(ad_info: AdInfo, _response_info: ResponseInfo) -> void:
	_last_banner_ad_id = ad_info.get_ad_id() if ad_info else ""
	_show_button.disabled = _last_banner_ad_id.is_empty()
	_set_status("banner loaded id=%s" % _last_banner_ad_id)
	_append_log("banner_ad_loaded")
	_request_show_banner()


func _on_banner_ad_failed_to_load(ad_info: AdInfo, error_data: LoadAdError) -> void:
	var code := error_data.get_code() if error_data else -1
	var message := error_data.get_message() if error_data else "unknown"
	_set_status("banner load FAILED code=%s" % str(code))
	_append_log("banner_ad_failed_to_load code=%s msg=%s ad=%s" % [str(code), message, str(ad_info)])


func _on_banner_ad_impression(ad_info: AdInfo) -> void:
	_append_log("banner_ad_impression id=%s" % (ad_info.get_ad_id() if ad_info else ""))


func _set_status(text: String) -> void:
	_status.text = "Status: %s" % text
	print("[Phase0D] %s" % text)


func _append_log(text: String) -> void:
	var line := "[Phase0D] %s" % text
	print(line)
	_log.text = "%s\n%s" % [_log.text, line] if not _log.text.is_empty() else line
