# OmniROM 7.1.2 for Samsung Galaxy J5 2016 (SM-J510FN / j5xnlte)

Unofficial port. Everything builds on GitHub Actions, so no PC is needed.

## Build from your phone
1. Open the repo → **Actions** → **Build OmniROM 7.1.2 (j5xnlte)** → **Run workflow**.
2. Wait about 4–5 h. A full run takes close to the 6 h limit, and later runs are faster because of ccache.
3. If it works, the zip, `boot.img` and `recovery.img` appear under **Releases**.
   If it fails, the run's **Summary** page shows the first errors.

Set the target to `bootimage` to test only the kernel and boot image, which is much quicker.

## What's in here
| Path | Purpose |
|---|---|
| `device/samsung/j5xnlte` | Device tree (Galaxy-MSM8916 cm-14.1) converted to an Omni product (`omni_j5xnlte`) |
| `local_manifests/omni_j5xnlte.xml` | Common trees, the Dyeide kernel, blobs, and LineageOS msm8916 CAF HALs that replace Omni's stock HALs |
| `scripts/patch-sources.sh` | Omni compatibility patches (Samsung RIL class loader, removes modules that need the Lineage SDK, J510FN vendor dir) |
| `scripts/docker-build.sh` | Nougat build environment (Ubuntu 18.04, JDK 8, Python 2) |

## Sources
- Kernel: Dyeide/android_kernel_samsung_msm8916 `cm-14.1` (`msm8916_sec_j5xlte_eur_defconfig`, the J510FN EUR config with NFC)
- Device / blobs: Galaxy-MSM8916 `cm-14.1`
- ROM: omnirom/android `android-7.1` (android-7.1.2_r29)

## Status
**Works:** boot, Wi-Fi, Bluetooth, audio (speaker, earpiece, microphone), both cameras, auto-rotation, sensors,
wallpapers (OmniROM's own), OmniSwitch, Clock (OmniClockOSS), Messaging, Amaze (installed on first boot).

**Not tested:** GPS, charging behaviour, headphones, deep sleep / battery life, GApps.

## Known bugs
- **RIL / SIM: the SIM card is not detected**, so there are no calls, SMS or mobile data. The modem itself is fine;
  Samsung's radio library (libsec-ril) fails to start on this ROM. Use it as a Wi-Fi-only device for now.
- SELinux is permissive.
- Debug boot logging is on: each boot writes kernel and Android logs to `/cache/bootlog` (useful for bug reports).
- No OTA updates (OpenDelta), OmniJaws weather, OmniStyle or OmniSubs: their sources were deleted from GitHub.
- The LineageOS-only extras (Snap camera, Doze, FlipFlap) are left out.
