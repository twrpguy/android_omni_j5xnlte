#!/bin/bash
# Runs inside ubuntu:18.04: Nougat needs OpenJDK 8, Python 2 and an older glibc for its prebuilts.
set -eo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C LANG=C

apt-get update -qq
apt-get install -y -qq openjdk-8-jdk python git-core gnupg flex bison gperf build-essential \
  zip unzip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 lib32ncurses5-dev \
  x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc bc \
  ccache rsync schedtool lzop pngcrush imagemagick libssl-dev squashfs-tools procps >/dev/null

# Jack talks to its server over TLSv1, which JDK 8u29x disables
sed -i 's/^\(jdk.tls.disabledAlgorithms=\)SSLv3, TLSv1, TLSv1.1,/\1SSLv3,/' \
  /etc/java-8-openjdk/security/java.security || true

export USE_CCACHE=1
ccache -M 4G
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx6g"
export JACK_SERVER_VM_ARGUMENTS="$ANDROID_JACK_VM_ARGS"
export USER=root

source build/envsetup.sh
lunch omni_j5xnlte-userdebug

# Leave time at the end of the 6 h job to save ccache and logs
timeout 285m make -j"$(nproc)" "${TARGET:-bacon}" 2>&1 | tee build.log
exit "${PIPESTATUS[0]}"
