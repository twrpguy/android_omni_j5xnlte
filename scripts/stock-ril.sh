#!/bin/bash
# Replace the J500 (Marshmallow) libsec-ril with the one from the J510FN's own
# latest stock firmware, so it matches the modem firmware (J510FNXXS3BTI1).
# Downloads from Samsung's update servers with samloader-rs.
# Run from the source top after sync. Never fails the build: if anything goes
# wrong the old RIL stays in place.
set -u
TOP=$PWD
MODEL=SM-J510FN
REGIONS="DBT XEO BTU ITV PHE XEF NEE ATO AUT TPH SEB"
WORK=${STOCK_WORK:-$PWD/../stock-fw}
DEST=vendor/samsung-j5x/j5xnlte/proprietary/lib
# Outside device/samsung/j5xnlte: patch-sources.sh recreates that directory
EXTRA_MK=vendor/samsung-j5x/stock/stock-ril.mk
mkdir -p "$WORK" vendor/samsung-j5x/stock
: > "$EXTRA_MK"

say() { echo ">> $*"; }
fail() { say "stock RIL: $* - keeping the J500 libsec-ril"; exit 0; }

# samloader-rs (topjohnwu); only the nusb backend, so no libudev is needed.
# Build output goes on the big build volume, not the small root disk.
if ! command -v samloader >/dev/null; then
  say "building samloader"
  CARGO_TARGET_DIR="$WORK/cargo-target" cargo install --locked --quiet \
    --git https://github.com/topjohnwu/samloader-rs samloader \
    --no-default-features --features nusb 2>&1 | tail -20
  rm -rf "$WORK/cargo-target"
  command -v samloader >/dev/null || fail "could not build samloader"
fi

ver="" ; region=""
for r in $REGIONS; do
  out=$(samloader check-update -m "$MODEL" -r "$r" 2>&1)
  say "  check-update $r: $(echo "$out" | tail -1)"
  v=$(echo "$out" | grep -E '^[A-Z0-9]+/[A-Z0-9]*/[A-Z0-9]*' | tail -1)
  if [ -n "$v" ]; then ver=$v; region=$r; break; fi
done
[ -n "$ver" ] || fail "no firmware found for $MODEL"
say "stock firmware $ver ($region)"

cd "$WORK" || fail "no work dir"
# Only the AP part (system image); samloader decrypts and extracts it
samloader download -m "$MODEL" -r "$region" -s ap -d fw 2>&1 | grep -v '^\s*$' | tail -5
say "  firmware files: $(find fw -type f -printf '%f ' | head -c 400)"
ap=$(find fw -name 'AP_*.tar*' | head -1)
img=$(find fw -name 'system.img*' | head -1)
if [ -z "$img" ]; then
  [ -n "$ap" ] || fail "download failed (no AP file)"
  say "  AP: $(basename "$ap"): $(tar -tf "$ap" | tr '\n' ' ' | head -c 300)"
  tar -xf "$ap" --wildcards 'system.img*' || fail "no system image in $(basename "$ap")"
  img=$(ls system.img* | head -1)
fi
case "$img" in *.lz4) lz4 -dqf "$img" system.sparse && img=system.sparse ;; esac
say "  image: $(basename "$img"): $(file -b "$img" | cut -c1-80)"
if file -b "$img" | grep -qi "android sparse"; then
  simg2img "$img" system.raw || fail "simg2img failed"
else
  cp "$img" system.raw
fi
mkdir -p mnt
sudo mount -o loop,ro system.raw mnt || fail "cannot mount stock system ($(file -b system.raw | cut -c1-60))"
# system-as-root images keep the files under /system
SYS=mnt; [ -d mnt/system/lib ] && SYS=mnt/system
say "  stock libs: $(find "$SYS" -name 'libsec-ril*' -printf '%P ' 2>/dev/null)"

mkdir -p out
for f in libsec-ril.so libsec-ril-dsds.so; do
  [ -f "$SYS/lib/$f" ] && cp "$SYS/lib/$f" out/
done
if [ ! -s out/libsec-ril.so ]; then sudo umount mnt; fail "libsec-ril.so not found in stock system"; fi

# Pull every library in the stock RIL's dependency chain (recursively) that the
# ROM doesn't already build or ship; take it from the stock system.
provided=$WORK/provided.txt
{
  # modules built from source
  grep -rhoE --include=Android.mk 'LOCAL_MODULE *:?= *lib[A-Za-z0-9_+.-]+' \
       "$TOP/bionic" "$TOP/system" "$TOP/frameworks" "$TOP/external" "$TOP/hardware" \
       "$TOP/device" "$TOP/vendor" "$TOP/libcore" "$TOP/art" "$TOP/bootable" 2>/dev/null \
    | sed -E 's/.*= *//'
  grep -rhoE --include=Android.bp 'name: *"lib[A-Za-z0-9_+.-]+"' \
       "$TOP/bionic" "$TOP/system" "$TOP/frameworks" "$TOP/external" "$TOP/hardware" "$TOP/art" 2>/dev/null \
    | sed -E 's/.*"(.*)"/\1/'
  # prebuilt blobs copied into /system/lib
  grep -rhoE ':system/(vendor/)?lib/lib[^ \\]+\.so' "$TOP/vendor/samsung" "$TOP/vendor/samsung-j5x" --include='*.mk' 2>/dev/null \
    | sed -E 's#.*/##; s/\.so$//'
} | sed -E 's/\.so$//' | sort -u > "$provided"
say "  $(wc -l < "$provided") libraries provided by the ROM"

queue="libsec-ril.so libsec-ril-dsds.so"; seen=" "
while [ -n "$queue" ]; do
  set -- $queue; cur=$1; shift; queue="$*"
  case "$seen" in *" $cur "*) continue ;; esac
  seen="$seen$cur "
  [ -f out/$cur ] || continue
  for lib in $(readelf -d out/$cur 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p'); do
    case "$seen $queue" in *" $lib "*|*" $lib") continue ;; esac
    grep -qx "${lib%.so}" "$provided" && continue
    src=""
    for d in "$SYS/lib" "$SYS/vendor/lib"; do [ -f "$d/$lib" ] && src="$d/$lib" && break; done
    if [ -z "$src" ]; then say "  ! $cur needs $lib: not in ROM or stock"; continue; fi
    cp "$src" out/
    echo "PRODUCT_COPY_FILES += vendor/samsung-j5x/stock/$lib:system/lib/$lib" >> "$TOP/$EXTRA_MK"
    say "  + dependency $lib (needed by $cur)"
    queue="$queue $lib"
  done
done
# Samsung's feature libraries read this
if [ -f "$SYS/etc/floating_feature.xml" ]; then
  cp "$SYS/etc/floating_feature.xml" out/
  echo "PRODUCT_COPY_FILES += vendor/samsung-j5x/stock/floating_feature.xml:system/etc/floating_feature.xml" >> "$TOP/$EXTRA_MK"
  say "  + etc/floating_feature.xml"
fi
say "  libsec-ril needs: $(readelf -d out/libsec-ril.so | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' | tr '\n' ' ')"
sudo umount mnt
cd - >/dev/null

mkdir -p vendor/samsung-j5x/stock
cp "$WORK"/out/* vendor/samsung-j5x/stock/
for f in libsec-ril.so libsec-ril-dsds.so; do
  [ -s vendor/samsung-j5x/stock/$f ] && cp vendor/samsung-j5x/stock/$f "$DEST/$f" && say "  replaced $f with $ver version"
done
echo "$ver" > vendor/samsung-j5x/stock/VERSION
rm -rf "$WORK"
exit 0
