# FAQ — MediaTek MT7902 Linux WiFi / Bluetooth

Common questions for **WiFi not working**, **Bluetooth missing**, **Ubuntu 24.04**, PCI **14c3:7902**, and MediaTek MT7902.

See also: [Installation](installation.md) · [Supported hardware](supported-hardware.md) · [README](../README.md) · [RU](ru/faq.md)

## WiFi not working — is this the right fix?

Yes, if `lspci -nn` shows **`14c3:7902`** (MediaTek MT7902 / Filogic 310) and there is no `Kernel driver in use` / no `wlan*` or `wlp*`.

```bash
sudo ./mt7902.sh install-all && sudo reboot
```

If your ID is `14c3:7921` / `7961`, try stock `mt7921e` first — this pack is for **MT7902**.

### Driver not loading

```bash
sudo modprobe -r mt7902e
sudo modprobe mt7902e
sudo systemctl restart NetworkManager
```

### No interface / no networks

```bash
journalctl -b | grep -i mt7902e | tail -30
ls /lib/firmware/mediatek/WIFI_MT7902*
```

On Windows dual-boot, disable **Fast Startup** — otherwise the card may fail to initialize under Linux.

Firmware files: `mediatek/WIFI_MT7902_patch_mcu_1_1_hdr.bin`, `mediatek/WIFI_RAM_CODE_MT7902_1.bin`. Interface is usually `wlan0` or renamed `wlpXsY`.

## Why is Bluetooth missing / Opcode 0x0c03 failed: -110?

Stock `btusb` + `btmtk` often fail firmware setup on MT7902 combo USB (e.g. `13d3:3594`). Symptoms:

- BD address `00:00:00:00:00:00`
- `No default controller`
- dmesg: `Opcode 0x0c03 failed: -110`

Install `btusb_mt7902` via `install-all` or `sudo ./mt7902.sh bluetooth`.

What Bluetooth install does:

1. Builds and installs `btusb_mt7902`
2. Installs firmware `mediatek/BT_RAM_CODE_MT7902_1_1_hdr.bin`
3. Blacklists stock modules in `/etc/modprobe.d/blacklist_btusb.conf` (`blacklist btusb`, `blacklist btmtk`)
4. Enables autoload of `btusb_mt7902`
5. Optionally registers DKMS

### Reload Bluetooth driver

```bash
sudo systemctl stop bluetooth
sudo modprobe -r btusb_mt7902
sudo modprobe btusb_mt7902
sudo systemctl start bluetooth
```

## Does install work on Ubuntu 24.04 / Ubuntu 26.04?

Yes. Ubuntu **24.04** is verified (Aspire A315-59). Ubuntu **26.04** and other Debian-family distros use the same `apt` + headers + DKMS flow. Also used on Fedora, Arch, Mint, Pop!_OS with matching kernel headers.

## Will this break my Realtek USB Bluetooth dongle?

Possibly. Bluetooth install **blacklists `btusb` and `btmtk`**. Built-in MT7902 BT works; adapters that need stock `btusb` (many Realtek USB sticks) will stop. USB Wi‑Fi (`rtw88`, etc.) is unaffected.

## Secure Boot error when loading modules?

Out-of-tree `mt7902e` / `btusb_mt7902` must be allowed:

- Disable Secure Boot in firmware setup, **or**
- Sign the modules and enroll the key with **MOK** (Machine Owner Key)

Unsigned modules will fail to load while Secure Boot is on.

## Wi‑Fi or Bluetooth drops after a while?

`install-all` enables `mt7902-watchdog.service`. It only **reloads** `mt7902e` / `btusb_mt7902` (same as the installer load path) when the module or interface disappears. It does not reinstall and it skips repair if you turned Wi‑Fi/BT off (`rfkill` / `nmcli radio wifi off`).

```bash
sudo ./mt7902.sh watchdog        # enable + start
sudo ./mt7902.sh watchdog-stop   # disable
mt7902-watchdog --check          # status
```

## Shutdown hangs after install?

The pack installs systemd timeout overrides and `mt7902-driver-shutdown.service` to unload drivers cleanly. Re-run `sudo ./mt7902.sh system` if those units were skipped. Details: [Installation — autoload](installation.md#autoload). Diagnose with `./mt7902.sh diagnose`.

## Can I only add PCI ID 7902 to mt7921e?

No. That is incomplete for MT7902. Use dedicated module **`mt7902e`** from this repository (or wait for mainline **7.1+**).

## How do I undo everything?

```bash
sudo ./mt7902.sh rollback
# or
sudo ./mt7902.sh remove
```

Backup path: `/var/lib/mt7902-fix/backup`.

## Tests failed / I want to be safe before install

```bash
./tests/run-tests.sh
# or: make test
```

Tests need no root and no hardware. They check that blacklist/side effects stay scoped and reversible.

## Where do I report bugs or send PRs?

Bug reports welcome. Pull requests welcome. See [CONTRIBUTING.md](../CONTRIBUTING.md). Tested primarily on Ubuntu 24.04.
