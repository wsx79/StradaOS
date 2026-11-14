#!/bin/bash
PKG=com.stradaos.launcher.debug
ACT=$PKG/com.stradaos.launcher.Main
OUT=salida; mkdir -p $OUT
adb wait-for-device
for i in $(seq 1 100); do [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ] && break; sleep 3; done
sleep 10
adb shell input keyevent 82 || true
adb install -r -g prueba.apk | tail -1
adb shell mkdir -p /sdcard/Download
adb push malta.map /sdcard/Download/malta.map | tail -1
adb logcat -c
shot() { adb shell screencap -p /data/local/tmp/s.png >/dev/null 2>&1; adb pull /data/local/tmp/s.png "$OUT/$1.png" >/dev/null 2>&1; echo "captura $1"; }
go() { adb shell am start -n $ACT --es prueba "$1" >/dev/null; sleep "${2:-5}"; }
alive() { adb shell pidof $PKG >/dev/null 2>&1 && echo "vivo ($1)" || echo "*** CERRADO ($1) ***"; }
adb shell am start -n $ACT --es prueba saltar >/dev/null; sleep 20
go idioma:it 6; go tema:oscuro 6
# GPS que se mueve (Malta, La Valletta) con rumbo cambiante
( for i in $(seq 0 200); do
    lon=$(echo "14.5100 + $i*0.00008" | bc -l); lat=$(echo "35.8990 + $i*0.00005" | bc -l)
    adb emu geo fix $lon $lat 20 8 1 >/dev/null 2>&1; sleep 1; done ) &
GEO=$!
sleep 6; shot 1-norte; alive norte
echo "== sin archivo, rumbo:1 =="
go rumbo:1 10; shot 2-rumbo-online; alive rumbo-online
go mapa-mover 25; shot 3-rumbo-mover; alive mover
echo "== con archivo malta.map =="
go mapa-archivo:/sdcard/Download/malta.map 10; shot 4-rumbo-archivo; alive archivo
for z in 14 15 16 17; do go mapa-zoom:$z 12; shot 5-z$z; alive z$z; done
echo "== satelite =="
adb shell am start -n $ACT --es prueba ajustes:5 >/dev/null; sleep 4; adb shell input keyevent 4; sleep 2
sleep 20; alive final
kill $GEO 2>/dev/null
adb logcat -d > $OUT/logcat-completo.txt
grep -nE "FATAL|AndroidRuntime|OutOfMemory|Exception|ANR in|stradaos" $OUT/logcat-completo.txt | head -200 > $OUT/errores.txt
adb shell run-as $PKG cat files/fallos.txt > $OUT/fallos.txt 2>/dev/null
adb shell run-as $PKG ls -R files shared_prefs > $OUT/ls.txt 2>&1
cat $OUT/errores.txt | head -80
ls -l $OUT
