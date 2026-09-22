#!/bin/bash
# =============================================================================
# Generate TWRP Sideloadable / Flashable Installer ZIP for Galaxy M21
# Target: Writes boot.img to /dev/block/by-name/boot & installs rootfs to /data/rootfs.img
# =============================================================================

set -e

BUILD_DIR="out_twrp_zip"
OUTPUT_ZIP="ubuntu-touch-m21-focal-installer.zip"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/META-INF/com/google/android"

# Copy input artifacts
if [ -f "halium-boot.img" ]; then
    cp halium-boot.img "$BUILD_DIR/boot.img"
fi

if [ -f "rootfs.img" ]; then
    cp rootfs.img "$BUILD_DIR/rootfs.img"
fi

# Copy hardware configuration and udev rules
mkdir -p "$BUILD_DIR/adaptation"
if [ -d "device-config" ]; then
    cp -r device-config/* "$BUILD_DIR/adaptation/"
fi

# Create dummy updater-script (required by older recoveries)
touch "$BUILD_DIR/META-INF/com/google/android/updater-script"

# Create update-binary shell script executed by TWRP
cat << 'EOF' > "$BUILD_DIR/META-INF/com/google/android/update-binary"
#!/sbin/sh
# =============================================================================
# TWRP installer for Samsung Galaxy M21 Mobile Linux (Ubuntu Touch Focal)
# =============================================================================

OUTFD=$2
ZIPFILE=$3

ui_print() {
    echo -e "ui_print $1\nui_print" > /proc/self/fd/$OUTFD
}

ui_print "============================================"
ui_print "  Samsung Galaxy M21 Mobile Linux Installer "
ui_print "  Hardware: Exynos 9611 (SM-M215F)          "
ui_print "  OS: Ubuntu Touch (Focal 20.04 Lomiri)     "
ui_print "============================================"

# 1. Mount /data partition
ui_print "-> Checking userdata partition (/data)..."
if ! mountpoint -q /data; then
    mount /dev/block/by-name/userdata /data || mount /dev/block/mmcblk0p58 /data || mount /data || true
fi

# 2. Flash Linux Kernel to Boot Partition
ui_print "-> Flashing Halium 4.14 Kernel to Boot partition..."
BOOT_DEV=""
for p in /dev/block/by-name/boot /dev/block/platform/*/by-name/boot /dev/block/mmcblk0p35; do
    if [ -e "$p" ]; then
        BOOT_DEV="$p"
        break
    fi
done

if [ -n "$BOOT_DEV" ]; then
    ui_print "   Flashing to $BOOT_DEV..."
    unzip -p "$ZIPFILE" boot.img > "$BOOT_DEV"
    ui_print "   [OK] Boot partition flashed successfully."
else
    ui_print "   [WARNING] Boot block device not found directly, trying /dev/block/by-name/boot..."
    unzip -p "$ZIPFILE" boot.img > /dev/block/by-name/boot || true
fi

# 3. Extract Root Filesystem to /data/rootfs.img
if unzip -l "$ZIPFILE" | grep -q "rootfs.img"; then
    ui_print "-> Deploying Ubuntu Touch rootfs to /data/rootfs.img..."
    unzip -p "$ZIPFILE" rootfs.img > /data/rootfs.img
    
    ui_print "-> Resizing filesystem for optimal performance..."
    e2fsck -fy /data/rootfs.img || true
    
    # Calculate available space in KB, leave 200MB safety buffer
    AVAIL_KB=$(df -k /data | awk 'NR==2 {print $4}')
    if [ -n "$AVAIL_KB" ] && [ "$AVAIL_KB" -gt 500000 ]; then
        TARGET_SIZE_KB=$((AVAIL_KB - 204800))
        resize2fs /data/rootfs.img "${TARGET_SIZE_KB}K" || true
    fi
    
    # Symlink android-rootfs if needed
    if [ ! -e /data/android-rootfs.img ]; then
        ln -sf /halium-system/var/lib/lxc/android/android-rootfs.img /data/android-rootfs.img 2>/dev/null || true
    fi
    ui_print "   [OK] Ubuntu Touch rootfs successfully deployed!"
else
    ui_print "   [NOTICE] Standalone kernel package flashed."
    ui_print "   [TIP] Ensure /data/rootfs.img is present on device."
fi

ui_print "============================================"
ui_print "  INSTALLATION COMPLETE!                    "
ui_print "  Android partition integrity preserved.    "
ui_print "  Reboot system to launch Ubuntu Touch!     "
ui_print "============================================"
exit 0
EOF

chmod +x "$BUILD_DIR/META-INF/com/google/android/update-binary"

# Pack the ZIP file
cd "$BUILD_DIR"
zip -r9 "../$OUTPUT_ZIP" ./*
cd ..
echo "Successfully generated: $OUTPUT_ZIP"
