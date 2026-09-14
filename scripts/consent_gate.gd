class_name ConsentGate
extends RefCounted

## Phase 0-E spike gate for AdMob v7.0.
## Official canRequestAds() is NOT exposed by the plugin (see tooling/admob/UMP_API_AUDIT.md).
## This helper is fail-closed and never treats a local cache as authoritative.

enum AdsDecision {
	BLOCKED_NO_UPDATE,
	BLOCKED_UPDATE_FAILED,
	BLOCKED_CONSENT_REQUIRED,
	BLOCKED_CONSENT_UNKNOWN,
	ALLOWED_NOT_REQUIRED,
	ALLOWED_OBTAINED,
}


static func decision_name(decision: AdsDecision) -> String:
	return AdsDecision.keys()[decision]


static func is_ads_allowed(decision: AdsDecision) -> bool:
	return (
		decision == AdsDecision.ALLOWED_NOT_REQUIRED
		or decision == AdsDecision.ALLOWED_OBTAINED
	)


## Evaluate ads request permission from a live consent status + update outcome.
## `update_succeeded` must reflect the latest update_consent_info result only.
## On update failure we always fail-closed (no canRequestAds fallback available).
static func evaluate(update_succeeded: bool, status: UserConsent.Status) -> AdsDecision:
	if not update_succeeded:
		return AdsDecision.BLOCKED_UPDATE_FAILED

	match status:
		UserConsent.Status.NOT_REQUIRED:
			return AdsDecision.ALLOWED_NOT_REQUIRED
		UserConsent.Status.OBTAINED:
			return AdsDecision.ALLOWED_OBTAINED
		UserConsent.Status.REQUIRED:
			return AdsDecision.BLOCKED_CONSENT_REQUIRED
		UserConsent.Status.UNKNOWN:
			return AdsDecision.BLOCKED_CONSENT_UNKNOWN
		_:
			return AdsDecision.BLOCKED_CONSENT_UNKNOWN


static func initial_decision() -> AdsDecision:
	return AdsDecision.BLOCKED_NO_UPDATE
