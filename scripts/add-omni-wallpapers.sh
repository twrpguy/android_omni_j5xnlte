#!/bin/bash
# Bundle OmniROM's official wallpapers into WallpaperPicker (they used to be
# downloaded on demand by OmniStyle, whose source is gone).
# Sources: dl.omnirom.org, falling back to the Internet Archive copy.
# Never fails the build: missing images are skipped and reported.
# Run from the top of the source tree; needs ImageMagick (convert/identify).
set -u
LIST=vendor/omni/prebuilt/wallpapers/wallpapers.xml
WP=packages/apps/WallpaperPicker
OUT=$WP/res/drawable-nodpi
DL=$(mktemp -d)
mkdir -p "$OUT"

names=$(grep -oE 'filename="[^"]+"' "$LIST" | cut -d'"' -f2)
added=()
for f in $names; do
  base="${f%.*}"
  # Android resource names: lowercase letters, digits, underscore; no leading digit
  res="omni_$(echo "$base" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9_\n' '_')"
  got=""
  for url in "https://dl.omnirom.org/images/wallpapers/$f" \
             "https://web.archive.org/web/2019id_/https://dl.omnirom.org/images/wallpapers/$f"; do
    if curl -fsSL --retry 2 --max-time 90 -o "$DL/$f" "$url" && identify "$DL/$f" >/dev/null 2>&1; then
      got="$url"; break
    fi
  done
  if [ -z "$got" ]; then
    echo "  skip $f (not downloadable)"
    continue
  fi
  # J5 2016 is 720x1280; keep enough width for scrolling, as JPEG to keep /system small
  convert "$DL/$f[0]" -resize '1440x1440>' -quality 90 "$OUT/$res.jpg"
  convert "$DL/$f[0]" -thumbnail '192x192^' -gravity center -extent 192x192 -quality 85 "$OUT/${res}_small.jpg"
  added+=("$res")
  echo "  added $f -> $res ($got)"
done
rm -rf "$DL"

{
  echo '<?xml version="1.0" encoding="utf-8"?>'
  echo '<resources>'
  echo '    <string-array name="wallpapers" translatable="false">'
  for r in "${added[@]}"; do echo "        <item>$r</item>"; done
  echo '    </string-array>'
  echo '</resources>'
} > "$WP/res/values-nodpi/wallpapers.xml"

echo ">> ${#added[@]} of $(echo "$names" | wc -w) OmniROM wallpapers bundled into WallpaperPicker"
du -sh "$OUT" 2>/dev/null || true
exit 0
