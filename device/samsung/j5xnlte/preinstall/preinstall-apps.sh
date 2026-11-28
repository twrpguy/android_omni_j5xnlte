#!/system/bin/sh
# Install the bundled apps in /system/preinstall once, as normal user apps
# (updatable and uninstallable). An app that fails is retried on the next boot.
DONE=/data/system/preinstall.done
LOG=/cache/bootlog/preinstall.txt
for f in /system/preinstall/*.apk.pre; do
  [ -f "$f" ] || continue
  n=$(basename "$f" .apk.pre)
  grep -qx "$n" "$DONE" 2>/dev/null && continue
  t=/data/local/tmp/preinstall-$n.apk
  cp "$f" "$t" && chmod 644 "$t"
  r=$(pm install -r "$t" 2>&1)
  echo "$n: $r" >> "$LOG"
  case "$r" in *Success*) echo "$n" >> "$DONE" ;; esac
  rm -f "$t"
done
