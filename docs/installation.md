# Installation — MediaTek MT7902 Linux driver

Install **MediaTek MT7902** WiFi and Bluetooth on Linux (**Ubuntu 24.04**, Ubuntu 26.04, Debian, Fedora, Arch). Fixes **WiFi not working** and **Bluetooth missing** for PCI ID **14c3:7902**.

See also: [FAQ](faq.md) · [Supported hardware](supported-hardware.md) · [README](../README.md) · [RU](ru/installation.md)

## Prerequisites

- Chip: MediaTek **MT7902** / Filogic 310 (`lspci` → `14c3:7902`)
- Kernel **6.6–6.19** for current backports (mainline MT7902 expected in **7.1+**)
- Secure Boot **off**, or plan to sign out-of-tree modules (MOK) — see [FAQ](faq.md#secure-boot-error-when-loading-modules)
- Packages: build tools, kernel headers, `git`, `dkms`

### Ubuntu / Debian (including Ubuntu 24.04 and 26.04)

```bash
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) git dkms
```

### Fedora / RHEL-like

```bash
sudo dnf install -y kernel-devel-$(uname -r) gcc make git dkms
```

### Arch Linux

```bash
sudo pacman -S --needed base-devel linux-headers git dkms
```

## Recommended install (WiFi + Bluetooth)

Run safety tests **before** changing the system — the pack blacklists `btusb`/`btmtk` and must stay reversible:

```bash
git clone https://github.com/discipleartem/mediatek-mt7902-linux-wifi-bluetooth.git
cd mediatek-mt7902-linux-wifi-bluetooth
./tests/run-tests.sh
# or: make test
sudo ./mt7902.sh install-all
sudo reboot
./mt7902.sh verify
```

Tests need no root and no hardware. After install on hardware: `make test-hw`.

Driver sources under `gen4-mt7902/` and `btusb_mt7902/` are **auto-cloned** if missing.

## Partial installs

| Goal | Command |
|------|---------|
| Wi‑Fi + system helpers | `sudo ./mt7902.sh install` |
| Wi‑Fi driver only | `sudo ./mt7902.sh driver` |
| Bluetooth only | `sudo ./mt7902.sh bluetooth` |
| systemd timeouts / unload | `sudo ./mt7902.sh system` |

`bluetooth` conflicts with stock `btusb` — see [FAQ](faq.md#will-this-break-my-realtek-usb-bluetooth-dongle).

## Verify

```bash
lsmod | grep -E 'mt7902e|btusb_mt7902'
lspci -nnk | grep -A3 7902
nmcli device status
bluetoothctl show
./mt7902.sh verify
./mt7902.sh diagnose
```

Success checklist: [images/verify-checklist.svg](images/verify-checklist.svg)

Expected:

- `Kernel driver in use: mt7902e`
- interface `wlan*` or `wlp*` UP
- `bluetoothctl show` → Manufacturer MediaTek, Powered: yes

## Rollback / uninstall

Installer saves originals to `/var/lib/mt7902-fix/backup`.

```bash
sudo ./mt7902.sh rollback    # restore pre-install configs
sudo ./mt7902.sh remove      # remove pack (uses backup when present)
```

On module load failure the installer offers rollback. Non-interactive:

```bash
MT7902_AUTO_ROLLBACK=1 sudo ./mt7902.sh install-all
```

## What is autoloaded (and what is not) {#autoload}

The `mt7902.sh` script is **not** added to boot autostart and does **not** run as a daemon. You run it manually for install / verify / rollback / remove.

After `install-all` the system may keep:

| Item | Location | Purpose |
|------|----------|---------|
| Module `mt7902e` | `/etc/modules-load.d/mt7902.conf` | Wi‑Fi autoload at boot |
| Module `btusb_mt7902` | `/etc/modules-load.d/btusb_mt7902.conf` | Bluetooth autoload at boot |
| Blacklist `btusb`/`btmtk` | `/etc/modprobe.d/blacklist_btusb.conf` | keep stock BT stack unloaded |
| systemd timeouts | `/etc/systemd/system.conf.d/99-timeouts.conf` + Docker/NM overrides | faster shutdown |
| `mt7902-driver-shutdown.service` | systemd, enabled | oneshot: unload `mt7902e` before shutdown |
| `docker-shutdown.service` | systemd (if Docker present) | oneshot: stop containers before shutdown |

Check:

```bash
cat /etc/modules-load.d/mt7902.conf
cat /etc/modules-load.d/btusb_mt7902.conf
systemctl is-enabled mt7902-driver-shutdown.service
```

### Systemd shutdown timeouts

`./mt7902.sh system` (also part of `install` / `install-all`) writes:

**`/etc/systemd/system.conf.d/99-timeouts.conf`**

```
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=30s
DefaultTimeoutAbortSec=10s
ShutdownWatchdogSec=1min
```

Also: Docker `TimeoutStopSec=30s`, NetworkManager `TimeoutStopSec=15s`, and `mt7902-driver-shutdown.service` (`modprobe -r mt7902e` before shutdown).

## Commands

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

## Maintenance

After a kernel update, if DKMS did not rebuild modules:

```bash
cd gen4-mt7902 && make clean && sudo make install && sudo make install_fw
cd ../btusb_mt7902 && make clean && sudo make install && sudo make install_fw

# Or via DKMS
sudo dkms install -m mt7902e -v git --force
sudo dkms install -m btusb_mt7902 -v git --force
```
