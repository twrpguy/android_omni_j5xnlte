#!/system/bin/sh
# Writes boot logs to /cache/bootlog. The previous boot's logs are kept as *.prev.txt.
D=/cache/bootlog
mkdir -p $D
# Write synchronously so logs survive a sudden reboot
mount -o remount,sync /cache
for f in kmsg logcat; do
  [ -f $D/$f.txt ] && mv -f $D/$f.txt $D/$f.prev.txt
done
cat /proc/last_kmsg > $D/last_kmsg.txt 2>/dev/null
cat /sys/fs/pstore/console-ramoops > $D/pstore.txt 2>/dev/null
getprop > $D/props.txt
logcat -b all -v threadtime -f $D/logcat.txt -r 4096 -n 2 &
# /dev/kmsg streams the whole kernel log (from boot) and keeps following it
exec cat /dev/kmsg > $D/kmsg.txt
