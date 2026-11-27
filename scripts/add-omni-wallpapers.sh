#!/bin/bash
# Bundle OmniROM's official wallpapers into WallpaperPicker.
# The 45-image gallery OmniStyle downloaded (dl.omnirom.org) is gone and not
# archived, so use the official wallpapers OmniROM kept in git: the default
# wallpapers of other OmniROM releases and the Android 10 theme wallpapers.
# Never fails the build. Run from the top of the source tree; needs ImageMagick.
set -u
WP=packages/apps/WallpaperPicker
OUT=$WP/res/drawable-nodpi
REPO=https://github.com/omnirom/android_vendor_omni
TMP=$(mktemp -d)
mkdir -p "$OUT"

# blob id (in android_vendor_omni history)      resource name     (origin)
WALLS="
3d9b0fa22d85fc3d679bd571a68e937b0aec2b74 omni_marshmallow  android-6.0 default
bf7dbd3f9f3261f3e4eb5bc40e29eb3945c9127d omni_nougat       android-7.0 default
1759fd7409e151d7f02430122203de592937e6c8 omni_nature       android-10 theme
d4f7b353a9b255bcc255f55f02f7192dc0caaef5 omni_red          android-10 theme
1345dd2abd56fad02f4228380e1298a7b163df2c omni_space        android-10 theme
0c7da9ba78137e2ceda1263808c065834d3d8958 omni_eleven       android-11 default
ab07947fda8679a071178f22e661b3a32b498840 omni_twelve       android-12 default
d7a27948d0d2803eb79a7dbe33aa0497bb857b6f omni_thirteen     android-13 default
"

git clone -q --filter=blob:none --no-checkout "$REPO" "$TMP/vo" || { echo ">> wallpapers: cannot reach $REPO"; exit 0; }

added=()
while read -r blob name origin; do
  [ -n "$blob" ] || continue
  if git -C "$TMP/vo" cat-file -p "$blob" > "$TMP/$name.img" 2>/dev/null && identify "$TMP/$name.img" >/dev/null 2>&1; then
    # J5 2016 is 720x1280; keep enough width for scrolling, as JPEG to keep /system small
    convert "$TMP/$name.img[0]" -resize '1440x1440>' -quality 90 "$OUT/$name.jpg"
    convert "$TMP/$name.img[0]" -thumbnail '192x192^' -gravity center -extent 192x192 -quality 85 "$OUT/${name}_small.jpg"
    added+=("$name")
    echo "  added $name ($origin)"
  else
    echo "  skip $name (blob $blob not available)"
  fi
done <<< "$WALLS"
rm -rf "$TMP"

{
  echo '<?xml version="1.0" encoding="utf-8"?>'
  echo '<resources>'
  echo '    <string-array name="wallpapers" translatable="false">'
  for r in "${added[@]}"; do echo "        <item>$r</item>"; done
  echo '    </string-array>'
  echo '</resources>'
} > "$WP/res/values-nodpi/wallpapers.xml"

echo ">> ${#added[@]} OmniROM wallpapers bundled into WallpaperPicker"
du -sh "$OUT" 2>/dev/null || true
exit 0
