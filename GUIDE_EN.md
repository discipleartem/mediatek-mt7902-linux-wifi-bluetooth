# MediaTek MT7902 WiFi + Bluetooth — Complete Guide

## Overview

A Linux fix for the built-in **MediaTek MT7902** (Filogic 310) combo adapter: PCIe Wi‑Fi, USB Bluetooth, firmware, autoload, and shutdown timeout tuning.

On kernels **before 7.1**, MT7902 is often left unclaimed. This project installs community backport drivers and system settings.

## Supported Hardware

### Network cards / chipsets

| Chipset | Role | IDs | Module |
|---------|------|-----|--------|
| **MT7902** | Wi‑Fi 6 PCIe | PCI `14c3:7902`, AzureWave subsystem `1a3b:5524` | `mt7902e` |
| **MT7902** | Bluetooth USB (combo) | often USB `13d3:3594` (IMC Networks / MediaTek) | `btusb_mt7902` |
| MT7921 / MT7922 | Wi‑Fi PCIe | `14c3:7921`, `14c3:7922`, … | in-tree `mt7921e` |
| MT7961 | Wi‑Fi PCIe | `14c3:7961` | in-tree `mt7921e` |

System name: *MediaTek MT7902 802.11ax PCIe Wireless Network Adapter [Filogic 310]*.

Check your machine:

```bash
lspci -nnk | grep -A3 -i 'network\|mediatek\|7902'
lsusb | grep -iE '13d3:3594|Wireless|MediaTek|Bluetooth'
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name
```

### Laptops

AzureWave MT7902 modules are common in **Acer** notebooks:

