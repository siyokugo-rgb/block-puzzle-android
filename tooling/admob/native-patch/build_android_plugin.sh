#!/usr/bin/env bash
# Rebuild godot-admob v7.0 Android AARs with the Phase 0-E.1 UMP patch.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="${PATCH_DIR}/godot-admob-v7.0-ump-current.patch"

UPSTREAM_URL="${ADMOB_UPSTREAM_URL:-https://github.com/godot-sdk-integrations/godot-admob.git}"
UPSTREAM_TAG="${ADMOB_UPSTREAM_TAG:-v7.0}"
UPSTREAM_SHA="${ADMOB_UPSTREAM_SHA:-4b4ddceab0be81f0dcb12a6313038dba6cf9eacf}"

WORK_ROOT="${ADMOB_WORK_ROOT:-/tmp/godot-admob-v70-rebuild}"
SRC_DIR="${ADMOB_SRC_DIR:-${WORK_ROOT}/src}"

DEST_DEBUG="${ROOT_DIR}/addons/AdmobPlugin/bin/debug/AdmobPlugin-debug.aar"
DEST_RELEASE="${ROOT_DIR}/addons/AdmobPlugin/bin/release/AdmobPlugin-release.aar"

if [[ -z "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}" ]]; then
	echo "ERROR: set ANDROID_HOME or ANDROID_SDK_ROOT" >&2
	exit 1
fi
ANDROID_SDK="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"

echo "==> Upstream ${UPSTREAM_URL}"
echo "==> Tag ${UPSTREAM_TAG} / SHA ${UPSTREAM_SHA}"
echo "==> Source dir ${SRC_DIR}"

mkdir -p "${WORK_ROOT}"
if [[ ! -d "${SRC_DIR}/.git" ]]; then
	git clone --filter=blob:none "${UPSTREAM_URL}" "${SRC_DIR}"
fi

git -C "${SRC_DIR}" fetch --tags origin
git -C "${SRC_DIR}" checkout --force "${UPSTREAM_SHA}"
git -C "${SRC_DIR}" reset --hard "${UPSTREAM_SHA}"
git -C "${SRC_DIR}" clean -fdx

ACTUAL_SHA="$(git -C "${SRC_DIR}" rev-parse HEAD)"
if [[ "${ACTUAL_SHA}" != "${UPSTREAM_SHA}" ]]; then
	echo "ERROR: expected ${UPSTREAM_SHA}, got ${ACTUAL_SHA}" >&2
	exit 1
fi

echo "==> Applying ${PATCH_FILE}"
git -C "${SRC_DIR}" apply --check "${PATCH_FILE}"
git -C "${SRC_DIR}" apply "${PATCH_FILE}"

echo "sdk.dir=${ANDROID_SDK}" > "${SRC_DIR}/local.properties"
echo "sdk.dir=${ANDROID_SDK}" > "${SRC_DIR}/common/local.properties"
echo "sdk.dir=${ANDROID_SDK}" > "${SRC_DIR}/android/local.properties"

echo "==> Building Android debug AAR"
(
	cd "${SRC_DIR}"
	./script/build.sh -a -- -cb
)

echo "==> Building Android release AAR"
(
	cd "${SRC_DIR}"
	./script/build.sh -a -- -cbr
)

SRC_DEBUG="${SRC_DIR}/common/build/plugin/android/addons/AdmobPlugin/bin/debug/AdmobPlugin-debug.aar"
SRC_RELEASE="${SRC_DIR}/common/build/plugin/android/addons/AdmobPlugin/bin/release/AdmobPlugin-release.aar"

if [[ ! -f "${SRC_DEBUG}" || ! -f "${SRC_RELEASE}" ]]; then
	echo "ERROR: expected AAR outputs missing" >&2
	ls -la "${SRC_DIR}/common/build/plugin/android/addons/AdmobPlugin/bin/" || true
	exit 1
fi

mkdir -p "$(dirname "${DEST_DEBUG}")" "$(dirname "${DEST_RELEASE}")"
cp -f "${SRC_DEBUG}" "${DEST_DEBUG}"
cp -f "${SRC_RELEASE}" "${DEST_RELEASE}"

echo "==> Installed AARs"
sha256sum "${DEST_DEBUG}" "${DEST_RELEASE}"

echo "==> Public method smoke check (debug AAR)"
TMP_AAR="$(mktemp -d)"
unzip -qo "${DEST_DEBUG}" -d "${TMP_AAR}"
javap -classpath "${TMP_AAR}/classes.jar" -public org.godotengine.plugin.admob.AdmobPlugin \
	| rg "can_request_ads|get_privacy_options_requirement_status|show_privacy_options_form|get_ump_consent_snapshot" \
	|| {
		echo "ERROR: expected public methods not found in AAR" >&2
		exit 1
	}
rm -rf "${TMP_AAR}"

echo "OK: patched v7.0 AARs ready"
