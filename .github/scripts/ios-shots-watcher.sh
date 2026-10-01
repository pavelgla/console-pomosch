#!/usr/bin/env bash
# Хост-сторона съёмки: ждёт от теста файлы req_<имя>, снимает кадр симулятора и кладёт ack_<имя>.
# Запись экрана включается с кадра 02 (вход, подключение, сеанс) и гасится по файлу done.
# Использование: ios-shots-watcher.sh <UDID> <каталог-обмена> <каталог-кадров> [<файл-видео>]
set -u
UDID="$1"; XCH="$2"; OUT="$3"; VIDEO="${4:-}"
mkdir -p "$XCH" "$OUT"
REC_PID=""
while [ ! -f "$XCH/done" ]; do
  for req in "$XCH"/req_*; do
    [ -e "$req" ] || continue
    name="${req##*/req_}"
    if [ ! -f "$XCH/ack_$name" ]; then
      if [ -n "$VIDEO" ] && [ -z "$REC_PID" ] && [ "$name" = "02-address-book" ]; then
        xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$VIDEO" >/dev/null 2>&1 &
        REC_PID=$!
        sleep 1
      fi
      xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png" >/dev/null 2>&1
      echo "кадр $name снят"
      touch "$XCH/ack_$name"
    fi
  done
  sleep 0.5
done
if [ -n "$REC_PID" ]; then kill -INT "$REC_PID" 2>/dev/null; wait "$REC_PID" 2>/dev/null; fi
echo "съёмка завершена"
