# Makefile for MediaTek MT7902 WiFi + Bluetooth
# Version: 6.0.0

KERNEL_VERSION := $(shell uname -r)
KERNEL_BUILD := /lib/modules/$(KERNEL_VERSION)/build
NPROC := $(shell nproc)
GEN4_DIR := gen4-mt7902
BT_DIR := btusb_mt7902
WIFI_MOD := mt7902e
BT_MOD := btusb_mt7902

.PHONY: all help test test-hw diagnose check-status \
	install install-all quick-install bluetooth install-bt \
	gen4-driver install-gen4 clean uninstall

# Default: show help (never build a stub driver)
all: help

help:
	@echo "MediaTek MT7902 WiFi + Bluetooth"
	@echo ""
	@echo "Tests (run first — must not harm user systems):"
	@echo "  make test            # safety tests (no root)"
	@echo "  make test-hw         # check on hardware after install"
	@echo ""
	@echo "Install:"
	@echo "  make quick-install   # Wi‑Fi + Bluetooth + system"
	@echo "  make install-all     # same via mt7902.sh"
	@echo "  make install         # Wi‑Fi mt7902e"
	@echo "  make bluetooth       # Bluetooth btusb_mt7902"
	@echo ""
	@echo "Check:"
	@echo "  make check-status"
	@echo "  make diagnose"
	@echo ""
	@echo "Docs: README.md, docs/installation.md, docs/ru/installation.md"

gen4-driver:
	@echo "Building Wi‑Fi ($(GEN4_DIR) → $(WIFI_MOD))..."
	@if [ ! -d "$(GEN4_DIR)" ]; then \
		echo "Missing $(GEN4_DIR). Clone: git clone -b backport https://github.com/hmtheboy154/mt7902.git $(GEN4_DIR)"; \
		exit 1; \
	fi
	cd $(GEN4_DIR) && $(MAKE) -j$(NPROC)

install-gen4:
	@echo "Installing Wi‑Fi..."
	@if [ ! -d "$(GEN4_DIR)" ]; then exit 1; fi
	cd $(GEN4_DIR) && sudo $(MAKE) install -j$(NPROC)
	cd $(GEN4_DIR) && sudo $(MAKE) install_fw

install: gen4-driver install-gen4
	@echo "Autoload $(WIFI_MOD)..."
	echo "$(WIFI_MOD)" | sudo tee /etc/modules-load.d/mt7902.conf
	sudo modprobe -r $(WIFI_MOD) 2>/dev/null || true
	sudo modprobe $(WIFI_MOD)
	@echo "Done. Bluetooth: make bluetooth | sudo ./mt7902.sh bluetooth"

bluetooth install-bt:
	@echo "Installing Bluetooth via script..."
	sudo ./mt7902.sh bluetooth

quick-install:
	sudo ./mt7902.sh install-all

install-all:
	sudo ./mt7902.sh install-all

check-status:
	@echo "MediaTek MT7902 status:"
	@echo ""
	@echo "Wi‑Fi ($(WIFI_MOD)):"
	@lsmod | grep $(WIFI_MOD) || echo "  not loaded"
	@echo ""
	@echo "Bluetooth ($(BT_MOD)):"
	@lsmod | grep $(BT_MOD) || echo "  not loaded"
	@echo ""
	@echo "PCI:"
	@lspci -nn | grep -i "7902\|mediatek" || echo "  not found"
	@echo ""
	@echo "Interfaces:"
	@ip -br link | grep -iE 'wlan|wlp' || echo "  Wi‑Fi interface not found"
	@echo ""
	@bluetoothctl show 2>/dev/null | head -8 || echo "  Bluetooth controller unavailable"

test:
	./tests/run-tests.sh

test-hw: check-status
	@echo ""
	@echo "Wi‑Fi probe..."
	@if lsmod | grep -q $(WIFI_MOD); then \
		IFACE=$$(ip -br link | awk '/wl/{print $$1; exit}'); \
		if [ -n "$$IFACE" ]; then \
			echo "Interface: $$IFACE"; \
			nmcli device wifi list ifname $$IFACE 2>/dev/null | head -5 || true; \
		else \
			echo "Interface not found"; \
		fi; \
	else \
		echo "$(WIFI_MOD) not loaded"; \
	fi

diagnose:
	./mt7902.sh diagnose

clean:
	@echo "Cleaning..."
	@if [ -d "$(GEN4_DIR)" ]; then cd $(GEN4_DIR) && $(MAKE) clean; fi
	@if [ -d "$(BT_DIR)" ]; then cd $(BT_DIR) && $(MAKE) clean; fi

uninstall:
	@echo "Removing via script..."
	sudo ./mt7902.sh remove
	@if [ -d "$(GEN4_DIR)" ]; then cd $(GEN4_DIR) && sudo $(MAKE) uninstall || true; fi
	@if [ -d "$(BT_DIR)" ]; then cd $(BT_DIR) && sudo $(MAKE) uninstall || true; fi
