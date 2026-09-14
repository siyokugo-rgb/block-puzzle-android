extends GutTest

## Phase 0-E: fail-closed consent gate without official canRequestAds API.


func test_phase0e_initial_decision_is_blocked() -> void:
	var decision := ConsentGate.initial_decision()
	assert_eq(decision, ConsentGate.AdsDecision.BLOCKED_NO_UPDATE)
	assert_false(ConsentGate.is_ads_allowed(decision))


func test_phase0e_update_failure_is_fail_closed() -> void:
	var decision := ConsentGate.evaluate(false, UserConsent.Status.OBTAINED)
	assert_eq(decision, ConsentGate.AdsDecision.BLOCKED_UPDATE_FAILED)
	assert_false(ConsentGate.is_ads_allowed(decision))


func test_phase0e_required_blocks_ads() -> void:
	var decision := ConsentGate.evaluate(true, UserConsent.Status.REQUIRED)
	assert_eq(decision, ConsentGate.AdsDecision.BLOCKED_CONSENT_REQUIRED)
	assert_false(ConsentGate.is_ads_allowed(decision))


func test_phase0e_unknown_after_update_blocks_ads() -> void:
	var decision := ConsentGate.evaluate(true, UserConsent.Status.UNKNOWN)
	assert_eq(decision, ConsentGate.AdsDecision.BLOCKED_CONSENT_UNKNOWN)
	assert_false(ConsentGate.is_ads_allowed(decision))


func test_phase0e_not_required_allows_ads() -> void:
	var decision := ConsentGate.evaluate(true, UserConsent.Status.NOT_REQUIRED)
	assert_eq(decision, ConsentGate.AdsDecision.ALLOWED_NOT_REQUIRED)
	assert_true(ConsentGate.is_ads_allowed(decision))


func test_phase0e_obtained_allows_ads() -> void:
	var decision := ConsentGate.evaluate(true, UserConsent.Status.OBTAINED)
	assert_eq(decision, ConsentGate.AdsDecision.ALLOWED_OBTAINED)
	assert_true(ConsentGate.is_ads_allowed(decision))


func test_phase0e_auto_start_ads_disabled() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	assert_true(src.find("SPIKE_AUTO_START_ADS := false") >= 0)
	assert_true(src.find("SPIKE_AUTO_START_ADS := true") < 0)


func test_phase0e_uses_google_test_ids_only() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	assert_true(src.find("ca-app-pub-3940256099942544~3347511713") >= 0)
	assert_true(src.find("ca-app-pub-3940256099942544/9214589741") >= 0)
