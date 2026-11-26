#!/usr/bin/env bash
# تجربة سريعة على محاكي أندرويد في CI: تثبيت التطبيق، فتحه، والتنقل بين الشاشات مع لقطات شاشة وسجل الأخطاء.
set -x
OUT=${OUT:-/tmp/smoke}
mkdir -p "$OUT"
APK=$1
PKG=com.murattil.quran
adb wait-for-device
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
adb install -r "$APK" || exit 1
adb logcat -c
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1
sleep 35

shot() { adb exec-out screencap -p > "$OUT/$1.png"; }
# بيدوّر على عنصر بالنص في شجرة الواجهة (Flutter بيعرض النصوص للـ accessibility) ويضغط عليه
tap_text() {
  adb shell rm -f /sdcard/ui.xml
  for _ in 1 2 3 4 5; do
    adb shell uiautomator dump --compressed /sdcard/ui.xml 2>&1 | grep -q "dumped to" && break
    sleep 3
  done
  adb pull /sdcard/ui.xml "$OUT/ui.xml" >/dev/null 2>&1 || : > "$OUT/ui.xml"
  local b
  b=$(python3 - "$OUT/ui.xml" "$1" <<'PY'
import re,sys
xml=open(sys.argv[1],encoding='utf-8').read(); t=sys.argv[2]
nodes=[]
for m in re.finditer(r'<node [^>]*>', xml):
    n=m.group(0)
    txt=re.search(r'text="([^"]*)"',n); cd=re.search(r'content-desc="([^"]*)"',n)
    labels=[x.strip() for x in ((txt.group(1) if txt else ''), (cd.group(1) if cd else '')) if x.strip()]
    b=re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',n)
    if b and labels: nodes.append((labels, tuple(map(int,b.groups()))))
# الأول: تطابق كامل (أو أول سطر من الوصف)، وبعدين: أقصر نص فيه الكلمة
exact=[b for l,b in nodes if any(x==t or x.split('\n')[0]==t for x in l)]
part=sorted([(min(len(x) for x in l if t in x),b) for l,b in nodes if any(t in x for x in l)])
pick=exact[0] if exact else (part[0][1] if part else None)
if pick:
    x1,y1,x2,y2=pick; print((x1+x2)//2,(y1+y2)//2)
PY
)
  if [ -n "$b" ]; then adb shell input tap $b; sleep 4; return 0; fi
  echo "tap_text: '$1' not found"; return 1
}

shot 01_onboarding
tap_text "تخطي" || adb shell input tap 100 150
sleep 5
shot 02_home
adb shell input swipe 540 2000 540 900 400; sleep 2
shot 03_home_scrolled
tap_text "المصحف"; shot 04_index
tap_text "سورة البقرة"; sleep 8; shot 05_mushaf
adb shell input swipe 200 1200 900 1200 300; sleep 6; shot 06_mushaf_next
adb shell input keyevent KEYCODE_BACK; sleep 3
tap_text "الأذكار"; sleep 2; shot 07_adhkar
tap_text "أذكار الصباح"; sleep 3; shot 08_adhkar_morning
adb shell input tap 540 1000; sleep 3; shot 08b_adhkar_next
adb shell input keyevent KEYCODE_BACK; sleep 2
tap_text "المسبحة"; sleep 3
for _ in 1 2 3 4 5 6 7; do adb shell input tap 540 1150; done; sleep 1; shot 08c_tasbih
adb shell input keyevent KEYCODE_BACK; sleep 2
tap_text "الصلاة"; shot 09_prayer
tap_text "المزيد"; shot 10_more
tap_text "الرئيسية"; sleep 2
adb shell input swipe 540 2000 540 700 400; sleep 2
tap_text "الاستماع"; sleep 3; shot 11_listen
tap_text "سورة الفاتحة"; sleep 10; shot 12_playing
adhb_tap() { :; }; adb shell input tap 825 2238
sleep 4; shot 13_now_playing

adb shell input keyevent KEYCODE_BACK; sleep 2

# موبايل صغير (٣٦٠×٦٤٠) وخط النظام كبير: التنسيق لازم يفضل سليم
adb shell wm size 720x1280
adb shell wm density 320
adb shell settings put system font_scale 1.3
adb shell am force-stop $PKG; sleep 2
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1; sleep 20
shot 20_small_home
tap_text "المصحف"; tap_text "سورة البقرة"; sleep 8; shot 21_small_mushaf
adb shell input tap 360 640; sleep 2; shot 22_small_mushaf_clean
adb shell input keyevent KEYCODE_BACK; sleep 2
tap_text "الأذكار"; sleep 2; shot 23_small_adhkar
tap_text "المسبحة"; sleep 3; shot 24_small_tasbih
adb shell wm size reset; adb shell wm density reset; adb shell settings put system font_scale 1.0

adb logcat -d > "$OUT/logcat.txt"
grep -E "flutter|FATAL|AndroidRuntime" "$OUT/logcat.txt" | grep -iE "error|exception|fatal|overflow" | head -200 > "$OUT/errors.txt"
echo "smoke done"
