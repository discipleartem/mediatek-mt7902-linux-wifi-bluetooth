# Makefile for MediaTek MT7902 WiFi + Bluetooth
# Version: 6.0.0
#
# Thin wrapper around ./mt7902.sh — prefer the script for installs.

GEN4_DIR := gen4-mt7902
BT_DIR := btusb_mt7902

.PHONY: all help test test-hw diagnose check-status \
	install install-all quick-install bluetooth install-bt \
	clean uninstall

# Default: show help (never build a stub driver)
all: help

help:
	@echo "MediaTek MT7902 WiFi + Bluetooth"
	@echo ""
	@echo "Tests (run first — must not harm user systems):"
	@echo "  make test            # safety tests (no root)"
	@echo "  make test-hw         # check on hardware after install"
	@echo ""
	@echo "Install (via mt7902.sh):"
	@echo "  make quick-install / install-all   # Wi‑Fi + Bluetooth + system"
	@echo "  make install                       # Wi‑Fi + system"
	@echo "  make bluetooth                     # Bluetooth only"
	@echo ""
	@echo "Check:"
	@echo "  make check-status / diagnose"
	@echo ""
	@echo "Docs: README.md, docs/installation.md, docs/ru/installation.md"

test:
	./tests/run-tests.sh

test-hw: check-status
	@echo ""
	@./mt7902.sh diagnose | head -40 || true

check-status:
	./mt7902.sh status

diagnose:
	./mt7902.sh diagnose

install:
	sudo ./mt7902.sh install

bluetooth install-bt:
	sudo ./mt7902.sh bluetooth

quick-install install-all:
	sudo ./mt7902.sh install-all

clean:
	@echo "Cleaning driver trees (if cloned)..."
	@if [ -d "$(GEN4_DIR)" ]; then $(MAKE) -C $(GEN4_DIR) clean; fi
	@if [ -d "$(BT_DIR)" ]; then $(MAKE) -C $(BT_DIR) clean; fi

uninstall:
	sudo ./mt7902.sh remove
	@if [ -d "$(GEN4_DIR)" ]; then cd $(GEN4_DIR) && sudo $(MAKE) uninstall || true; fi
	@if [ -d "$(BT_DIR)" ]; then cd $(BT_DIR) && sudo $(MAKE) uninstall || true; fi
