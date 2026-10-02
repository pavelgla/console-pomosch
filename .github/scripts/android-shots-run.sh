#!/usr/bin/env bash
# Один прогон съёмки на запущенном эмуляторе (вызывается из android-emulator-runner).
# Секреты: SHOTS_USER, SHOTS_PASS, SHOTS_PEER_PASS в окружении.
set -uo pipefail
ROOT="$PWD"
OUT="$ROOT/shots"
mkdir -p "$OUT"
LOG="$OUT/test.log"
: > "$LOG"

adb wait-for-device
adb shell 'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done'
adb root || true
sleep 3
adb wait-for-device

# Русская локаль системы: без этого интерфейс на английском.
adb shell setprop persist.sys.locale ru-RU
adb shell setprop ctl.restart zygote
sleep 15
adb wait-for-device
adb shell 'while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done'
sleep 10
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
# Экран не должен гаснуть: сборка внутри `flutter test` идёт минуты, без этого кадры чёрные.
adb shell settings put system screen_off_timeout 2147483647
adb shell svc power stayon true
adb shell input keyevent KEYCODE_WAKEUP
adb shell wm dismiss-keyguard || true

# Чистый статус-бар: 09:41, полный заряд и сеть.
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command network -e mobile hide >/dev/null
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null

adb shell wm size; adb shell getprop persist.sys.locale

# Наблюдатель: тест кладёт маркеры в каталог данных приложения (adb root), по ним снимаем кадры и пишем видео.
MARKDIR=/data/user/0/com.carriez.flutter_hbb/app_flutter/shotreq
(
  seen=""
  for tick in $(seq 1 6000); do
    sleep 0.5
    list=$(adb shell "ls $MARKDIR 2>/dev/null" </dev/null | tr -d '\r')
    for m in $list; do
      case " $seen " in *" $m "*) continue ;; esac
      seen="$seen $m"
      kind="${m#*_}"
      case "$kind" in
        SHOT_*)
          name="${kind#SHOT_}"
          adb exec-out screencap -p </dev/null > "$OUT/$name.png" && echo "[watcher] снимок $name" >> "$OUT/watcher.log"
          adb shell dumpsys window </dev/null | grep -E "mCurrentFocus" >> "$OUT/watcher.log" 2>&1
          ;;
        VIDEOSTART)
          ( adb shell screenrecord --time-limit 70 --bit-rate 6000000 /sdcard/session.mp4 </dev/null >/dev/null 2>&1 & )
          echo "[watcher] видео старт" >> "$OUT/watcher.log"
          ;;
        VIDEOSTOP)
          adb shell pkill -2 screenrecord </dev/null || true
          echo "[watcher] видео стоп" >> "$OUT/watcher.log"
          ;;
        DONE) exit 0 ;;
      esac
    done
  done
) &
WATCH=$!

# Диагностика: раз в 20 с фокус окна и маленький снимок.
mkdir -p "$OUT/diag"
(
  for n in $(seq 1 45); do
    sleep 20
    echo "t$n $(date +%T) $(adb shell dumpsys window </dev/null | grep -E 'mCurrentFocus' | tr -d '\r')" >> "$OUT/diag/focus.log"
    adb exec-out screencap -p </dev/null > "$OUT/diag/t$n.png" 2>/dev/null
  done
) &
DIAG=$!

cd flutter
flutter test integration_test/android_screenshots_test.dart -d emulator-5554 \
  --dart-define=SHOTS_USER="$SHOTS_USER" \
  --dart-define=SHOTS_PASS="$SHOTS_PASS" \
  --dart-define=SHOTS_PEER_PASS="$SHOTS_PEER_PASS" 2>&1 | tee -a "$LOG"
RC=${PIPESTATUS[0]}
cd "$ROOT"

kill $DIAG 2>/dev/null
sleep 5
echo DONE >> "$LOG"
sleep 3; kill $WATCH 2>/dev/null || true
sleep 3
adb pull /sdcard/session.mp4 "$OUT/session.mp4" || true
adb exec-out screencap -p > "$OUT/zz-last.png" || true
adb logcat -d -s AndroidRuntime:E ActivityManager:I ActivityTaskManager:I flutter:I DEBUG:I libc:F 2>&1 | tail -400 > "$OUT/logcat-filtered.txt"
ls -la "$OUT"
python3 - <<'PY'
import struct, glob
for f in sorted(glob.glob("shots/*.png")):
    d = open(f, "rb").read(24)
    print(f, struct.unpack(">II", d[16:24]))
PY
exit $RC
