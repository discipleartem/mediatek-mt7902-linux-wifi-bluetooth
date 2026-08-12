# Установка — драйвер MediaTek MT7902 для Linux

Установка WiFi и Bluetooth **MediaTek MT7902** на Linux (**Ubuntu 24.04**, Ubuntu 26.04, Debian, Fedora, Arch). Исправляет **неработающий WiFi** и **отсутствие Bluetooth** для PCI ID **14c3:7902**.

См. также: [FAQ](faq.md) · [Поддерживаемое железо](supported-hardware.md) · [README.ru](../../README.ru.md) · [EN](../installation.md)

## Требования

- Чип: MediaTek **MT7902** / Filogic 310 (`lspci` → `14c3:7902`)
- Ядро **6.6–7.0** для текущих backport (в mainline MT7902 ожидается в **7.1+**)
- Secure Boot **выключен**, либо подпись out-of-tree модулей (MOK) — см. [FAQ](faq.md#ошибка-secure-boot-при-загрузке-модулей)
- Пакеты: build tools, заголовки ядра, `git`, `dkms`

### Ubuntu / Debian (включая Ubuntu 24.04 и 26.04)

```bash
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) git dkms
```

### Fedora / RHEL-подобные

```bash
sudo dnf install -y kernel-devel-$(uname -r) gcc make git dkms
```

### Arch Linux

```bash
sudo pacman -S --needed base-devel linux-headers git dkms
```

## Рекомендуемая установка (WiFi + Bluetooth)

Сначала safety-тесты — пакет блокирует `btusb`/`btmtk` и должен оставаться откатываемым:

```bash
git clone https://github.com/discipleartem/mediatek-mt7902-linux-wifi-bluetooth.git
cd mediatek-mt7902-linux-wifi-bluetooth
./tests/run-tests.sh
# или: make test
sudo ./mt7902.sh install-all
sudo reboot
./mt7902.sh verify
```

Тесты не требуют root и железа. После установки на железе: `make test-hw`.

Исходники драйверов в `gen4-mt7902/` и `btusb_mt7902/` **клонируются автоматически**, если их нет.

## Частичная установка

| Цель | Команда |
|------|---------|
| Wi‑Fi + системные настройки | `sudo ./mt7902.sh install` |
| Только Wi‑Fi драйвер | `sudo ./mt7902.sh driver` |
| Только Bluetooth | `sudo ./mt7902.sh bluetooth` |
| systemd таймауты / unload | `sudo ./mt7902.sh system` |

`bluetooth` конфликтует со штатным `btusb` — см. [FAQ](faq.md#сломается-ли-мой-realtek-usb-bluetooth-адаптер).

## Проверка

```bash
lsmod | grep -E 'mt7902e|btusb_mt7902'
lspci -nnk | grep -A3 7902
nmcli device status
bluetoothctl show
./mt7902.sh verify
./mt7902.sh diagnose
```

Чеклист: [../images/verify-checklist.svg](../images/verify-checklist.svg)

Ожидается:

- `Kernel driver in use: mt7902e`
- интерфейс `wlan*` или `wlp*` UP
- `bluetoothctl show` → Manufacturer MediaTek, Powered: yes

## Откат / удаление

Установщик сохраняет оригиналы в `/var/lib/mt7902-fix/backup`.

```bash
sudo ./mt7902.sh rollback    # восстановить конфиги до установки
sudo ./mt7902.sh remove      # удалить пакет (использует backup при наличии)
```

При ошибке загрузки модуля установщик предлагает rollback. Без интерактива:

```bash
MT7902_AUTO_ROLLBACK=1 sudo ./mt7902.sh install-all
```

## Что автозагружается (и что нет) {#autoload}

Скрипт `mt7902.sh` **не** добавляется в автозапуск и **не** работает как демон. Его запускают вручную для install / verify / rollback / remove / watchdog.

После `install-all` в системе могут остаться:

| Элемент | Расположение | Назначение |
|---------|--------------|------------|
| Модуль `mt7902e` | `/etc/modules-load.d/mt7902.conf` | автозагрузка Wi‑Fi при boot |
| Модуль `btusb_mt7902` | `/etc/modules-load.d/btusb_mt7902.conf` | автозагрузка Bluetooth при boot |
| Blacklist `btusb`/`btmtk` | `/etc/modprobe.d/blacklist_btusb.conf` | не грузить штатный BT stack |
| systemd таймауты | `/etc/systemd/system.conf.d/99-timeouts.conf` + overrides Docker/NM | быстрее выключение |
| `mt7902-driver-shutdown.service` | systemd, enabled | oneshot: unload `mt7902e` перед shutdown |
| `mt7902-watchdog.service` | systemd, enabled | перезагрузка `mt7902e` / `btusb_mt7902` если они пропали (не полная переустановка) |
| `docker-shutdown.service` | systemd (если есть Docker) | oneshot: остановить контейнеры перед shutdown |

Проверка:

```bash
cat /etc/modules-load.d/mt7902.conf
cat /etc/modules-load.d/btusb_mt7902.conf
systemctl is-enabled mt7902-driver-shutdown.service
systemctl is-active mt7902-watchdog.service
```

### Systemd таймауты при выключении

`./mt7902.sh system` (также часть `install` / `install-all`) пишет:

**`/etc/systemd/system.conf.d/99-timeouts.conf`**

```
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=30s
DefaultTimeoutAbortSec=10s
ShutdownWatchdogSec=1min
```

Также: Docker `TimeoutStopSec=30s`, NetworkManager `TimeoutStopSec=15s`, и `mt7902-driver-shutdown.service` (`modprobe -r mt7902e` перед shutdown).

## Команды

### `mt7902.sh`

```bash
sudo ./mt7902.sh install-all  # Wi‑Fi + Bluetooth + systemd
sudo ./mt7902.sh install      # Wi‑Fi + система
sudo ./mt7902.sh driver       # только Wi‑Fi
sudo ./mt7902.sh bluetooth    # только Bluetooth
sudo ./mt7902.sh system       # только systemd
./mt7902.sh verify
./mt7902.sh status            # alias verify
sudo ./mt7902.sh rollback     # восстановить настройки до установки
sudo ./mt7902.sh watchdog     # фоновый ремонт, если Wi‑Fi/BT пропали
sudo ./mt7902.sh watchdog-stop
./mt7902.sh diagnose
sudo ./mt7902.sh remove
./mt7902.sh help
```

Алиасы: `all` → `install-all`, `bt` → `bluetooth`, `restore` → `rollback`.

Структура: тонкий `mt7902.sh` + `lib/*.sh` (Wi‑Fi, Bluetooth, systemd, backup, verify).

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

Достаточно одной команды (модули, PCI/USB, NM, BT, логи MediaTek):

```bash
./mt7902.sh diagnose
```

## Обслуживание

После обновления ядра, если DKMS не пересобрал модули:

```bash
cd gen4-mt7902 && make clean && sudo make install && sudo make install_fw
cd ../btusb_mt7902 && make clean && sudo make install && sudo make install_fw

# Или через DKMS
sudo dkms install -m mt7902e -v git --force
sudo dkms install -m btusb_mt7902 -v git --force
```
