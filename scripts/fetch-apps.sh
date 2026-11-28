#!/bin/bash
# Download the bundled user apps (official builds) into the device tree.
# They are shipped in /system/preinstall and installed once on first boot as
# normal, updatable apps. Run from the source top after patch-sources.sh.
# A failed download only skips that app.
DEST=device/samsung/j5xnlte/preinstall
mkdir -p "$DEST"

get() { # name url
  local name=$1 url=$2 tmp
  tmp=$(mktemp)
  if curl -fsSL --retry 3 --connect-timeout 30 -o "$tmp" "$url" \
     && unzip -l "$tmp" 2>/dev/null | grep -q " AndroidManifest.xml$"; then
    mv "$tmp" "$DEST/$name.apk.pre"
    echo ">> $name: $(du -h "$DEST/$name.apk.pre" | cut -f1) from $url"
  else
    rm -f "$tmp"
    echo ">> $name: download FAILED ($url), not bundled"
  fi
}

# Amaze File Manager: latest GitHub release (F-Droid flavour, no Google libs)
amaze=$(curl -fsSL https://api.github.com/repos/TeamAmaze/AmazeFileManager/releases/latest \
        | python3 -c 'import json,sys; a=[x["browser_download_url"] for x in json.load(sys.stdin)["assets"] if x["name"].endswith(".apk")]; print(([u for u in a if "fdroid" in u] or a)[0])' 2>/dev/null)
[ -n "$amaze" ] && get Amaze "$amaze" || echo ">> Amaze: no APK found in the latest release"

exit 0
