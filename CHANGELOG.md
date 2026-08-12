# Changelog

## 5.2 — 2026-08-12

- Проверено: Acer Aspire A315-59, Ubuntu 24.04.4, ядро **7.0.0-28-generic** (Wi‑Fi `wlp42s0` + BT Powered)
- Диапазон backport: **6.6–7.0** (mainline MT7902 по-прежнему ожидается в 7.1+)
- `diagnose`: логи только MediaTek/mt7902 (не gnome/livepatch `-p err`), плюс NM и краткий итог

## 5.1 — 2026-07-16

- Репозиторий переименован: `mediatek-mt7902-linux-wifi-bluetooth` (старый URL редиректит)
- AI discoverability: усилены `llms.txt` / `llms-full.txt` / README / `AGENTS.md` (match criteria, cite URL, agent directives)
- GitHub About/topics: `scripts/set-github-discoverability.sh`

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
- Проверено: Acer Aspire A315-59, Ubuntu 24.04, ядро 6.17 (стенд обновлён до 7.0 в 5.2)

## 4.0 — 2026-02-25

- Унификация в `mt7902.sh` (Wi‑Fi + system + патчи)
- Двуязычные GUIDE_EN / GUIDE_RU
