# OmniROM 7.1.2 product for Samsung Galaxy J5 2016 (SM-J510FN)

# Inherit Omni common config (vendor/omni) via j5-common
$(call inherit-product, device/samsung/j5-common/omni.mk)

# Device
$(call inherit-product, device/samsung/j5xnlte/device.mk)

## Device identifier. This must come after all inclusions
PRODUCT_DEVICE := j5xnlte
PRODUCT_NAME := omni_j5xnlte
PRODUCT_BRAND := samsung
PRODUCT_MODEL := SM-J510FN
PRODUCT_MANUFACTURER := samsung
PRODUCT_CHARACTERISTICS := phone
PRODUCT_RELEASE_NAME := Galaxy J5 2016

PRODUCT_GMS_CLIENTID_BASE := android-samsung
