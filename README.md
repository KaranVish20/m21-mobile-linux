# Samsung Galaxy M21 Mobile Linux (GNOME/Phosh on Exynos 9611)

A complete, automated cloud build pipeline and hardware-enablement layer for running **Mobile Linux (GNOME/Phosh)** on the **Samsung Galaxy M21** (`SM-M215F`, codename: `m21` / `m21nsxx`, Exynos 9611).

---

## ⚡ Features & Hardware Parity

By using **Halium + `libhybris`**, the system bridges to Samsung's proprietary hardware drivers instead of running on unaccelerated software rendering:

- **GPU**: ARM Mali-G72 MP3 hardware-accelerated via `libhybris-hwcomposer` (smooth 60 FPS, no freezing).
- **Telephony & SIM**: Shannon IPC modem managed by `oFono` + `rild` (Incoming/Outgoing calls, SMS, 4G LTE).
- **Sound**: PulseAudio / PipeWire droid sink connected to Samsung `audio.primary.exynos9611.so` (Speaker, mic, 3.5mm jack).
- **Screen & Touch**: 1080 × 2400 AMOLED display with multi-touch (`sec_ts`).
- **Wi-Fi & Bluetooth**: Samsung LSI (`slsi_wlan` / `scat`).
- **Sensors**: Orientation auto-rotation and proximity sensor mapped through `hybris-sensor-service`.
- **Environment**: **Phosh (GNOME)** Wayland mobile shell.

---

## 🛡️ 100% Fail-Safe: How Your Android 16 Stays Safe

1. **SD Card Isolation**: The installer packages the entire Linux operating system onto your **external MicroSD card**.
2. **Internal Partitions Untouched**: Your internal `super` partition (where Android 16 lives) and `/data` (where your personal photos/apps live) are **never wiped or modified**.
3. **10-Second Instant Rollback**:
   - In TWRP, go to **Backup** -> Select **Boot** -> Save to MicroSD card.
   - If you ever want to return to Android, simply go to **Restore** -> Select your Boot backup -> Swipe to Restore. You are back in Android 16 in 10 seconds!

---

## 🚀 How to Build in the Cloud (100% Free / ~30 Mins)

You do **not** need a Linux computer to build this. GitHub Actions builds the entire kernel and packages the TWRP zip for free:

### Step 1: Create a GitHub Repository
1. Go to [GitHub.com](https://github.com/new) and create a new repository (e.g. `m21-mobile-linux`).
2. Set it to **Public** (to get unlimited free build minutes).

### Step 2: Push this folder to your repository
In your terminal, navigate to this folder and run:
```bash
git init
git add .
git commit -m "feat: initial m21 mobile linux build configuration"
git branch -M main
git remote add origin https://github.com/<your-username>/m21-mobile-linux.git
git push -u origin main
```

### Step 3: Trigger the Build
1. Open your repository in your browser.
2. Click the **Actions** tab at the top.
3. Select **"Build Galaxy M21 Mobile Linux (GNOME/Phosh)"** on the left.
4. Click **Run workflow** -> Select **Run workflow**.

The cloud runner will:
- Clone `Parbindar7`'s Linux 4.14 kernel (`lineage-24.0-KSUN`).
- Compile the kernel and device tree with AOSP Clang.
- Package `halium-boot.img` with header version 2.
- Build the GNOME rootfs and package everything into **`pmos-m21-gnome-twrp-installer.zip`**.

### Step 4: Download the Flashable Files
Once the build completes (~25–35 minutes), go to the workflow run summary and download the artifact:
👉 **`m21-mobile-linux-gnome-build.zip`**

Inside you will find:
- `halium-boot.img`
- `pmos-m21-gnome-twrp-installer.zip`

---

## 📲 How to Install on Your Galaxy M21

### Option A: Using `adb sideload` (from PC)
1. Boot your phone into **TWRP Recovery**.
2. *(Important)*: Go to **Backup** -> Check **Boot** -> Save to SD card.
3. Go to **Advanced** -> **ADB Sideload** -> **Swipe to Start Sideload**.
4. Connect phone to PC via USB and run:
   ```bash
   adb sideload pmos-m21-gnome-twrp-installer.zip
   ```
5. Once complete, tap **Reboot System**.

### Option B: Directly from MicroSD Card (No PC needed)
1. Copy `pmos-m21-gnome-twrp-installer.zip` to your MicroSD card.
2. Boot into **TWRP Recovery**.
3. Tap **Backup** -> Check **Boot** -> Swipe to Backup.
4. Tap **Install** -> Select **MicroSD Card** -> Tap `pmos-m21-gnome-twrp-installer.zip`.
5. **Swipe to confirm Flash**.
6. Tap **Reboot System**.

---

## 💻 Emergency USB Rescue Shell (If screen stays dark)

If the screen is loading or you want to inspect boot logs:
1. Connect phone to PC with USB.
2. The phone exposes a USB networking interface at `172.16.42.1`.
3. Access the debug shell:
   ```bash
   telnet 172.16.42.1 24
   # or
   ssh user@172.16.42.1
   # (Default password: user)
   ```
4. View live logs:
   ```bash
   journalctl -f
   dmesg
   ```
