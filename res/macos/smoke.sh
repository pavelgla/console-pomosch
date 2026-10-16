#!/usr/bin/env bash
# Смоук подписанного dmg на macOS-раннере — замена живого Mac (решение Павла 16.10).
#
#   smoke.sh <dmg>
#
# 1) Gatekeeper принимает приложение как нотаризованное — та же оценка, что при двойном клике;
# 2) тикет нотаризации пришит к dmg (работает без сети);
# 3) клиент под hardened runtime стартует, не падает и регистрируется на rs.console10.ru.
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

# run_server <фаза>: запускает --server, ждёт регистрации до 60 с; 0 — keep_alive от hbbs получен
run_server() {
  rm -rf "$LOGDIR"
  "$EXE" --server >"$MNT.out" 2>&1 &
  PID=$!
  local ok=1
  for _ in $(seq 1 30); do
    sleep 2
    kill -0 "$PID" 2>/dev/null || { echo "клиент завершился ($1):" >&2; tail -40 "$MNT.out" >&2; exit 1; }
    if grep -rqs "keep_alive:" "$LOGDIR" && grep -rqs "start rendezvous mediator of $HOST" "$LOGDIR"; then ok=0; break; fi
  done
  echo "--- лог клиента ($1), без повторов ipc_service"
  grep -rh "" "$LOGDIR" 2>/dev/null | grep -v 'failed to connect to ipc_service' | tail -40 || true
  if grep -rqis 'panic' "$LOGDIR" "$MNT.out"; then echo "в логе panic ($1)" >&2; exit 1; fi
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
  PID=""
  return $ok
}

if run_server udp; then
  echo "смоук ок: Gatekeeper принял, тикет пришит, клиент зарегистрирован на $HOST по UDP"
  exit 0
fi

# Раннеры GitHub (macOS) могут резать исходящий UDP; TCP до $HOST при этом есть.
# Повтор по TCP проверяет то же самое для подписанного бинарника: старт под hardened runtime,
# сеть, протокол регистрации. UDP на раннере в этом случае не проверен — пишем это явно.
CFG2=$(find "$HOME/Library/Preferences" -name 'ConsoleHelp2.toml' 2>/dev/null | head -1)
if [ -z "$CFG2" ]; then
  CFG1=$(find "$HOME/Library/Preferences" -name 'ConsoleHelp.toml' 2>/dev/null | head -1)
  [ -n "$CFG1" ] || { echo "нет регистрации по UDP, конфиг клиента не найден" >&2; exit 1; }
  CFG2="$(dirname "$CFG1")/ConsoleHelp2.toml"
  : >"$CFG2"
fi
echo "UDP: нет keep_alive за 60 с; повтор по TCP (disable-udp=Y в $CFG2)"
if grep -q '^\[options\]' "$CFG2"; then
  awk '{ print } /^\[options\]$/ { print "disable-udp = '"'"'Y'"'"'" }' "$CFG2" >"$CFG2.new" && mv "$CFG2.new" "$CFG2"
else
  printf "\n[options]\ndisable-udp = 'Y'\n" >>"$CFG2"
fi

if run_server tcp; then
  echo "смоук ок: Gatekeeper принял, тикет пришит, клиент зарегистрирован на $HOST по TCP (UDP с раннера не проверен)"
  exit 0
fi
echo "нет регистрации на $HOST ни по UDP, ни по TCP (нет keep_alive от hbbs)" >&2
exit 1
