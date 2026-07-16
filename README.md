# MediaTek MT7902 / MT7921 / MT7961 — WiFi + Bluetooth

Решение для встроенных Wi‑Fi/Bluetooth адаптеров MediaTek на Linux: out-of-tree драйверы, прошивка, автозагрузка и системные оптимизации.

## Поддерживаемое железо

### Сетевые карты (чипсеты)

| Чипсет | Интерфейс | ID | Драйвер в проекте | Примечание |
|--------|-----------|-----|-------------------|------------|
| **MT7902** (Filogic 310) | PCIe Wi‑Fi 6 | `14c3:7902` | `mt7902e` | Основная цель проекта |
| **MT7902** Bluetooth | USB (combo) | часто `13d3:3594` (IMC Networks) | `btusb_mt7902` | Отдельная установка |
| MT7921 / MT7922 | PCIe | `14c3:7921`, `14c3:7922`, … | штатный `mt7921e` | Обычно уже в ядре |
| MT7961 | PCIe | `14c3:7961` | штатный `mt7921e` | Обычно уже в ядре |

Типичный OEM‑модуль MT7902:

- **Subsystem:** AzureWave `1a3b:5524`
- **Имя:** MediaTek MT7902 802.11ax PCIe Wireless Network Adapter [Filogic 310]
- **Bluetooth:** тот же combo‑чип по USB (например IMC Networks `13d3:3594`)

Проверка у себя:

```bash
lspci -nnk | grep -A3 -i network
lsusb | grep -iE '13d3|0e8d|Wireless|Bluetooth'
```

### Ноутбуки (проверено сообществом)

Карта AzureWave MT7902 (`14c3:7902` / `1a3b:5524`) встречается в основном в линейках **Acer Aspire** и **Acer Extensa**:

| Производитель | Модели (примеры) | Статус |
|---------------|------------------|--------|
| Acer | **Aspire A315-59** | ✅ Проверено в этом проекте (Wi‑Fi + BT) |
| Acer | Aspire A314-23P, A314-35 | Сообщество / [linux-hardware.org](https://linux-hardware.org/?id=pci%3A14c3-7902-1a3b-5524) |
| Acer | Aspire A315-24P, A114-33 | Сообщество |
| Acer | Extensa 215-23, Extensa 215-55 | Сообщество |

Список неполный: подойдёт любой ноутбук, где `lspci` показывает `14c3:7902` (и для BT — USB‑часть combo‑чипа MediaTek).

> **Ядро:** out-of-tree драйверы рассчитаны на **6.6–6.19**. Нативная поддержка MT7902 ожидается в Linux **7.1+**.

## Что решает

- Wi‑Fi MT7902 не поднимается (устройство «unclaimed»)
- Bluetooth MT7902: `hci` с адресом `00:00:00:00:00:00`, таймауты `Opcode … failed: -110`
- Зависание при выключении из‑за драйвера / Docker / NetworkManager
- Нет автозагрузки модулей после перезагрузки

## Быстрый старт

```bash
# Зависимости
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) git dkms

# Wi‑Fi + Bluetooth + systemd (рекомендуется)
sudo ./mt7902.sh install-all

# Перезагрузка
sudo reboot
```

По частям: `sudo ./mt7902.sh install` (Wi‑Fi) и `sudo ./mt7902.sh bluetooth` (BT; конфликтует со штатным `btusb`).
Проверка после установки:

```bash
lsmod | grep -E 'mt7902e|btusb_mt7902'
lspci -nnk | grep -A2 7902
nmcli device status
bluetoothctl show
```

## Структура проекта

```
FIX-MediaTek-MT7902-MT7921-MT7961-WIFI/
├── mt7902.sh              # Универсальный скрипт (Wi‑Fi, BT, system, патчи)
├── Makefile
├── gen4-mt7902/           # Wi‑Fi: hmtheboy154/mt7902 (ветка backport) → модуль mt7902e
├── btusb_mt7902/          # Bluetooth: та же репа, ветка bluetooth_backport
├── patches/               # Патчи PCI ID / метаданные для ядра
├── GUIDE_EN.md
├── GUIDE_RU.md
├── README.md
└── LICENSE
```

Источники драйверов:

- Wi‑Fi: [hmtheboy154/mt7902](https://github.com/hmtheboy154/mt7902) (`backport`)
- Bluetooth: [hmtheboy154/mt7902](https://github.com/hmtheboy154/mt7902) (`bluetooth_backport`)

## Использование

```bash
sudo ./mt7902.sh install-all  # Wi‑Fi + Bluetooth + systemd
sudo ./mt7902.sh install      # Wi‑Fi + системные настройки
sudo ./mt7902.sh driver       # только Wi‑Fi драйвер
sudo ./mt7902.sh bluetooth    # Bluetooth драйвер + прошивка
sudo ./mt7902.sh system       # только systemd-оптимизации
./mt7902.sh verify            # проверка
./mt7902.sh diagnose          # диагностика
sudo ./mt7902.sh remove       # удаление настроек/автозагрузки
./mt7902.sh help
```

Makefile:

```bash
make quick-install    # через mt7902.sh install
sudo make install     # сборка/установка Wi‑Fi
sudo make bluetooth   # сборка/установка Bluetooth
make check-status
make diagnose
sudo make uninstall
```

> `mt7921e_simple_patch.c` — устаревший stub; для MT7902 используйте `mt7902e` / `btusb_mt7902`.
## Bluetooth — кратко

1. Устанавливается модуль `btusb_mt7902` и прошивка `mediatek/BT_RAM_CODE_MT7902_1_1_hdr.bin`
2. Штатные `btusb` и `btmtk` **блокируются** (`/etc/modprobe.d/blacklist_btusb.conf`) — они конфликтуют с backport
3. Bluetooth на USB‑адаптерах Realtek через `btusb` после этого **не будет** работать; Wi‑Fi USB (например `rtw88`) не затрагивается

Подробности: [GUIDE_RU.md](GUIDE_RU.md) / [GUIDE_EN.md](GUIDE_EN.md).

## Требования

- Ubuntu/Debian (рекомендуется), Fedora, RHEL-подобные
- Ядро **6.6+** (для текущего backport); Secure Boot лучше выключить или подписать модули
- Пакеты: `build-essential`, `linux-headers-$(uname -r)`, `git`, `dkms`
- Устройство: MediaTek **MT7902** (`14c3:7902`)

## Документация

- [GUIDE_RU.md](GUIDE_RU.md) — полное руководство (RU)
- [GUIDE_EN.md](GUIDE_EN.md) — complete guide (EN)
- `./mt7902.sh help` / `make help`

## Версия

**5.0** — Wi‑Fi (`mt7902e`) + Bluetooth (`btusb_mt7902`), описание поддерживаемого железа, DKMS.

---

```bash
sudo ./mt7902.sh install-all && sudo reboot
```