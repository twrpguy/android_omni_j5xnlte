# Inherit from common
include device/samsung/j5-common/BoardConfigCommon.mk

LOCAL_PATH := device/samsung/j5xnlte

# Asserts
TARGET_OTA_ASSERT_DEVICE := j5xnlte,j5xnltexx

# Kernel
# SM-J510FN uses the j5xlte EUR config (has PN547 NFC); there is no j5xnlte defconfig
TARGET_KERNEL_VARIANT_CONFIG := msm8916_sec_j5xlte_eur_defconfig

# Audio
AUDIO_FEATURE_SAMSUNG_DUAL_SIM := true

# Radio
SIM_COUNT := 2

# Partition sizes
BOARD_SYSTEMIMAGE_PARTITION_SIZE    := 3145728000
BOARD_USERDATAIMAGE_PARTITION_SIZE := 12138278912

# RIL
BOARD_GLOBAL_CFLAGS += -DRIL_FIX_SMS_NOT_SENT_ERR

# ---------------------------------------------------------------------------
# OmniROM 7.1 compatibility shims (these trees were written for LineageOS 14.1)
# ---------------------------------------------------------------------------

# Omni only applies -DQCOM_HARDWARE / -DQCOM_BSP when this is set
BOARD_USES_QCOM_HARDWARE := true

# LineageOS-only BOARD_GLOBAL_* flags -> AOSP equivalents
TARGET_GLOBAL_CFLAGS += $(BOARD_GLOBAL_CFLAGS)
TARGET_GLOBAL_CPPFLAGS += $(BOARD_GLOBAL_CPPFLAGS)

# LineageOS build function used by the CAF HALs and qcom/common.
# Omni has no "variant" paths, so the msm8916 CAF HALs replace the stock
# ones in place (see local_manifests/omni_j5xnlte.xml).
project-path-for = $(strip $(if $(filter recovery,$(1)),bootable/recovery,$(if $(filter ril,$(1)),hardware/ril,$(if $(filter qcom-display,$(1)),hardware/qcom/display,$(if $(filter qcom-audio,$(1)),hardware/qcom/audio,$(if $(filter qcom-media,$(1)),hardware/qcom/media,))))))

# libhealthd.cm no longer exists anywhere; use AOSP's board library
BOARD_HAL_STATIC_LIBRARIES := libhealthd.default

# Omni has no vendor/qcom/opensource/cryptfs_hw; use software encryption
TARGET_HW_DISK_ENCRYPTION := false

# The device ships an open-source QMI shim (libwcnss_qmi), so wcnss_service
# must not link Qualcomm's QMI blobs directly (they aren't build modules)
TARGET_PROVIDES_WCNSS_QMI := true

# Nougat's envsetup only puts arm-eabi-4.9 on PATH, but only 4.8 is in the tree
KERNEL_TOOLCHAIN := $(ANDROID_BUILD_TOP)/prebuilts/gcc/$(HOST_PREBUILT_TAG)/arm/arm-eabi-4.8/bin
KERNEL_TOOLCHAIN_PREFIX := arm-eabi-

# The CAF policy_hal targets Lineage's AudioPolicyMix API; use AOSP's policy manager
USE_CUSTOM_AUDIO_POLICY := 0
