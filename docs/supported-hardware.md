# Supported hardware — MediaTek MT7902

Hardware match for this **MediaTek MT7902 Linux** WiFi / Bluetooth driver pack.

See also: [Installation](installation.md) · [FAQ](faq.md) · [README](../README.md) · [RU](ru/supported-hardware.md)

![Architecture](images/architecture.svg)

## Primary chipset

| Chipset | Role | IDs | Driver in this project |
|---------|------|-----|------------------------|
| **MT7902** (Filogic 310) | Wi‑Fi 6 PCIe | PCI **`14c3:7902`**, subsystem AzureWave **`1a3b:5524`** | `mt7902e` |
| **MT7902** Bluetooth | USB (combo) | often USB **`13d3:3594`** (IMC Networks) | `btusb_mt7902` |

System name: *MediaTek MT7902 802.11ax PCIe Wireless Network Adapter [Filogic 310]*.

If `lspci` shows **`14c3:7902`**, this repository applies — even if your laptop model is not listed below.

## Related chips (usually already work in-tree)

| Chipset | PCI IDs | Driver |
|---------|---------|--------|
| MT7921 / MT7922 | `14c3:7921`, `14c3:7922`, … | stock `mt7921e` |
| MT7961 | `14c3:7961` | stock `mt7921e` |

Do **not** treat this pack as a general MT7921/MT7961 installer. Historical PCI-ID patches under `patches/` are not the preferred MT7902 fix.

## Laptops (community)

AzureWave MT7902 modules are common in **Acer Aspire** and **Acer Extensa**:

| Model | Status |
|-------|--------|
| **Aspire A315-59** | Verified in this project (Wi‑Fi + Bluetooth) |
| Aspire A314-23P | Community / [linux-hardware.org](https://linux-hardware.org/?id=pci%3A14c3-7902-1a3b-5524) |
| Aspire A314-35 | Community |
| Aspire A315-24P | Community |
| Aspire A114-33 | Community |
| Extensa 215-23 | Community |
| Extensa 215-55 | Community |

## Check your machine

```bash
lspci -nnk | grep -A3 -i 'network\|mediatek\|7902'
lsusb | grep -iE '13d3:3594|Wireless|MediaTek|Bluetooth'
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name
```

## Kernel compatibility

| Component | Source | Kernels |
|-----------|--------|---------|
| Wi‑Fi `mt7902e` | `gen4-mt7902/` ← `backport` | **6.6–6.19** |
| Bluetooth `btusb_mt7902` | `btusb_mt7902/` ← `bluetooth_backport` | **6.6–6.19** |
| Mainline | expected | **Linux 7.1+** |

Upstream: [hmtheboy154/mt7902](https://github.com/hmtheboy154/mt7902).

## Verified reference setup

| Item | Value |
|------|-------|
| Laptop | Acer Aspire A315-59 |
| Wi‑Fi | PCI `14c3:7902` / AzureWave `1a3b:5524` → `mt7902e` |
| Bluetooth | USB `13d3:3594` → `btusb_mt7902` |
| OS | Ubuntu 24.04 |
| Kernel | Linux 6.17 (HWE) |
