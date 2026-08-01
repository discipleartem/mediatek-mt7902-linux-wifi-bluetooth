# Поддерживаемое железо — MediaTek MT7902

Соответствие железа для пакета драйверов **MediaTek MT7902 Linux** (WiFi / Bluetooth).

См. также: [Установка](installation.md) · [FAQ](faq.md) · [README.ru](../../README.ru.md) · [EN](../supported-hardware.md)

![Architecture](../images/architecture.svg)

## Основной чипсет

| Чипсет | Роль | ID | Драйвер в этом проекте |
|--------|------|-----|------------------------|
| **MT7902** (Filogic 310) | Wi‑Fi 6 PCIe | PCI **`14c3:7902`**, subsystem AzureWave **`1a3b:5524`** | `mt7902e` |
| **MT7902** Bluetooth | USB (combo) | часто USB **`13d3:3594`** (IMC Networks) | `btusb_mt7902` |

Системное имя: *MediaTek MT7902 802.11ax PCIe Wireless Network Adapter [Filogic 310]*.

Если `lspci` показывает **`14c3:7902`**, этот репозиторий подходит — даже если модель ноутбука не указана ниже.

## Смежные чипы (обычно уже работают in-tree)

| Чипсет | PCI ID | Драйвер |
|--------|--------|---------|
| MT7921 / MT7922 | `14c3:7921`, `14c3:7922`, … | штатный `mt7921e` |
| MT7961 | `14c3:7961` | штатный `mt7921e` |

**Не** используйте этот пакет как общий установщик MT7921/MT7961. Исторический PCI-ID патч — в [`archive/mt7921-pci-id/`](../../archive/mt7921-pci-id/); предпочтительный фикс MT7902 — `mt7902e`.

## Ноутбуки (community)

Модули AzureWave MT7902 часто встречаются в **Acer Aspire** и **Acer Extensa**:

| Модель | Статус |
|--------|--------|
| **Aspire A315-59** | Проверено в этом проекте (Wi‑Fi + Bluetooth) |
| Aspire A314-23P | Community / [linux-hardware.org](https://linux-hardware.org/?id=pci%3A14c3-7902-1a3b-5524) |
| Aspire A314-35 | Community |
| Aspire A315-24P | Community |
| Aspire A114-33 | Community |
| Extensa 215-23 | Community |
| Extensa 215-55 | Community |

## Проверка машины

```bash
lspci -nnk | grep -A3 -i 'network\|mediatek\|7902'
lsusb | grep -iE '13d3:3594|Wireless|MediaTek|Bluetooth'
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name
```

## Совместимость ядер

| Компонент | Источник | Ядра |
|-----------|----------|------|
| Wi‑Fi `mt7902e` | `gen4-mt7902/` ← `backport` | **6.6–6.19** |
| Bluetooth `btusb_mt7902` | `btusb_mt7902/` ← `bluetooth_backport` | **6.6–6.19** |
| Mainline | ожидается | **Linux 7.1+** |

Upstream: [hmtheboy154/mt7902](https://github.com/hmtheboy154/mt7902).

## Проверенная конфигурация

| Параметр | Значение |
|----------|----------|
| Ноутбук | Acer Aspire A315-59 |
| Wi‑Fi | PCI `14c3:7902` / AzureWave `1a3b:5524` → `mt7902e` |
| Bluetooth | USB `13d3:3594` → `btusb_mt7902` |
| ОС | Ubuntu 24.04 |
| Ядро | Linux 6.17 (HWE) |
