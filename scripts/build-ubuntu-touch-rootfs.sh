#!/bin/bash
set -e

echo "==================================================================="
echo " Building Ubuntu Touch Focal (20.04) Rootfs for Samsung Galaxy M21 "
echo " Hardware: Exynos 9611 (SM-M215F) | Halium 12 Framework            "
echo "==================================================================="

ROOTFS_URL="https://ci.ubports.com/job/ubuntu-touch-rootfs/job/ubports%252Ffocal/lastSuccessfulBuild/artifact/ubuntu-touch-android9plus-rootfs-arm64.tar.gz"
HALIUM_GENERIC_URL="https://ci.ubports.com/job/UBportsCommunityPortsJenkinsCI/job/ubports%252Fporting%252Fcommunity-ports%252Fjenkins-ci%252Fgeneric_arm64/job/halium-12.0/lastSuccessfulBuild/artifact/halium_halium_arm64.tar.xz"

WORK_DIR="build_ut"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/rootfs"
cd "$WORK_DIR"

# 1. Download official UBports Focal rootfs & Halium 12 generic adaptation
echo "-> [1/5] Downloading latest official UBports Focal ARM64 rootfs..."
curl -sSL -o rootfs.tar.gz "$ROOTFS_URL"

echo "-> [2/5] Downloading Halium 12 generic adaptation layer..."
curl -sSL -o halium_arm64.tar.xz "$HALIUM_GENERIC_URL"

# 2. Extract components
echo "-> [3/5] Extracting rootfs and Halium generic layer..."
tar -xzf rootfs.tar.gz -C rootfs/
tar -xJf halium_arm64.tar.xz -C rootfs/

# 3. Apply Samsung Galaxy M21 Exynos 9611 Adaptation & Fixes
echo "-> [4/5] Injecting Samsung Exynos 9611 adaptation and hardware fixes..."
if [ -d "../device-config/overlay/system" ]; then
    cp -r ../device-config/overlay/system/* rootfs/
fi

# Enable systemd services
mkdir -p rootfs/etc/systemd/system/multi-user.target.wants/
mkdir -p rootfs/etc/systemd/system/graphical.target.wants/
ln -sf /etc/systemd/system/samsung-hwc.service rootfs/etc/systemd/system/graphical.target.wants/samsung-hwc.service || true
ln -sf /etc/systemd/system/m21-bluetooth.service rootfs/etc/systemd/system/multi-user.target.wants/m21-bluetooth.service || true

# 4. Generate ext4 rootfs.img
echo "-> [5/5] Generating ext4 filesystem image (rootfs.img)..."
IMG_SIZE_MB=3800
dd if=/dev/zero of=rootfs.img bs=1M count=$IMG_SIZE_MB
mkfs.ext4 -F -O ^has_journal -m 0 -L "rootfs" rootfs.img

mkdir -p /tmp/mnt_ut
sudo mount -o loop rootfs.img /tmp/mnt_ut
echo "   Copying rootfs tree into image..."
sudo cp -a rootfs/* /tmp/mnt_ut/
sudo sync
sudo umount /tmp/mnt_ut

echo "   Minimizing rootfs image size..."
e2fsck -fy rootfs.img || true
resize2fs -M rootfs.img || true

cp rootfs.img ../rootfs.img
cd ..
echo "==================================================================="
echo " Ubuntu Touch rootfs.img built successfully!                       "
echo "==================================================================="
ls -lh rootfs.img
