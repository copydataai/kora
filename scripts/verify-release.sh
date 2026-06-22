#!/usr/bin/env bash

set -euo pipefail

PROJECT="${1:-./kora.xcodeproj}"
SCHEME="${2:-kora}"
CONFIGURATION="${3:-Release}"
ARCHIVE_PATH="${4:-./build/kora.xcarchive}"
EXPORT_DIR="${5:-./build}"
EXPORT_OPTIONS="${6:-./exportOptions.plist}"

ARCHIVED_APP="${ARCHIVE_PATH}/Products/Applications/${SCHEME}.app"
INFO_PLIST="${ARCHIVED_APP}/Contents/Info.plist"
WIDGET_BUNDLE="${ARCHIVED_APP}/Contents/PlugIns/koraWidget.appex"

fail() {
  echo "❌ $1" >&2
  exit 1
}

pass() {
  echo "✅ $1"
}

need_file() {
  [[ -f "$1" ]] || fail "Missing required file: $1"
}

need_dir() {
  [[ -d "$1" ]] || fail "Missing required directory: $1"
}

echo "==> Scheme-friendly verification: ${SCHEME}"

xcodebuild -list -project "$PROJECT" >/tmp/kora-xcode-build-list.txt
if ! grep -qE "^[[:space:]]+${SCHEME}$" /tmp/kora-xcode-build-list.txt; then
  fail "Scheme '${SCHEME}' not found in ${PROJECT}"
fi
pass "Scheme '${SCHEME}' found in project"

need_file "$EXPORT_OPTIONS"
pass "Export options found: ${EXPORT_OPTIONS}"

echo "==> Archiving"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination "generic/platform=macOS" -archivePath "$ARCHIVE_PATH" archive
need_dir "$ARCHIVED_APP"
pass "Archive created: ${ARCHIVED_APP}"

if [[ ! -d "$WIDGET_BUNDLE" ]]; then
  fail "Widget bundle missing from archive: ${WIDGET_BUNDLE}"
fi
pass "Widget bundle embedded: koraWidget.appex"

need_file "$INFO_PLIST"

if ! /usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes' "$INFO_PLIST" >/tmp/kora-urltypes.txt 2>/dev/null; then
  fail "URL type block missing from ${INFO_PLIST}"
fi

if ! grep -q "kora" /tmp/kora-urltypes.txt; then
  fail "kora URL scheme not registered in ${INFO_PLIST}"
fi
pass "kora URL scheme registered in app bundle"

echo "==> Exporting"
mkdir -p "$EXPORT_DIR"
xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" -exportOptionsPlist "$EXPORT_OPTIONS" -exportPath "$EXPORT_DIR" >/tmp/kora-export.log
if [[ ! -d "${EXPORT_DIR}/${SCHEME}.app" ]]; then
  fail "Export did not produce ${EXPORT_DIR}/${SCHEME}.app"
fi
pass "Export produced ${EXPORT_DIR}/${SCHEME}.app"

echo "==> Source deep-link contract checks"
if ! grep -q "kora://rooms" "kora/koraApp.swift"; then
  fail "App URL handler no longer advertises kora://rooms"
fi
if ! grep -q "kora://room" "kora/koraApp.swift"; then
  fail "Room deep-link handling contract missing in app source"
fi
pass "Deep-link contract present in source"

echo "==> Optional runtime smoke checks (manual)"
echo "1) Launch app, open a room, and confirm widget-state.json updates."
echo "2) Open kora://rooms in browser/terminal to confirm rooms surface."
echo "3) Open kora://room/<id> and confirm target room opens."
echo "4) Tap widget action to confirm room resume path."

echo "Release verification complete."
