# Changelog

## 5.0 — 2026-07-16

- Wi‑Fi: out-of-tree `mt7902e` (ветка `backport` → `gen4-mt7902/`)
- Bluetooth: out-of-tree `btusb_mt7902` (ветка `bluetooth_backport` → `btusb_mt7902/`)
- Документация: поддерживаемые карты (MT7902 / MT7921 / MT7961) и ноутбуки Acer
- Скрипт: `install-all`, `bluetooth`, автоклон источников, модуль `mt7902e` вместо `mt7902`
- Makefile: `make bluetooth`, `make install-all` / `quick-install`
- Тесты: `tests/run-tests.sh` / `make test` — безопасность патча (не навредить системе); `make test-hw` на железе
- Откат: бэкап в `/var/lib/mt7902-fix/backup`, команда `sudo ./mt7902.sh rollback` если Wi‑Fi/BT не появились
- Документация: уточнено, что `mt7902.sh` не демон; автозагрузка — модули (`modules-load.d`) и oneshot systemd на shutdown
- AI discoverability: `llms.txt`, `llms-full.txt`, `AGENTS.md`, симптомы/PCI ID в README
- Проверено: Acer Aspire A315-59, Ubuntu 24.04, ядро 6.17

## 4.0 — 2026-02-25

- Унификация в `mt7902.sh` (Wi‑Fi + system + патчи)
- Двуязычные GUIDE_EN / GUIDE_RU
