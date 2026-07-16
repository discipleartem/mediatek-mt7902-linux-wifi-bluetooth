# MediaTek MT7902 WiFi + Bluetooth — Полное руководство

## Обзор

Решение для встроенного combo‑адаптера **MediaTek MT7902** (Filogic 310) на Linux: Wi‑Fi (PCIe), Bluetooth (USB), прошивка, автозагрузка и оптимизация выключения системы.

На ядрах **до 7.1** чип MT7902 обычно «unclaimed». Проект ставит community backport‑драйверы и системные настройки.

## Поддерживаемое железо

### Сетевые карты / чипсеты

| Чипсет | Роль | Идентификаторы | Модуль |
|--------|------|----------------|--------|
| **MT7902** | Wi‑Fi 6 PCIe | PCI `14c3:7902`, subsystem AzureWave `1a3b:5524` | `mt7902e` |
| **MT7902** | Bluetooth USB (combo) | часто USB `13d3:3594` (IMC Networks / MediaTek) | `btusb_mt7902` |
| MT7921 / MT7922 | Wi‑Fi PCIe | `14c3:7921`, `14c3:7922`, … | штатный `mt7921e` (уже в ядре) |
| MT7961 | Wi‑Fi PCIe | `14c3:7961` | штатный `mt7921e` (уже в ядре) |

Имя в системе: *MediaTek MT7902 802.11ax PCIe Wireless Network Adapter [Filogic 310]*.

Проверка:

```bash
lspci -nnk | grep -A3 -i 'network\|mediatek\|7902'
lsusb | grep -iE '13d3:3594|Wireless|MediaTek|Bluetooth'
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name
```

### Ноутбуки

Модуль AzureWave MT7902 чаще всего стоит в ноутбуках **Acer**:

