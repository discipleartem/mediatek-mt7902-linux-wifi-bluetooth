# FAQ — MediaTek MT7902 Linux WiFi / Bluetooth

Частые вопросы про **неработающий WiFi**, **отсутствие Bluetooth**, **Ubuntu 24.04**, PCI **14c3:7902** и MediaTek MT7902.

См. также: [Установка](installation.md) · [Поддерживаемое железо](supported-hardware.md) · [README.ru](../../README.ru.md) · [EN](../faq.md)

## Не работает WiFi — это правильный фикс?

Да, если `lspci -nn` показывает **`14c3:7902`** (MediaTek MT7902 / Filogic 310) и нет `Kernel driver in use` / нет `wlan*` или `wlp*`.

```bash
sudo ./mt7902.sh install-all && sudo reboot
```

Если ID `14c3:7921` / `7961`, сначала попробуйте штатный `mt7921e` — этот пакет для **MT7902**.

### Драйвер не загружается

```bash
sudo modprobe -r mt7902e
sudo modprobe mt7902e
sudo systemctl restart NetworkManager
```

### Нет интерфейса / нет сетей

```bash
journalctl -b | grep -i mt7902e | tail -30
ls /lib/firmware/mediatek/WIFI_MT7902*
```

При dual-boot с Windows отключите **Fast Startup** — иначе карта может не инициализироваться под Linux.

Прошивки: `mediatek/WIFI_MT7902_patch_mcu_1_1_hdr.bin`, `mediatek/WIFI_RAM_CODE_MT7902_1.bin`. Интерфейс обычно `wlan0` или переименован в `wlpXsY`.

## Почему нет Bluetooth / Opcode 0x0c03 failed: -110?

Штатные `btusb` + `btmtk` часто не поднимают прошивку на MT7902 combo USB (например `13d3:3594`). Симптомы:

- BD-адрес `00:00:00:00:00:00`
- `No default controller`
- dmesg: `Opcode 0x0c03 failed: -110`

Установите `btusb_mt7902` через `install-all` или `sudo ./mt7902.sh bluetooth`.

Что делает установка Bluetooth:

1. Собирает и ставит `btusb_mt7902`
2. Ставит прошивку `mediatek/BT_RAM_CODE_MT7902_1_1_hdr.bin`
3. Блокирует штатные модули в `/etc/modprobe.d/blacklist_btusb.conf` (`blacklist btusb`, `blacklist btmtk`)
4. Включает автозагрузку `btusb_mt7902`
5. Опционально регистрирует DKMS

### Перезагрузка драйвера Bluetooth

```bash
sudo systemctl stop bluetooth
sudo modprobe -r btusb_mt7902
sudo modprobe btusb_mt7902
sudo systemctl start bluetooth
```

## Работает ли установка на Ubuntu 24.04 / Ubuntu 26.04?

Да. Ubuntu **24.04** проверена (Aspire A315-59). Ubuntu **26.04** и другие Debian-семейства используют тот же `apt` + headers + DKMS. Также на Fedora, Arch, Mint, Pop!_OS с подходящими заголовками ядра.

## Сломается ли мой Realtek USB Bluetooth-адаптер?

Возможно. Установка Bluetooth **блокирует `btusb` и `btmtk`**. Встроенный MT7902 BT работает; адаптеры, которым нужен штатный `btusb` (многие Realtek USB), перестанут. USB Wi‑Fi (`rtw88` и т.п.) не затрагивается.

## Ошибка Secure Boot при загрузке модулей?

Out-of-tree `mt7902e` / `btusb_mt7902` должны быть разрешены:

- Выключите Secure Boot в настройках прошивки, **или**
- Подпишите модули и зарегистрируйте ключ через **MOK** (Machine Owner Key)

Неподписанные модули не загрузятся при включённом Secure Boot.

## Зависание при выключении после установки?

Пакет ставит overrides таймаутов systemd и `mt7902-driver-shutdown.service` для корректной выгрузки драйверов. Повторите `sudo ./mt7902.sh system`, если юниты были пропущены. Подробнее: [Установка — autoload](installation.md#autoload). Диагностика: `./mt7902.sh diagnose`.

## Можно ли только добавить PCI ID 7902 в mt7921e?

Нет. Для MT7902 этого недостаточно. Используйте отдельный модуль **`mt7902e`** из этого репозитория (или дождитесь mainline **7.1+**).

## Как всё откатить?

```bash
sudo ./mt7902.sh rollback
# или
sudo ./mt7902.sh remove
```

Backup: `/var/lib/mt7902-fix/backup`.

## Тесты упали / хочу быть уверен перед установкой

```bash
./tests/run-tests.sh
# или: make test
```

Тесты не требуют root и железа. Они проверяют, что blacklist/побочные эффекты ограничены и обратимы.

## Куда слать багрепорты и PR?

Багрепорты и pull request приветствуются. См. [CONTRIBUTING.md](../../CONTRIBUTING.md). Основная проверка — Ubuntu 24.04.
