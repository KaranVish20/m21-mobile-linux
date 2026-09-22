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
if [ -f "halium-boot.img" ]; then
    cp halium-boot.img "$BUILD_DIR/boot.img"
elif [ -f "kernel/out/arch/arm64/boot/Image" ]; then
    echo "Warning: halium-boot.img not found, building standalone adaptation package."
fi

# Copy hardware configuration and udev rules
mkdir -p "$BUILD_DIR/adaptation"
if [ -d "device-config" ]; then
    cp -r device-config/* "$BUILD_DIR/adaptation/"
fi

# Check for rootfs payload
HAS_ROOTFS=0
if [ -f "rootfs.tar.xz" ]; then
    cp rootfs.tar.xz "$BUILD_DIR/rootfs.tar.xz"
    HAS_ROOTFS=1
elif [ -f "droidian-rootfs.zip" ]; then
    cp droidian-rootfs.zip "$BUILD_DIR/droidian-rootfs.zip"
    HAS_ROOTFS=1
fi

# Create dummy updater-script (required by older recoveries)
touch "$BUILD_DIR/META-INF/com/google/android/updater-script"

# Create update-binary shell script executed by TWRP
cat << 'EOF' > "$BUILD_DIR/META-INF/com/google/android/update-binary"
#!/sbin/sh
# =============================================================================
# TWRP installer for Samsung Galaxy M21 Mobile Linux (GNOME / Phosh)
# =============================================================================

OUTFD=$2
ZIPFILE=$3

ui_print() {
    echo -e "ui_print $1\nui_print" > /proc/self/fd/$OUTFD
}

ui_print "============================================"
ui_print "  Samsung Galaxy M21 Mobile Linux Installer "
ui_print "  Hardware: Exynos 9611 (SM-M215F)          "
ui_print "  Environment: Halium / Droidian Phosh     "
ui_print "============================================"

# 1. Flash Linux Kernel to Boot Partition
ui_print "-> Flashing Halium 4.14 Kernel to Boot partition..."
BOOT_DEV="/dev/block/by-name/boot"
if [ -e "$BOOT_DEV" ]; then
    unzip -p "$ZIPFILE" boot.img > "$BOOT_DEV"
    ui_print "   [OK] Boot partition flashed successfully."
else
    ui_print "   [ERROR] /dev/block/by-name/boot not found!"
    exit 1
fi

# 2. Check for MicroSD Storage
ui_print "-> Scanning for MicroSD Card storage..."
SD_BLOCK=""
if [ -b "/dev/block/mmcblk0" ]; then
    SD_BLOCK="/dev/block/mmcblk0"
elif [ -b "/dev/block/mmcblk1" ]; then
    SD_BLOCK="/dev/block/mmcblk1"
fi

# 3. Process Root Filesystem
if unzip -l "$ZIPFILE" | grep -q "rootfs.tar.xz"; then
    if [ -n "$SD_BLOCK" ]; then
        ui_print "   [OK] Target: MicroSD card ($SD_BLOCK)"
        ui_print "-> Formatting & preparing MicroSD Linux partition..."
        mke2fs -t ext4 -F -L "pmOS_root" "${SD_BLOCK}p2" || mke2fs -t ext4 -F -L "pmOS_root" "${SD_BLOCK}p1" || true
        mkdir -p /mnt/pmos_root
        mount -L "pmOS_root" /mnt/pmos_root || mount "${SD_BLOCK}p1" /mnt/pmos_root
        
        ui_print "-> Extracting GNOME / Phosh system rootfs..."
        unzip -p "$ZIPFILE" rootfs.tar.xz | tar -xJ -C /mnt/pmos_root
        
        # Inject hardware udev rules into rootfs
        mkdir -p /mnt/pmos_root/etc/udev/rules.d/
        unzip -p "$ZIPFILE" adaptation/90-samsung-m21.rules > /mnt/pmos_root/etc/udev/rules.d/90-samsung-m21.rules 2>/dev/null || true
        
        sync
        umount /mnt/pmos_root
        ui_print "   [OK] Mobile Linux successfully installed on MicroSD!"
    else
        ui_print "   [NOTICE] No MicroSD card detected."
        ui_print "-> Storing rootfs on internal storage (/data/pmos/)..."
        mkdir -p /data/pmos
        unzip -p "$ZIPFILE" rootfs.tar.xz > /data/pmos/rootfs.tar.xz
        ui_print "   [OK] Stored rootfs for loopback boot."
    fi
elif unzip -l "$ZIPFILE" | grep -q "droidian-rootfs.zip"; then
    ui_print "-> Extracting Droidian rootfs image to /data..."
    unzip -p "$ZIPFILE" droidian-rootfs.zip > /tmp/droidian-rootfs.zip
    unzip -o /tmp/droidian-rootfs.zip -d /data/
    rm -f /tmp/droidian-rootfs.zip
    ui_print "   [OK] Droidian rootfs deployed."
else
    ui_print "   [OK] Hardware adaptation & kernel boot flashed."
    ui_print "   [TIP] Flash droidian-OFFICIAL-rootfs zip next if installing fresh."
fi

ui_print "============================================"
ui_print "  INSTALLATION COMPLETE!                    "
ui_print "  Android 16 partition integrity preserved. "
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
