# Changelog

## 6.1.0 — 2026-08-12

- `mt7902-watchdog.service`: reloads `mt7902e` / `btusb_mt7902` if Wi‑Fi or Bluetooth drop (not a full reinstall)
- CLI: `sudo ./mt7902.sh watchdog` / `watchdog-stop`; `mt7902-watchdog --check`
- Skips repair when radio is intentionally off (`rfkill` / `nmcli radio wifi off`); rate-limited
- Rollback/remove disables the watchdog; `install-all` enables it

## 6.0.1 — 2026-08-12

- Verified on Acer Aspire A315-59, Ubuntu 24.04.4 LTS, kernel **7.0.0-28-generic** (`mt7902e` + `wlp42s0`, `btusb_mt7902` Powered)
- Documented backport range **6.6–7.0** (in-tree MT7902 still expected in Linux **7.1+**)
- `diagnose`: MediaTek/mt7902 logs only (not unrelated `journalctl -p err`), plus NetworkManager and a short verdict

## 6.0.0 — 2026-08-01

Breaking cleanup of the install pack:

- Removed legacy stub `mt7921e_simple_patch.c`; `make` / `all` defaults to `help`
- Removed `patch` / `patch-check` CLI (did not work from this repo)
- Historical PCI-ID patch moved to `archive/mt7921-pci-id/`; broken duplicate patches deleted
- Installer split: thin `mt7902.sh` + `lib/*.sh`, unified `run_install`
- Tests split into harness + sections; GitHub Actions CI (`bash -n`, shellcheck, `make test`)
- Makefile is a thin wrapper around `mt7902.sh`
- Docs synced (aliases documented; no stub/patch install path)
- Docs refactor: removed `GUIDE_EN.md` / `GUIDE_RU.md`; how-to SoT in `docs/` with Russian mirrors in `docs/ru/`
- README.md / README.ru.md slimmed to a short symptoms → fix path with links to docs

## 5.1.0 — 2026-08-01

- README.md (English) + README.ru.md with user-search keywords
- docs/: installation.md, supported-hardware.md, faq.md + SVG images
- CONTRIBUTING.md — bug reports / PRs welcome; tested on Ubuntu 24.04
- GitHub Topics/About updated for SEO (`driver`, `kernel`, `pcie`, `mtk`, …)
- First GitHub Release tag `v5.1.0`

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
- Проверено: Acer Aspire A315-59, Ubuntu 24.04, ядро 6.17

## 4.0 — 2026-02-25

- Унификация в `mt7902.sh` (Wi‑Fi + system + патчи)
- Двуязычные GUIDE_EN / GUIDE_RU