| Модель | Примечание |
|--------|------------|
| **Aspire A315-59** | Проверено в этом проекте (Wi‑Fi + Bluetooth) |
| Aspire A314-23P | Часто встречается на [linux-hardware.org](https://linux-hardware.org/?id=pci%3A14c3-7902-1a3b-5524) |
| Aspire A314-35 | Сообщество |
| Aspire A315-24P | Сообщество |
| Aspire A114-33 | Сообщество |
| Extensa 215-23 | Сообщество |
| Extensa 215-55 | Сообщество |

Подойдёт любой ПК/ноутбук с PCI ID **`14c3:7902`**. Список моделей расширяется по мере отчётов пользователей.

### Совместимость ядра

| Компонент | Источник | Ядра |
|-----------|----------|------|
| Wi‑Fi `mt7902e` | `gen4-mt7902/` ← ветка `backport` | 6.6–6.19 |
| Bluetooth `btusb_mt7902` | `btusb_mt7902/` ← ветка `bluetooth_backport` | 6.6–6.19 |
| Mainline | ожидается в Linux **7.1+** | — |

Репозиторий драйверов: [hmtheboy154/mt7902](https://github.com/hmtheboy154/mt7902).

## Тесты (сначала)

Перед установкой или правками в репозитории:

```bash
./tests/run-tests.sh
# или
make test
```

Тесты не требуют root и железа. После установки: `make test-hw` / `./mt7902.sh verify`.

## Быстрый старт

```bash
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) git dkms

# Wi‑Fi + Bluetooth + systemd одним шагом
sudo ./mt7902.sh install-all

sudo reboot
```

Эквивалент по частям: `sudo ./mt7902.sh install` затем `sudo ./mt7902.sh bluetooth`.

После перезагрузки:

```bash
lsmod | grep -E 'mt7902e|btusb_mt7902'
nmcli device status
bluetoothctl show
./mt7902.sh verify
```

### Проверено на стенде

| Параметр | Значение |
|----------|----------|
| Ноутбук | Acer Aspire A315-59 |
| Wi‑Fi | PCI `14c3:7902` / AzureWave `1a3b:5524` → `mt7902e`, интерфейс `wlp42s0` |
| Bluetooth | USB `13d3:3594` → `btusb_mt7902`, HCI MediaTek 5.2, Powered |
| Ядро | Linux 6.17 (Ubuntu 24.04 HWE) |
| ОС | Ubuntu 24.04 |
## Wi‑Fi

### Характеристики

- **Устройство:** MediaTek MT7902
- **PCI ID:** `14c3:7902`
- **Драйвер:** `mt7902e`
- **Прошивка:** `mediatek/WIFI_MT7902_patch_mcu_1_1_hdr.bin`, `mediatek/WIFI_RAM_CODE_MT7902_1.bin`
- **Интерфейс:** обычно `wlan0`, после udev может стать `wlpXsY` (например `wlp42s0`)

### Проверка

```bash
lsmod | grep mt7902e
lspci -nnk | grep -A3 7902
ip -br link
nmcli device status
```

### Типичные проблемы

**Драйвер не загружается**

```bash
sudo modprobe -r mt7902e
sudo modprobe mt7902e
sudo systemctl restart NetworkManager
```

**Нет интерфейса / нет сетей**

```bash
journalctl -b | grep -i mt7902e | tail -30
ls /lib/firmware/mediatek/WIFI_MT7902*
```

При dual-boot с Windows отключите **Fast Startup** в Windows — иначе карта может не инициализироваться в Linux.

## Bluetooth

### Симптомы до фикса

- `bluetoothctl show` → *No default controller*
- `hciconfig`: адрес `00:00:00:00:00:00`, состояние `DOWN`
- В логах: `Bluetooth: hciX: Opcode 0x0c03 failed: -110`

### Установка

```bash
sudo ./mt7902.sh bluetooth
# или
sudo make bluetooth
```

Что делает установка:

1. Собирает и ставит модуль `btusb_mt7902`
2. Ставит прошивку `mediatek/BT_RAM_CODE_MT7902_1_1_hdr.bin`
3. Пишет blacklist штатных модулей в `/etc/modprobe.d/blacklist_btusb.conf`:
   ```
   blacklist btusb
   blacklist btmtk
   ```
4. Включает автозагрузку `btusb_mt7902`
5. (Опционально) регистрирует DKMS

### Проверка

```bash
lsmod | grep btusb_mt7902
hciconfig -a
bluetoothctl show
# Ожидается: Manufacturer MediaTek, Powered yes, валидный BD Address
```

### Важно

- Штатные `btusb` / `btmtk` **конфликтуют** с `btusb_mt7902` — их нужно выгрузить и заблокировать.
- Bluetooth на USB‑донгле Realtek (через `btusb`) после blacklist **перестанет** работать.
- Wi‑Fi на USB Realtek (`rtw88` и т.п.) не затрагивается.

### Перезагрузка драйвера BT

```bash
sudo systemctl stop bluetooth
sudo modprobe -r btusb_mt7902
sudo modprobe btusb_mt7902
sudo systemctl start bluetooth
```

## Системные оптимизации

### Проблема: зависание при выключении

Частые причины:

- Бесконечные таймауты Docker (`TimeoutStopUSec=infinity`)
- Проблемы с выгрузкой Wi‑Fi драйвера
- Долгая остановка NetworkManager

### Решение (ставится через `./mt7902.sh system` или `install`)

**`/etc/systemd/system.conf.d/99-timeouts.conf`**

```
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=30s
DefaultTimeoutAbortSec=10s
ShutdownWatchdogSec=1min
```

**Docker** — `TimeoutStopSec=30s` в override.

**NetworkManager** — `TimeoutStopSec=15s` в override.

**Сервис выгрузки драйвера:** `mt7902-driver-shutdown.service` (`modprobe -r mt7902e` перед shutdown).

## Установка и команды

### Тесты (запускать первыми)

```bash
./tests/run-tests.sh   # smoke-тесты репозитория
make test              # то же
make test-hw           # после установки на железе
```

### Скрипт `mt7902.sh`

```bash
sudo ./mt7902.sh install-all  # Wi‑Fi + Bluetooth + systemd
sudo ./mt7902.sh install      # Wi‑Fi + system
sudo ./mt7902.sh driver       # только Wi‑Fi
sudo ./mt7902.sh bluetooth    # только Bluetooth
sudo ./mt7902.sh system       # только systemd
./mt7902.sh verify
./mt7902.sh status
./mt7902.sh diagnose
sudo ./mt7902.sh remove
./mt7902.sh patch             # подготовка патчей для ядра (нужно дерево kernel)
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

## Диагностика

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

## Требования

- ОС: Ubuntu/Debian (рекомендуется), Fedora и др.
- Ядро: **6.6+** для текущего backport
- Пакеты: `build-essential`, `linux-headers-$(uname -r)`, `git`, `dkms`
- Secure Boot: выключен или модули подписаны (MOK)
- Устройство: MT7902 (`14c3:7902`)

## Результаты

| Параметр | До | После |
|----------|----|-------|
| Wi‑Fi MT7902 | Не работает | `mt7902e`, интерфейс UP |
| Bluetooth MT7902 | Таймаут / нулевой адрес | MediaTek HCI UP |
| Выключение | Зависание | 15–30 с |
| Автозагрузка | Нет | `modules-load.d` + DKMS |

## Обслуживание

```bash
# Пересборка после обновления ядра (если DKMS не сработал)
cd gen4-mt7902 && make clean && sudo make install && sudo make install_fw
cd ../btusb_mt7902 && make clean && sudo make install && sudo make install_fw

# Или через DKMS
sudo dkms install -m mt7902e -v git --force
sudo dkms install -m btusb_mt7902 -v git --force
```

## Структура проекта

```
FIX-MediaTek-MT7902-MT7921-MT7961-WIFI/
├── mt7902.sh           # Установка Wi‑Fi / BT / system / патчи
├── Makefile
├── tests/run-tests.sh  # Smoke-тесты (запускать первыми)
├── gen4-mt7902/        # Wi‑Fi (mt7902e)
├── btusb_mt7902/       # Bluetooth (btusb_mt7902)
├── patches/            # Патчи PCI ID для отправки в ядро
├── GUIDE_EN.md
├── GUIDE_RU.md
├── README.md
└── LICENSE
```

## Готово

```bash
./tests/run-tests.sh
sudo ./mt7902.sh install-all
sudo reboot
```
