#!/usr/bin/env bash
# Подпись Developer ID, dmg и нотаризация macOS-сборки (w-all-platforms).
#
#   sign-notarize.sh <ConsoleHelp.app> <dmg-out> <identity> <entitlements> <notary-json>
#
# Подпись изнутри наружу: сначала каждый вложенный Mach-O, потом вложенные бандлы, потом само
# приложение с entitlements. `codesign --deep` для этого не годится: вложенные библиотеки он
# подписывает ненадёжно и без hardened runtime, нотаризация такое отклоняет.
# <notary-json> — ключ App Store Connect в формате rcodesign (issuer_id, key_id, private_key).
set -euo pipefail

APP="$1" DMG="$2" IDENTITY="$3" ENT="$4" NOTARY_JSON="$5"
MAIN_EXE="$APP/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")"

sign() { codesign --force --options runtime --timestamp -s "$IDENTITY" "$@"; }

# Глубже — раньше: родитель подписывается после всего, что лежит внутри него.
by_depth() { awk -F/ '{print NF"\t"$0}' | sort -rn | cut -f2-; }

echo "== Mach-O внутри бандла"
find "$APP/Contents" -type f ! -path "$MAIN_EXE" -print0 \
  | while IFS= read -r -d '' f; do if file -b "$f" | grep -q 'Mach-O'; then printf '%s\n' "$f"; fi; done \
  | by_depth | while IFS= read -r f; do sign "$f"; done

echo "== вложенные бандлы"
find "$APP/Contents" -type d \( -name '*.framework' -o -name '*.app' -o -name '*.xpc' -o -name '*.bundle' \) \
  | by_depth | while IFS= read -r b; do sign "$b"; done

echo "== приложение"
sign --entitlements "$ENT" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q 'allow-jit' \
  || { echo "entitlements не попали в подпись" >&2; exit 1; }

echo "== dmg"
rm -f "$DMG"
create-dmg --icon "$(basename "$APP")" 200 190 --hide-extension "$(basename "$APP")" \
  --window-size 800 400 --app-drop-link 600 185 "$DMG" "$APP"
codesign --force --timestamp -s "$IDENTITY" "$DMG"

echo "== нотаризация"
# Сеть до appstoreconnect.apple.com с раннера рвётся (16.10: os error 60 при опросе статуса).
# Повторная отправка того же dmg безопасна: Apple выдаст тикет на тот же cdhash.
for try in 1 2 3; do
  if rcodesign notary-submit --api-key-path "$NOTARY_JSON" --wait --staple "$DMG"; then break; fi
  [ "$try" -lt 3 ] || { echo "нотаризация не прошла за 3 попытки" >&2; exit 1; }
  echo "нотаризация: попытка $try не удалась, повтор через 30 с" >&2
  sleep 30
done
xcrun stapler validate "$DMG"
