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
# Emptied, not deleted: hardware/samsung/Android.mk includes these paths by name
: > hardware/samsung/AdvancedDisplay/Android.mk
: > device/samsung/qcom-common/doze/Android.mk
sed -i '/SamsungDoze/d; /FlipFlap/d' device/samsung/j5-common/product/*.mk
sed -i '/^\s*Snap\s*\\\?\s*$/d' device/samsung/j5-common/product/camera.mk || true

echo ">> Pointing LineageOS CAF variant paths at the in-place HALs"
sed -i 's#hardware/qcom/audio-caf/msm8916#hardware/qcom/audio#' device/samsung/msm8916-common/board/qcom-audio.mk

echo ">> Removing LineageOS-only entries from resource overlays"
python3 "$PORT_DIR/scripts/filter-overlays.py" \
  device/samsung/j5xnlte/overlay device/samsung/j5-common/overlay \
  device/samsung/msm8916-common/overlay device/samsung/qcom-common/overlay

echo ">> Lineage-only APIs used by the msm8916 HALs"
# qti-testscripts.te uses a type only vendor/cm declares. Keep the rest of the
# test dir: qcom common file_contexts labels /system/bin/sns.* with its types.
rm -f device/qcom/sepolicy/test/qti-testscripts.te
# Samsung CameraParametersExtra macros trip -Werror=unused-parameter
grep -q 'Wno-unused-parameter' frameworks/av/camera/Android.mk || \
  sed -i '0,/^LOCAL_MODULE:= *libcamera_client/s//LOCAL_CFLAGS += -Wno-unused-parameter\nLOCAL_MODULE:= libcamera_client/' frameworks/av/camera/Android.mk
grep -n 'Wno-unused-parameter' frameworks/av/camera/Android.mk
# audio_is_offload_pcm() is a Lineage system/media helper (PCM offload is a Lineage format)
grep -q 'omni-compat audio_is_offload_pcm' hardware/qcom/audio/hal/audio_hw.c || \
  sed -i '0,/^#include "audio_hw.h"/s//#include "audio_hw.h"\n\/* omni-compat audio_is_offload_pcm *\/\nstatic inline bool audio_is_offload_pcm(audio_format_t f) { (void)f; return false; }/' hardware/qcom/audio/hal/audio_hw.c
grep -n 'omni-compat' hardware/qcom/audio/hal/audio_hw.c
# android_set_rt_ioprio() is a Lineage libcutils addition (only an I/O priority tweak)
sed -i 's/^\(\s*\)android_set_rt_ioprio(0, 1);/\1\/* omni: android_set_rt_ioprio unavailable *\//' hardware/qcom/display/libhwcomposer/hwc_vsync.cpp
# qcom power HAL: drop Lineage's power-profile extension (hint/feature ids + getFeature)
for f in device/qcom/common/power/power.c device/qcom/common/power/power-8916.c; do
  grep -q 'omni-compat' "$f" || sed -i '0,/^#include /s//\/* omni-compat *\/\n#ifndef POWER_HINT_SET_PROFILE\n#define POWER_HINT_SET_PROFILE 0x00000111\n#endif\n#ifndef POWER_FEATURE_SUPPORTED_PROFILES\n#define POWER_FEATURE_SUPPORTED_PROFILES 0x00001000\n#endif\n#include /' "$f"
done
sed -i '/^\s*\.setFeature = set_feature,\s*$/{N;s/,\n\s*\.getFeature = get_feature/\n/}' device/qcom/common/power/power.c
grep -n 'getFeature\|setFeature' device/qcom/common/power/power.c

echo ">> Dropping Omni apps whose source no longer exists on GitHub"
sed -i -E '/^\s*(OpenDelta|OmniSwitch|OmniJaws|OmniStyle|OmniClockOSS|OmniSubs)\s*\\?\s*$/d' vendor/omni/config/packages.mk

echo ">> Telephony: let Omni load ro.telephony.ril_class (SamsungQcomRIL)"
TEL=frameworks/opt/telephony
RILJ=$TEL/src/java/com/android/internal/telephony/RIL.java
PF=$TEL/src/java/com/android/internal/telephony/PhoneFactory.java
# Open RIL.java up so the device RIL subclass can override its handlers
sed -i -E 's/^(    |        )private /\1protected /' "$RILJ"

# RIL must be subclassable, and needs Lineage's mQANElements (Samsung modems
# return 6 strings per network in a scan instead of 4)
python3 - "$RILJ" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace('public final class RIL extends BaseCommands', 'public class RIL extends BaseCommands', 1)
if 'mQANElements' not in s:
    s = s.replace('    protected Integer mInstanceId;',
        '    protected Integer mInstanceId;\n'
        '    protected int mQANElements = SystemProperties.getInt("ro.ril.telephony.mqanelements", 4);', 1)
    i = s.index('responseOperatorInfos(Parcel p) {')
    j = s.index('return ret;', i)
    body = s[i:j]
    body = (body.replace('strings.length % 4 != 0', 'strings.length % mQANElements != 0')
                .replace('expected multible of 4', 'expected multiple of " + mQANElements + "')
                .replace('strings.length / 4', 'strings.length / mQANElements')
                .replace('i += 4', 'i += mQANElements'))
    s = s[:i] + body + s[j:]
assert 'mQANElements' in s and 'public class RIL ' in s
open(p, 'w').write(s)
PY

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
