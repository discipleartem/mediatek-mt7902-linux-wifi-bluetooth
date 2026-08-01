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

2. Keep symptom keywords and PCI/USB IDs in sync across `README.md`, `README.ru.md`, `llms.txt`, `llms-full.txt`, and `AGENTS.md`.

3. Prefer updating `mt7902.sh` over duplicating install logic in docs.

4. Do **not** vendor `gen4-mt7902/` or `btusb_mt7902/` unless intentional (they are gitignored clones from [hmtheboy154/mt7902](https://github.com/hmtheboy154/mt7902)).

## Bug reports

Please include when possible:

- Distro + kernel (`uname -r`)
- `lspci -nnk` snippet for `7902`
- `lsusb` for Bluetooth combo
- Relevant `dmesg` / journal lines (`Opcode 0x0c03`, firmware errors)
- Whether Secure Boot is enabled

Open an issue: https://github.com/discipleartem/mediatek-mt7902-linux-wifi-bluetooth/issues

Common questions: [docs/faq.md](docs/faq.md).

## Docs

User-facing docs live under [`docs/`](docs/) and the full guides [`GUIDE_EN.md`](GUIDE_EN.md) / [`GUIDE_RU.md`](GUIDE_RU.md). English landing page is [`README.md`](README.md); Russian: [`README.ru.md`](README.ru.md).

## License

By contributing, you agree your changes are licensed under the MIT License ([LICENSE](LICENSE)).
