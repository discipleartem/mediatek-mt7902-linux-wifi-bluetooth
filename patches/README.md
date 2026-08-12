# Патчи и драйверы MediaTek MT7902 / MT7921 / MT7961

## Назначение

Набор исправлений для Linux, связанных с чипсетами MediaTek семейства mt76:

| Цель | Что чинит |
|------|-----------|
| **MT7902 Wi‑Fi** | PCI ID `14c3:7902` (AzureWave `1a3b:5524`) — основной out-of-tree драйвер `mt7902e` |
| **MT7902 Bluetooth** | USB combo (часто `13d3:3594`) — драйвер `btusb_mt7902` |
| **MT7921 / MT7961** | Исторические патчи добавления ID в in-tree `mt7921`; на новых ядрах эти чипы обычно уже работают |

## Файлы в `patches/`

| Файл | Описание |
|------|----------|
| `0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch` | Патч для отправки в ядро: добавить PCI ID `0x7902` в `mt7921` |
| `mt7921_add_7902.patch` | Упрощённый вариант того же изменения |
| `mt7921_metadata.patch` | Метаданные |
| `README.md` | Этот файл |

> Для **практической** установки на ядрах 6.6–7.0 используйте каталоги `gen4-mt7902/` (Wi‑Fi) и `btusb_mt7902/` (Bluetooth), а не только эти diff‑патчи. Патчи в `patches/` полезны для upstream / сборки своего ядра.

## Bluetooth fix (добавлено в проекте)

### Проблема

Штатные `btusb` + `btmtk` не загружают прошивку MT7902:

- HCI с адресом `00:00:00:00:00:00`
- `Opcode 0x0c03 failed: -110`

### Решение

Out-of-tree модуль из [hmtheboy154/mt7902](https://github.com/hmtheboy154/mt7902) ветка **`bluetooth_backport`**:

```bash
# Клонирование (если ещё нет)
git clone -b bluetooth_backport https://github.com/hmtheboy154/mt7902.git btusb_mt7902

sudo ./mt7902.sh bluetooth
# или: cd btusb_mt7902 && make && sudo make install && sudo make install_fw
```

Прошивка: `mediatek/BT_RAM_CODE_MT7902_1_1_hdr.bin`

Обязательный blacklist (иначе конфликт с новым модулем):

```
# /etc/modprobe.d/blacklist_btusb.conf
blacklist btusb
blacklist btmtk
```

Upstream-патчи MediaTek для Bluetooth:  
https://lore.kernel.org/all/20260219231624.8226-1-sean.wang@kernel.org/

## Wi‑Fi fix

Практическая установка — модуль **`mt7902e`** из ветки **`backport`**:

```bash
git clone -b backport https://github.com/hmtheboy154/mt7902.git gen4-mt7902
sudo ./mt7902.sh install
```

Прошивка: `WIFI_MT7902_patch_mcu_1_1_hdr.bin`, `WIFI_RAM_CODE_MT7902_1.bin`

Upstream Wi‑Fi:  
https://lore.kernel.org/all/20260219004007.19733-1-sean.wang@kernel.org/

## Железо (кратко)

- **Карта:** MediaTek MT7902 Filogic 310, PCI `14c3:7902`, AzureWave `1a3b:5524`
- **Ноутбуки:** Acer Aspire A315-59 (проверено), A314-23P, A314-35, A315-24P, A114-33; Extensa 215-23 / 215-55 и др. с тем же PCI ID

Подробнее: корневой [README.md](../README.md), [GUIDE_RU.md](../GUIDE_RU.md), [GUIDE_EN.md](../GUIDE_EN.md).

## Исторический патч mt7921 (PCI ID 7902)

Ранний подход — добавить ID в in-tree `mt7921`. Для реального MT7902 предпочтителен отдельный драйвер `mt7902e` (своя прошивка и инициализация).

Пример изменения:

```c
{ PCI_DEVICE(PCI_VENDOR_ID_MEDIATEK, 0x7902),
    .driver_data = (kernel_ulong_t)MT7921_FIRMWARE_WM },
```

## Лицензия патчей

MIT для метаданных community patch; код драйверов в `gen4-mt7902/` и `btusb_mt7902/` — GPL (как в upstream mt76 / btusb).
