#!/bin/bash
# Replace the J500 (Marshmallow) libsec-ril with the one from the J510FN's own
# latest stock firmware, so it matches the modem firmware (J510FNXXS3BTI1).
# Downloads from Samsung's update servers with samloader-rs.
# Run from the source top after sync. Never fails the build: if anything goes
# wrong the old RIL stays in place.
set -u
MODEL=SM-J510FN
REGIONS="DBT XEO BTU ITV PHE XEF NEE ATO AUT TPH SEB"
WORK=${STOCK_WORK:-$PWD/../stock-fw}
DEST=vendor/samsung-j5x/j5xnlte/proprietary/lib
EXTRA_MK=device/samsung/j5xnlte/stock-ril.mk
mkdir -p "$WORK"
: > "$EXTRA_MK"

say() { echo ">> $*"; }
fail() { say "stock RIL: $* - keeping the J500 libsec-ril"; exit 0; }

command -v samloader >/dev/null || cargo install --quiet samloader || fail "could not install samloader"

ver="" ; region=""
for r in $REGIONS; do
  v=$(samloader -m "$MODEL" -r "$r" check 2>/dev/null | tail -1)
  if [ -n "$v" ]; then ver=$v; region=$r; break; fi
done
[ -n "$ver" ] || fail "no firmware found for $MODEL"
say "stock firmware $ver ($region)"

cd "$WORK" || fail "no work dir"
samloader -m "$MODEL" -r "$region" download >/dev/null 2>&1 || fail "download failed"
zip=$(ls -S *.zip 2>/dev/null | head -1)
[ -n "$zip" ] || fail "no firmware zip"
unzip -o -q "$zip" 'AP_*' || fail "no AP file in $zip"
ap=$(ls AP_*.tar.md5 AP_*.tar 2>/dev/null | head -1)
tar -xf "$ap" --wildcards 'system.img*' || fail "no system image in $ap"
img=$(ls system.img* | head -1)
case "$img" in *.lz4) lz4 -dq "$img" system.sparse && img=system.sparse ;; esac
simg2img "$img" system.raw 2>/dev/null || cp "$img" system.raw
debugfs -R "ls -l /lib/libsec-ril.so" system.raw 2>/dev/null | grep -q libsec-ril || fail "libsec-ril.so not in stock system"

mkdir -p out
for f in libsec-ril.so libsec-ril-dsds.so; do
  debugfs -R "dump /lib/$f out/$f" system.raw >/dev/null 2>&1
done
[ -s out/libsec-ril.so ] || fail "could not extract libsec-ril.so"

# Pull Samsung-only libraries the stock RIL links against (never AOSP/Qualcomm ones
# the ROM already builds or ships).
keep_re='^lib(sec|omission|factory|ril_sem|vendorsemril|secnativefeature|SecRil|sec_)'
for lib in $(readelf -d out/libsec-ril*.so 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' | sort -u); do
  echo "$lib" | grep -Eq "$keep_re" || continue
  case "$lib" in libsec-ril.so|libsec-ril-dsds.so) continue ;; esac
  if debugfs -R "dump /lib/$lib out/$lib" system.raw >/dev/null 2>&1 && [ -s "out/$lib" ]; then
    echo "PRODUCT_COPY_FILES += vendor/samsung-j5x/stock/$lib:system/lib/$lib" >> "$OLDPWD/$EXTRA_MK"
    say "  + dependency $lib"
  fi
done
cd - >/dev/null

mkdir -p vendor/samsung-j5x/stock
cp "$WORK"/out/*.so vendor/samsung-j5x/stock/
for f in libsec-ril.so libsec-ril-dsds.so; do
  [ -s vendor/samsung-j5x/stock/$f ] && cp vendor/samsung-j5x/stock/$f "$DEST/$f" && say "  replaced $f with $ver version"
done
echo "$ver" > vendor/samsung-j5x/stock/VERSION
rm -rf "$WORK"
exit 0
