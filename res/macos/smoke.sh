#!/usr/bin/env bash
# Смоук подписанного dmg на macOS-раннере — замена живого Mac (решение Павла 16.10).
#
#   smoke.sh <dmg>
#
# 1) Gatekeeper принимает приложение как нотаризованное — та же оценка, что при двойном клике;
# 2) тикет нотаризации пришит к dmg (работает без сети);
# 3) клиент под hardened runtime стартует, не падает и регистрируется на rs.console10.ru.
#    Доказательство регистрации — key_confirmed = true в конфиге: клиент пишет его только по
#    RegisterPkResponse OK от hbbs. keep_alive в ответ наш hbbs 1.1.16 не кладёт (16.10, run 38930813170).
# Права TCC (запись экрана, универсальный доступ) раннеру не выдать — управление не проверяется.
set -euo pipefail

DMG="$1"
HOST="rs.console10.ru"
MNT=$(mktemp -d)
LOGDIR="$HOME/Library/Logs/ConsoleHelp"
PID=""

# shellcheck disable=SC2317  # вызывается из trap
cleanup() { if [ -n "$PID" ]; then kill "$PID" 2>/dev/null || true; fi; hdiutil detach "$MNT" -quiet 2>/dev/null || true; }
trap cleanup EXIT

xcrun stapler validate "$DMG"
hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MNT" -quiet
APP=$(find "$MNT" -maxdepth 1 -name '*.app' | head -1)
[ -n "$APP" ] || { echo "в dmg нет .app" >&2; exit 1; }

assess=$(spctl -a -vv -t exec "$APP" 2>&1 || true)
echo "$assess"
echo "$assess" | grep -q 'accepted' || { echo "Gatekeeper отклонил приложение" >&2; exit 1; }
echo "$assess" | grep -q 'Notarized Developer ID' || { echo "источник не Notarized Developer ID" >&2; exit 1; }

EXE="$APP/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")"
CFGDIR="$HOME/Library/Preferences/com.carriez.ConsoleHelp"
CFG="$CFGDIR/ConsoleHelp.toml"
# чистый старт: у раннеров общий аппаратный UUID, hbbs ответит UUID_MISMATCH, клиент сменит ID — это штатно
rm -rf "$LOGDIR" "$CFGDIR"
"$EXE" --server >"$MNT.out" 2>&1 &
PID=$!

ok=""
for _ in $(seq 1 30); do
  sleep 2
  kill -0 "$PID" 2>/dev/null || { echo "клиент завершился:" >&2; tail -40 "$MNT.out" >&2; exit 1; }
  if grep -qs '^key_confirmed = true' "$CFG" && grep -rqs "start rendezvous mediator of $HOST" "$LOGDIR"; then ok=1; break; fi
done
echo "--- лог клиента, без повторов ipc_service"
grep -rh "" "$LOGDIR" 2>/dev/null | grep -v 'failed to connect to ipc_service' | tail -40 || true
if grep -rqis 'panic' "$LOGDIR" "$MNT.out"; then echo "в логе panic" >&2; exit 1; fi
[ -n "$ok" ] || { echo "нет регистрации на $HOST за 60 с (key_confirmed не true в $CFG)" >&2; exit 1; }
echo "смоук ок: Gatekeeper принял, тикет пришит, клиент зарегистрирован на $HOST (ID $(grep -rhoE 'Generated id [0-9]+|id updated from [0-9]+ to [0-9]+' "$LOGDIR" | tail -1 | grep -oE '[0-9]+$'))"
