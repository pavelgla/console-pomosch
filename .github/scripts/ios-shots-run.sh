#!/usr/bin/env bash
# Один прогон съёмки на одном симуляторе. Использование: ios-shots-run.sh <UDID> <iphone|ipad>
set -euo pipefail
UDID="$1"; KIND="$2"
ROOT="$PWD"
XCH="$RUNNER_TEMP/xch-$KIND"
OUT="$ROOT/shots/$KIND"
rm -rf "$XCH"; mkdir -p "$XCH" "$OUT"

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3 --operatorName ""
xcrun simctl ui "$UDID" appearance light || true

VIDEO=""
[ "$KIND" = iphone ] && VIDEO="$OUT/session-recording.mp4"
bash "$ROOT/.github/scripts/ios-shots-watcher.sh" "$UDID" "$XCH" "$OUT" "$VIDEO" &
WATCH=$!

set +e
cd flutter
flutter test integration_test/screenshots_test.dart -d "$UDID" \
  --dart-define=SHOT_DIR="$XCH" \
  --dart-define=SHOTS_USER="$SHOTS_USER" \
  --dart-define=SHOTS_PASS="$SHOTS_PASS" \
  --dart-define=SHOTS_PEER_PASS="$SHOTS_PEER_PASS" 2>&1 | tee "$RUNNER_TEMP/test-$KIND.log"
RC=${PIPESTATUS[0]}
set -e
cd "$ROOT"

touch "$XCH/done"
wait "$WATCH" || true
cp "$RUNNER_TEMP/test-$KIND.log" "$OUT/test.log"
xcrun simctl shutdown "$UDID" || true
ls -la "$OUT"
for f in "$OUT"/*.png; do sips -g pixelWidth -g pixelHeight "$f" | tail -2 | tr '\n' ' '; echo "$f"; done
exit $RC
