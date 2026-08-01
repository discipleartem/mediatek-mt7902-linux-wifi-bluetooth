# Contributing

Bug reports welcome.  
Pull requests welcome.

## Tested on

Primary reference: **Ubuntu 24.04** (Acer Aspire A315-59, MediaTek MT7902 PCI `14c3:7902`).

## Before opening a PR

1. Run safety tests (must stay green — the pack must not harm user systems):

   ```bash
   ./tests/run-tests.sh
   # or: make test
   ```

   CI (`.github/workflows/ci.yml`) runs the same plus `bash -n` and shellcheck on every PR.

2. Keep symptom keywords and PCI/USB IDs in sync across `README.md`, `README.ru.md`, `llms.txt`, `llms-full.txt`, and `AGENTS.md`. Hardware / install / FAQ details belong in `docs/` and must stay mirrored in `docs/ru/`.

3. Prefer updating `mt7902.sh` / `lib/*.sh` over duplicating install logic in docs. README stays a short fix path; details live in `docs/installation.md` / `docs/faq.md` / `docs/supported-hardware.md`.

4. Do **not** vendor `gen4-mt7902/` or `btusb_mt7902/` unless intentional (they are gitignored clones from [hmtheboy154/mt7902](https://github.com/hmtheboy154/mt7902)).

## Bug reports

Please include when possible:

- Distro + kernel (`uname -r`)
- `lspci -nnk` snippet for `7902`
- `lsusb` for Bluetooth combo
- Relevant `dmesg` / journal lines (`Opcode 0x0c03`, firmware errors)
- Whether Secure Boot is enabled

Open an issue: https://github.com/discipleartem/mediatek-mt7902-linux-wifi-bluetooth/issues

Common questions: [docs/faq.md](docs/faq.md) · [docs/ru/faq.md](docs/ru/faq.md).

## Docs

How-to SoT: [`docs/installation.md`](docs/installation.md), [`docs/supported-hardware.md`](docs/supported-hardware.md), [`docs/faq.md`](docs/faq.md). Russian mirrors: [`docs/ru/`](docs/ru/). Landings: [`README.md`](README.md) / [`README.ru.md`](README.ru.md).

## License

By contributing, you agree your changes are licensed under the MIT License ([LICENSE](LICENSE)).