| Model | Note |
|-------|------|
| **Aspire A315-59** | Verified in this project (Wi‑Fi + Bluetooth) |
| Aspire A314-23P | Frequently reported on [linux-hardware.org](https://linux-hardware.org/?id=pci%3A14c3-7902-1a3b-5524) |
| Aspire A314-35 | Community |
| Aspire A315-24P | Community |
| Aspire A114-33 | Community |
| Extensa 215-23 | Community |
| Extensa 215-55 | Community |

Any system with PCI ID **`14c3:7902`** is a candidate. The laptop list grows with user reports.

### Kernel compatibility

| Component | Source | Kernels |
|-----------|--------|---------|
| Wi‑Fi `mt7902e` | `gen4-mt7902/` ← `backport` branch | 6.6–6.19 |
| Bluetooth `btusb_mt7902` | `btusb_mt7902/` ← `bluetooth_backport` | 6.6–6.19 |
| Mainline | expected in Linux **7.1+** | — |

Upstream driver repo: [hmtheboy154/mt7902](https://github.com/hmtheboy154/mt7902).

## Tests (run first) — do not harm the system

Primary goal: the driver patch/installer must **not harm** the user's system. Tests catch installer regressions (scoped blacklist, side-effect warnings, uninstall path) **before** `sudo ./mt7902.sh install-all`:

```bash
./tests/run-tests.sh
# or
make test
```

Tests need no root and no hardware. After install: `make test-hw` / `./mt7902.sh verify`.

### Rollback

Before changing the system, the installer saves originals under `/var/lib/mt7902-fix/backup`. If Wi‑Fi/Bluetooth never come up:

```bash
sudo ./mt7902.sh rollback
```

On module load failure the installer offers rollback (or set `MT7902_AUTO_ROLLBACK=1` for non-interactive).

## Quick Start

```bash
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) git dkms

# Wi‑Fi + Bluetooth + systemd in one step
sudo ./mt7902.sh install-all

sudo reboot
```

Or stepwise: `sudo ./mt7902.sh install` then `sudo ./mt7902.sh bluetooth`.

After reboot:

```bash
lsmod | grep -E 'mt7902e|btusb_mt7902'
nmcli device status
bluetoothctl show
./mt7902.sh verify
```

### Verified on

| Item | Value |
|------|-------|
| Laptop | Acer Aspire A315-59 |
| Wi‑Fi | PCI `14c3:7902` / AzureWave `1a3b:5524` → `mt7902e`, iface `wlp42s0` |
| Bluetooth | USB `13d3:3594` → `btusb_mt7902`, MediaTek HCI 5.2, Powered |
| Kernel | Linux 6.17 (Ubuntu 24.04 HWE) |
| OS | Ubuntu 24.04 |
## Wi‑Fi

### Specs

- **Device:** MediaTek MT7902
- **PCI ID:** `14c3:7902`
- **Driver:** `mt7902e`
- **Firmware:** `mediatek/WIFI_MT7902_patch_mcu_1_1_hdr.bin`, `mediatek/WIFI_RAM_CODE_MT7902_1.bin`
- **Interface:** usually `wlan0`, may be renamed to `wlpXsY` (e.g. `wlp42s0`)

### Checks

```bash
lsmod | grep mt7902e
lspci -nnk | grep -A3 7902
ip -br link
nmcli device status
```

### Common issues

**Driver not loading**

```bash
sudo modprobe -r mt7902e
sudo modprobe mt7902e
sudo systemctl restart NetworkManager
```

**No interface / no networks**

```bash
journalctl -b | grep -i mt7902e | tail -30
ls /lib/firmware/mediatek/WIFI_MT7902*
```

On Windows dual-boot, disable **Fast Startup** — otherwise the card may fail to initialize under Linux.

## Bluetooth

### Symptoms before the fix

- `bluetoothctl show` → *No default controller*
- `hciconfig`: address `00:00:00:00:00:00`, state `DOWN`
- Logs: `Bluetooth: hciX: Opcode 0x0c03 failed: -110`

### Install

```bash
sudo ./mt7902.sh bluetooth
# or
sudo make bluetooth
```

What it does:

1. Builds and installs `btusb_mt7902`
2. Installs firmware `mediatek/BT_RAM_CODE_MT7902_1_1_hdr.bin`
3. Blacklists stock modules in `/etc/modprobe.d/blacklist_btusb.conf`:
   ```
   blacklist btusb
   blacklist btmtk
   ```
4. Enables autoload of `btusb_mt7902`
5. Optionally registers DKMS

### Verify

```bash
lsmod | grep btusb_mt7902
hciconfig -a
bluetoothctl show
# Expect: Manufacturer MediaTek, Powered yes, valid BD Address
```

### Important

- In-tree `btusb` / `btmtk` **conflict** with `btusb_mt7902` — unload and blacklist them.
- Bluetooth on a Realtek USB dongle (via `btusb`) will **stop working** after the blacklist.
- Realtek USB Wi‑Fi (`rtw88`, etc.) is unaffected.

### Reload Bluetooth driver

```bash
sudo systemctl stop bluetooth
sudo modprobe -r btusb_mt7902
sudo modprobe btusb_mt7902
sudo systemctl start bluetooth
```

## System Optimizations

### Problem: hang on shutdown

Common causes:

- Infinite Docker stop timeouts (`TimeoutStopUSec=infinity`)
- Wi‑Fi driver unload stalls
- Long NetworkManager stop timeouts

### Fix (via `./mt7902.sh system` or `install`)

**`/etc/systemd/system.conf.d/99-timeouts.conf`**

```
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=30s
DefaultTimeoutAbortSec=10s
ShutdownWatchdogSec=1min
```

**Docker** — `TimeoutStopSec=30s` override.

**NetworkManager** — `TimeoutStopSec=15s` override.

**Driver unload service:** `mt7902-driver-shutdown.service` (`modprobe -r mt7902e` before shutdown).

## What is autoloaded (and what is not)

The `mt7902.sh` script is **not** added to boot autostart and does **not** run as a daemon. You run it manually for install / verify / rollback / remove.

After install, the system keeps:

| Item | Location | Purpose |
|------|----------|---------|
| Module `mt7902e` | `/etc/modules-load.d/mt7902.conf` | Wi‑Fi autoload at boot |
| Module `btusb_mt7902` | `/etc/modules-load.d/btusb_mt7902.conf` | Bluetooth autoload at boot |
| Blacklist `btusb`/`btmtk` | `/etc/modprobe.d/blacklist_btusb.conf` | keep stock BT stack unloaded |
| systemd timeouts | `/etc/systemd/system.conf.d/99-timeouts.conf` + Docker/NM overrides | faster shutdown |
| `mt7902-driver-shutdown.service` | systemd, `enable` | oneshot: unload `mt7902e` before shutdown |
| `docker-shutdown.service` | systemd (if Docker present) | oneshot: stop containers before shutdown |

Check module autoload:

```bash
cat /etc/modules-load.d/mt7902.conf
cat /etc/modules-load.d/btusb_mt7902.conf
systemctl is-enabled mt7902-driver-shutdown.service
```

## Commands

### Tests (run first)

```bash
./tests/run-tests.sh   # safety: patch must not harm the system
make test              # same
make test-hw           # after install on hardware
```

### `mt7902.sh`

```bash
sudo ./mt7902.sh install-all  # Wi‑Fi + Bluetooth + systemd
sudo ./mt7902.sh install      # Wi‑Fi + system
sudo ./mt7902.sh driver       # Wi‑Fi only
sudo ./mt7902.sh bluetooth    # Bluetooth only
sudo ./mt7902.sh system       # systemd only
./mt7902.sh verify
./mt7902.sh status
sudo ./mt7902.sh rollback     # restore settings from before install
./mt7902.sh diagnose
sudo ./mt7902.sh remove
./mt7902.sh patch             # kernel patch prep (needs kernel tree)
./mt7902.sh help
```

### Makefile

```bash
make test
make test-hw
make quick-install
sudo make install
sudo make bluetooth
make check-status
make diagnose
sudo make uninstall
make help
```

## Diagnostics

```bash
./mt7902.sh diagnose
make diagnose

lsmod | grep -E 'mt7902e|btusb_mt7902'
lspci -nnk | grep -A3 -i mediatek
lsusb | grep -i 13d3
ip -br link
nmcli device status
bluetoothctl show
journalctl -b | grep -iE 'mt7902|btusb_mt7902|mediatek' | tail -40
```

## Requirements

- OS: Ubuntu/Debian (recommended), Fedora, etc.
- Kernel: **6.6+** for the current backport
- Packages: `build-essential`, `linux-headers-$(uname -r)`, `git`, `dkms`
- Secure Boot: disabled or modules signed (MOK)
- Device: MT7902 (`14c3:7902`)

## Results

| Item | Before | After |
|------|--------|-------|
| MT7902 Wi‑Fi | Broken | `mt7902e`, interface UP |
| MT7902 Bluetooth | Timeout / zero address | MediaTek HCI UP |
| Shutdown | Hang | 15–30 s |
| Autoload | Missing | `modules-load.d` + DKMS |

## Maintenance

```bash
# Rebuild after kernel update if DKMS did not run
cd gen4-mt7902 && make clean && sudo make install && sudo make install_fw
cd ../btusb_mt7902 && make clean && sudo make install && sudo make install_fw

# Or via DKMS
sudo dkms install -m mt7902e -v git --force
sudo dkms install -m btusb_mt7902 -v git --force
```

## Project layout

```
FIX-MediaTek-MT7902-MT7921-MT7961-WIFI/
├── mt7902.sh           # Wi‑Fi / BT / system / patches
├── Makefile
├── tests/run-tests.sh  # Safety tests (do not harm the system)
├── gen4-mt7902/        # Wi‑Fi (mt7902e)
├── btusb_mt7902/       # Bluetooth (btusb_mt7902)
├── patches/            # PCI ID patches for upstream
├── GUIDE_EN.md
├── GUIDE_RU.md
├── README.md
└── LICENSE
```

## Ready

```bash
./tests/run-tests.sh
sudo ./mt7902.sh install-all
sudo reboot
```
