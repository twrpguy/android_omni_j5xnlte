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

## Known caveats
- The RIL/sensor blobs come from the J500FN set that the device tree lists, so check calls, SMS and mobile data first.
- The camera app (Snap) and Doze/FlipFlap are LineageOS-only and are left out.
