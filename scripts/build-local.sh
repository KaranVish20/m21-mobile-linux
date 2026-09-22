#!/bin/bash
# =============================================================================
# Local Build Script for Samsung Galaxy M21 Mobile Linux (WSL2 / Linux)
# =============================================================================

set -e

echo "=== Samsung Galaxy M21 Mobile Linux Local Build ==="

# Check toolchains
command -v aarch64-linux-gnu-gcc >/dev/null 2>&1 || { echo "Error: gcc-aarch64-linux-gnu is required."; exit 1; }
command -v clang >/dev/null 2>&1 || { echo "Error: clang is required."; exit 1; }

# 1. Clone kernel if not present
if [ ! -d "kernel" ]; then
    echo "-> Cloning kernel source..."
    git clone --depth 1 -b lineage-24.0-KSUN https://github.com/Parbindar7/android_kernel_samsung_universal9611.git kernel
fi

# 2. Apply defconfig patch
echo "-> Applying defconfig patch..."
if [ -f "patches/exynos9611-m21-halium.patch" ]; then
    cd kernel
    git apply ../patches/exynos9611-m21-halium.patch || true
    cd ..
fi

# 3. Build Kernel
echo "-> Compiling Linux 4.14 kernel for Exynos 9611..."
cd kernel
make -j$(nproc) O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- exynos9611-m21_defconfig
make -j$(nproc) O=out ARCH=arm64 CC=clang CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- Image dtbs
cd ..

echo "-> Kernel compilation complete: kernel/out/arch/arm64/boot/Image"
