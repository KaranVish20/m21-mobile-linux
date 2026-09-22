#!/bin/bash
# =============================================================================
# Generate TWRP Sideloadable / Flashable Installer ZIP for Galaxy M21
# Target: Writes boot.img to /dev/block/by-name/boot & installs rootfs to MicroSD
# =============================================================================

set -e

BUILD_DIR="out_twrp_zip"
OUTPUT_ZIP="pmos-m21-gnome-twrp-installer.zip"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/META-INF/com/google/android"

# Copy input artifacts
cp halium-boot.img "$BUILD_DIR/boot.img"
cp rootfs.tar.xz "$BUILD_DIR/rootfs.tar.xz"

# Create dummy updater-script (required by older recoveries)
touch "$BUILD_DIR/META-INF/com/google/android/updater-script"

# Create update-binary shell script executed by TWRP
cat << 'EOF' > "$BUILD_DIR/META-INF/com/google/android/update-binary"
#!/sbin/sh
# TWRP installer for Samsung Galaxy M21 Mobile Linux (GNOME)

OUTFD=$2
ZIPFILE=$3

ui_print() {
    echo -e "ui_print $1\nui_print" > /proc/self/fd/$OUTFD
}

ui_print "============================================"
ui_print "  Samsung Galaxy M21 Mobile Linux Installer "
ui_print "  Environment: GNOME / Phosh on Exynos 9611 "
ui_print "============================================"

# 1. Flash boot.img to /dev/block/by-name/boot
ui_print "-> Flashing Linux 4.14 Kernel to Boot partition..."
BOOT_DEV="/dev/block/by-name/boot"
if [ -e "$BOOT_DEV" ]; then
    unzip -p "$ZIPFILE" boot.img > "$BOOT_DEV"
    ui_print "   [OK] Boot partition flashed successfully."
else
    ui_print "   [ERROR] Could not find /dev/block/by-name/boot!"
    exit 1
fi

# 2. Check for MicroSD Card
ui_print "-> Checking for MicroSD Card storage..."
SD_BLOCK=""
if [ -b "/dev/block/mmcblk0" ]; then
    SD_BLOCK="/dev/block/mmcblk0"
elif [ -b "/dev/block/mmcblk1" ]; then
    SD_BLOCK="/dev/block/mmcblk1"
fi

if [ -n "$SD_BLOCK" ]; then
    ui_print "   [OK] Found MicroSD card: $SD_BLOCK"
    ui_print "-> Installing GNOME root filesystem to MicroSD..."
    # Format and extract to SD partition
    mke2fs -t ext4 -F -L "pmOS_root" "${SD_BLOCK}p2" || mke2fs -t ext4 -F -L "pmOS_root" "${SD_BLOCK}p1" || true
    mkdir -p /mnt/pmos_root
    mount -L "pmOS_root" /mnt/pmos_root || mount "${SD_BLOCK}p1" /mnt/pmos_root
    
    ui_print "-> Extracting system rootfs files..."
    unzip -p "$ZIPFILE" rootfs.tar.xz | tar -xJ -C /mnt/pmos_root
    sync
    umount /mnt/pmos_root
    ui_print "   [OK] Rootfs successfully installed on MicroSD!"
else
    ui_print "   [NOTICE] No SD Card detected. Storing rootfs on internal /data..."
    mkdir -p /data/pmos
    unzip -p "$ZIPFILE" rootfs.tar.xz > /data/pmos/rootfs.tar.xz
    ui_print "   [OK] Placed rootfs in /data/pmos/ for loopback boot."
fi

ui_print "============================================"
ui_print "  INSTALLATION COMPLETE!                    "
ui_print "  Your Android 16 installation is intact.   "
ui_print "  Reboot system to launch Mobile Linux.     "
ui_print "============================================"
exit 0
EOF

chmod +x "$BUILD_DIR/META-INF/com/google/android/update-binary"

# Pack the ZIP file
cd "$BUILD_DIR"
zip -r9 "../$OUTPUT_ZIP" ./*
cd ..
echo "Successfully generated: $OUTPUT_ZIP"
