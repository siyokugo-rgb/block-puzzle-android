class_name AdsConfig
extends RefCounted

## Phase 0-F ad unit configuration.
## Google test IDs remain for the Phase 0 regression spike only.
## Production IDs stay empty until deliberately configured later.

const GOOGLE_TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const GOOGLE_TEST_BANNER_UNIT_ID := "ca-app-pub-3940256099942544/9214589741"

const PRODUCTION_APP_ID := ""
const PRODUCTION_BANNER_UNIT_ID := ""


static func production_ids_configured() -> bool:
	return not PRODUCTION_APP_ID.is_empty() and not PRODUCTION_BANNER_UNIT_ID.is_empty()


static func resolve_banner_unit_id(use_test_ad_units: bool) -> String:
	if use_test_ad_units:
		return GOOGLE_TEST_BANNER_UNIT_ID
	return PRODUCTION_BANNER_UNIT_ID


static func can_request_banner(use_test_ad_units: bool) -> bool:
	return not resolve_banner_unit_id(use_test_ad_units).is_empty()
