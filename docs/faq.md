# FAQ — MediaTek MT7902 Linux WiFi / Bluetooth

Common questions for **WiFi not working**, **Bluetooth missing**, **Ubuntu 24.04**, PCI **14c3:7902**, and MediaTek MT7902.

See also: [Installation](installation.md) · [Supported hardware](supported-hardware.md) · [GUIDE_EN.md](../GUIDE_EN.md)

## WiFi not working — is this the right fix?

Yes, if `lspci -nn` shows **`14c3:7902`** (MediaTek MT7902 / Filogic 310) and there is no `Kernel driver in use` / no `wlan*` or `wlp*`.

```bash
sudo ./mt7902.sh install-all && sudo reboot
```

If your ID is `14c3:7921` / `7961`, try stock `mt7921e` first — this pack is for **MT7902**.

## Why is Bluetooth missing / Opcode 0x0c03 failed: -110?

Stock `btusb` + `btmtk` often fail firmware setup on MT7902 combo USB (e.g. `13d3:3594`). Symptoms:

- BD address `00:00:00:00:00:00`
- `No default controller`
- dmesg: `Opcode 0x0c03 failed: -110`

Install `btusb_mt7902` via `install-all` or `sudo ./mt7902.sh bluetooth`.

## Does install work on Ubuntu 24.04 / Ubuntu 26.04?

Yes. Ubuntu **24.04** is verified (Aspire A315-59). Ubuntu **26.04** and other Debian-family distros use the same `apt` + headers + DKMS flow. Also used on Fedora, Arch, Mint, Pop!_OS with matching kernel headers.

## Will this break my Realtek USB Bluetooth dongle?

Possibly. Bluetooth install **blacklists `btusb` and `btmtk`**. Built-in MT7902 BT works; adapters that need stock `btusb` (many Realtek USB sticks) will stop. USB Wi‑Fi (`rtw88`, etc.) is unaffected.

## Secure Boot error when loading modules?

Out-of-tree `mt7902e` / `btusb_mt7902` must be allowed: disable Secure Boot in firmware, or sign modules with MOK. See GUIDE Secure Boot notes.

## Shutdown hangs after install?

The pack installs systemd timeout overrides and `mt7902-driver-shutdown.service` to unload drivers cleanly. Re-run `sudo ./mt7902.sh system` if those units were skipped. Diagnose with `./mt7902.sh diagnose`.

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
