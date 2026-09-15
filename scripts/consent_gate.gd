class_name ConsentGate
extends RefCounted

## Phase 0-E.1 ads gate.
## Final ads-request authority is native UMP ConsentInformation.canRequestAds(),
## exposed as Admob.can_request_ads(). Consent status remains diagnostic only.

enum AdsDecision {
	BLOCKED_PRE_UPDATE,
	BLOCKED_CANNOT_REQUEST_ADS,
	ALLOWED_CAN_REQUEST_ADS,
}


static func decision_name(decision: AdsDecision) -> String:
	return AdsDecision.keys()[decision]


static func is_ads_allowed(decision: AdsDecision) -> bool:
	return decision == AdsDecision.ALLOWED_CAN_REQUEST_ADS


## `update_completed` is true only after update success OR failure callback.
## Before any update completes, ads stay blocked even if can_request_ads is true.
static func evaluate(update_completed: bool, can_request_ads: bool) -> AdsDecision:
	if not update_completed:
		return AdsDecision.BLOCKED_PRE_UPDATE
	if can_request_ads:
		return AdsDecision.ALLOWED_CAN_REQUEST_ADS
	return AdsDecision.BLOCKED_CANNOT_REQUEST_ADS


static func initial_decision() -> AdsDecision:
	return AdsDecision.BLOCKED_PRE_UPDATE


## Allowed → blocked means any already-shown / in-flight banner must be removed.
static func should_cleanup_on_decision_change(was_allowed: bool, now_allowed: bool) -> bool:
	return was_allowed and not now_allowed


## While blocked, a still-tracked or plugin-cached banner must be removed
## (covers reset, stuck display, and delayed load races).
static func should_cleanup_active_banner(now_allowed: bool, has_active_banner: bool) -> bool:
	return (not now_allowed) and has_active_banner


## Delayed banner_ad_loaded after gate blocked: never show; discard via remove.
static func should_discard_loaded_banner(now_allowed: bool) -> bool:
	return not now_allowed
