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
# إخفاء نوافذ «التطبيق لا يستجيب» بتاعة النظام (المحاكي أحيانًا بيبطّأ اللانشر)
adb shell settings put global hide_error_dialogs 1
sleep 20
adb shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS
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
# روابط الإذاعات: سلسلة التحويل والنوع
for u in https://stream.radiojar.com/8s5u5tpdtwzuv https://stream.radiojar.com/0tpy1h0kxtzuv https://qurango.net/radio/mahmoud_khalil_alhussary; do
  echo "== $u"; curl -sL --max-time 8 -o /dev/null -D - "$u" | grep -iE "^(HTTP|location|content-type)"
done > "$OUT/radio_urls.txt" 2>&1
# مميزات ١٫٥ — كل شاشة من فتحة جديدة للتطبيق (المحاكي في CI بيقع أحيانًا مع حركة الرجوع)
relaunch() { adb shell am force-stop $PKG; sleep 1; adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null; sleep 12; }
open_more() { relaunch; tap_text "المزيد"; sleep 1; tap_text "$1"; sleep "${2:-3}"; }
tap_text "المزيد"; sleep 2; shot 40_more
open_more "الحفظ"; shot 41_hifz
open_more "التقويم الهجري"; shot 45_calendar
open_more "حاسبة الزكاة"; shot 46_zakat
open_more "الأسماء الحسنى"; shot 47_asma
tap_text "الرحمن"; sleep 3; tap_text "ليلي"; sleep 1; shot 47b_share_asma
open_more "الأربعون النووية"; tap_text "إنما الأعمال بالنيات"; sleep 2; shot 48_nawawi
tap_text "مشاركة صورة"; sleep 3; shot 48b_share_hadith_square
tap_text "حالة واتساب"; sleep 2; shot 48c_share_hadith_story
open_more "الرقية الشرعية" 4; shot 49_ruqyah
open_more "رمضان"; shot 44_ramadan
adb shell input swipe 540 1800 540 500 400; sleep 1; shot 44b_ramadan_imsakiya
open_more "الإذاعات"; shot 42_radio
tap_text "إذاعة القرآن الكريم من القاهرة"; sleep 3; shot 43a_radio_connecting; sleep 10; shot 43_radio_playing
adb logcat -d | grep -iE "radio|ExoPlayer|Cleartext|HttpDataSource|flutter" | tail -40 > "$OUT/radio_log.txt"
# التفسير: الميسّر والسعدي وابن كثير (تحميل من النت)
relaunch; tap_text "المصحف"; tap_text "سورة البقرة"; sleep 6
adb shell input tap 540 1300; sleep 2; shot 50a_ayah_bar; tap_text "صورة"; sleep 3; shot 50b_share_ayah
tap_text "مصحف"; sleep 1; shot 50c_share_ayah_mushaf
adb shell input keyevent KEYCODE_BACK; sleep 2
adb shell input tap 540 1300; sleep 2; tap_text "تفسير"; sleep 3; shot 50_tafsir
tap_text "السعدي"; sleep 3; shot 51_tafsir_saadi
tap_text "ابن كثير"; sleep 10; shot 52_tafsir_ibnkathir
adb shell dumpsys appwidget > "$OUT/appwidget.txt" 2>&1
relaunch
tap_text "الرئيسية"
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

# الأذان: تشغيل منبّه الأذان مباشرة والتأكد إن الصوت شغال على مسار المنبّه
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS || true
adb shell media volume --stream 4 --set 2 || true
adb root >/dev/null 2>&1; sleep 4; adb wait-for-device
adb shell am broadcast -n $PKG/com.murattil.murattil.AdhanReceiver -a com.murattil.quran.ADHAN_ALARM --es sound adhan_egypt_refaat --es title "حان الآن موعد صلاة العصر" --es body test --ei volume 90
sleep 6
adb shell cmd statusbar expand-notifications; sleep 2; shot 30_adhan_notification
adb shell dumpsys audio > "$OUT/audio.txt" 2>&1
adb shell dumpsys media.audio_flinger > "$OUT/flinger.txt" 2>&1
adb shell cmd statusbar collapse
adb shell am broadcast -n $PKG/com.murattil.murattil.AdhanReceiver -a com.murattil.quran.ADHAN_STOP; sleep 3
adb shell dumpsys audio | grep -iE "STREAM_ALARM" -A4 | head -20 > "$OUT/alarm_after.txt" 2>&1

adb logcat -d > "$OUT/logcat.txt"
grep -E "flutter|FATAL|AndroidRuntime|AdhanService|murattil" "$OUT/logcat.txt" | grep -iE "error|exception|fatal|overflow" | head -200 > "$OUT/errors.txt"
echo "smoke done"
