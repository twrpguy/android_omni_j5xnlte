#!/bin/bash
# Adapts the synced OmniROM 7.1 tree + LineageOS 14.1-based device trees.
# Run from the top of the source tree. Safe to run more than once.
set -euo pipefail
TOP=$(pwd)
PORT_DIR=${PORT_DIR:?set PORT_DIR to the checkout of this repo}

echo ">> Installing j5xnlte device tree"
rm -rf device/samsung/j5xnlte
cp -r "$PORT_DIR/device/samsung/j5xnlte" device/samsung/j5xnlte

echo ">> Creating vendor/samsung/j5xnlte from j5nlte blobs (same RIL/sensor/ACDB set the tree lists)"
if [ ! -d vendor/samsung/j5xnlte ]; then
  cp -r vendor/samsung/j5nlte vendor/samsung/j5xnlte
  for f in vendor/samsung/j5xnlte/*j5nlte*; do mv "$f" "${f//j5nlte/j5xnlte}"; done
  find vendor/samsung/j5xnlte -maxdepth 1 -type f \( -name '*.mk' \) -exec sed -i 's/j5nlte/j5xnlte/g' {} +
fi

echo ">> Removing modules that need the LineageOS SDK (absent in Omni)"
rm -f hardware/samsung/AdvancedDisplay/Android.mk
rm -f device/samsung/qcom-common/doze/Android.mk
sed -i '/SamsungDoze/d; /FlipFlap/d' device/samsung/j5-common/product/*.mk
sed -i '/^\s*Snap\s*\\\?\s*$/d' device/samsung/j5-common/product/camera.mk || true

echo ">> Dropping Omni apps whose source no longer exists on GitHub"
sed -i -E '/^\s*(OpenDelta|OmniSwitch|OmniJaws|OmniStyle|OmniClockOSS|OmniSubs)\s*\\?\s*$/d' vendor/omni/config/packages.mk

echo ">> Telephony: let Omni load ro.telephony.ril_class (SamsungQcomRIL)"
TEL=frameworks/opt/telephony
RILJ=$TEL/src/java/com/android/internal/telephony/RIL.java
PF=$TEL/src/java/com/android/internal/telephony/PhoneFactory.java
# Open RIL.java up so the device RIL subclass can override its handlers
sed -i -E 's/^(    |        )private /\1protected /' "$RILJ"

python3 - "$PF" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
if 'instantiateCustomRIL' not in s:
    old = re.search(r'sCommandsInterfaces\[i\] = new RIL\(context, networkModes\[i\],\s*cdmaSubscription, i\);', s)
    if not old:
        sys.exit("PhoneFactory: RIL construction not found")
    new = '''String rilClass = SystemProperties.get("ro.telephony.ril_class", "RIL").trim();
                    try {
                        sCommandsInterfaces[i] = (RIL) Class
                                .forName("com.android.internal.telephony." + rilClass)
                                .getConstructor(Context.class, int.class, int.class, Integer.class)
                                .newInstance(context, networkModes[i], cdmaSubscription, i);
                        Rlog.i(LOG_TAG, "Using RIL class " + rilClass);
                    } catch (Exception e) {
                        Rlog.e(LOG_TAG, "Unable to use RIL class " + rilClass + ", falling back", e);
                        sCommandsInterfaces[i] = new RIL(context, networkModes[i],
                                cdmaSubscription, i);
                    }'''
    s = s[:old.start()] + new + s[old.end():]
    if 'import android.os.SystemProperties;' not in s:
        s = s.replace('import android.os.ServiceManager;',
                      'import android.os.ServiceManager;\nimport android.os.SystemProperties;')
    open(p, 'w').write(s)
PY

# Compile the device's RIL class into telephony-common
if ! grep -q BOARD_RIL_CLASS $TEL/Android.mk; then
  sed -i '0,/^LOCAL_JAVA_LIBRARIES := /s//ifneq ($(BOARD_RIL_CLASS),)\nLOCAL_SRC_FILES += $(call all-java-files-under, $(BOARD_RIL_CLASS))\nendif\n\nLOCAL_JAVA_LIBRARIES := /' $TEL/Android.mk
fi
grep -n -A2 BOARD_RIL_CLASS $TEL/Android.mk

echo ">> Done"
