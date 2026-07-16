# Makefile для MediaTek MT7902 WiFi + Bluetooth
# Версия: 5.0

KERNEL_VERSION := $(shell uname -r)
KERNEL_BUILD := /lib/modules/$(KERNEL_VERSION)/build
NPROC := $(shell nproc)
GEN4_DIR := gen4-mt7902
BT_DIR := btusb_mt7902
WIFI_MOD := mt7902e
BT_MOD := btusb_mt7902
PATCH_DRIVER := mt7921e_simple_patch

.PHONY: all install clean uninstall test test-hw diagnose help quick-install install-all patch patch-check \
	bluetooth install-bt gen4-driver install-gen4 check-status

obj-m += $(PATCH_DRIVER).o

all: patch-driver
	@echo "Сборка завершена. Используйте 'make install' / 'make bluetooth'"

patch-driver:
	@echo "Сборка $(PATCH_DRIVER)..."
	$(MAKE) -C $(KERNEL_BUILD) M=$(PWD) modules

gen4-driver:
	@echo "Сборка Wi‑Fi ($(GEN4_DIR) → $(WIFI_MOD))..."
	@if [ ! -d "$(GEN4_DIR)" ]; then \
		echo "Каталог $(GEN4_DIR) не найден. Клонируйте: git clone -b backport https://github.com/hmtheboy154/mt7902.git $(GEN4_DIR)"; \
		exit 1; \
	fi
	cd $(GEN4_DIR) && $(MAKE) -j$(NPROC)

install-gen4:
	@echo "Установка Wi‑Fi..."
	@if [ ! -d "$(GEN4_DIR)" ]; then exit 1; fi
	cd $(GEN4_DIR) && sudo $(MAKE) install -j$(NPROC)
	cd $(GEN4_DIR) && sudo $(MAKE) install_fw

install: gen4-driver install-gen4
	@echo "Автозагрузка $(WIFI_MOD)..."
	echo "$(WIFI_MOD)" | sudo tee /etc/modules-load.d/mt7902.conf
	sudo modprobe -r $(WIFI_MOD) 2>/dev/null || true
	sudo modprobe $(WIFI_MOD)
	@echo "Готово. Bluetooth: make bluetooth | sudo ./mt7902.sh bluetooth"

bluetooth install-bt:
	@echo "Установка Bluetooth через скрипт..."
	sudo ./mt7902.sh bluetooth

quick-install:
	sudo ./mt7902.sh install-all

install-all:
	sudo ./mt7902.sh install-all

check-status:
	@echo "Статус MediaTek MT7902:"
	@echo ""
	@echo "Wi‑Fi ($(WIFI_MOD)):"
	@lsmod | grep $(WIFI_MOD) || echo "  не загружен"
	@echo ""
	@echo "Bluetooth ($(BT_MOD)):"
	@lsmod | grep $(BT_MOD) || echo "  не загружен"
	@echo ""
	@echo "PCI:"
	@lspci -nn | grep -i "7902\|mediatek" || echo "  не найдено"
	@echo ""
	@echo "Интерфейсы:"
	@ip -br link | grep -iE 'wlan|wlp' || echo "  Wi‑Fi интерфейс не найден"
	@echo ""
	@bluetoothctl show 2>/dev/null | head -8 || echo "  Bluetooth контроллер недоступен"

# Safety / regression tests — run first when developing (must not harm users)
test:
	./tests/run-tests.sh

# Runtime check on a machine with MT7902 installed
test-hw: check-status
	@echo ""
	@echo "Тест Wi‑Fi..."
	@if lsmod | grep -q $(WIFI_MOD); then \
		IFACE=$$(ip -br link | awk '/wl/{print $$1; exit}'); \
		if [ -n "$$IFACE" ]; then \
			echo "Интерфейс: $$IFACE"; \
			nmcli device wifi list ifname $$IFACE 2>/dev/null | head -5 || true; \
		else \
			echo "Интерфейс не найден"; \
		fi; \
	else \
		echo "$(WIFI_MOD) не загружен"; \
	fi

diagnose:
	./mt7902.sh diagnose

clean:
	@echo "Очистка..."
	-$(MAKE) -C $(KERNEL_BUILD) M=$(PWD) clean
	@if [ -d "$(GEN4_DIR)" ]; then cd $(GEN4_DIR) && $(MAKE) clean; fi
	@if [ -d "$(BT_DIR)" ]; then cd $(BT_DIR) && $(MAKE) clean; fi

uninstall:
	@echo "Удаление через скрипт..."
	sudo ./mt7902.sh remove
	@if [ -d "$(GEN4_DIR)" ]; then cd $(GEN4_DIR) && sudo $(MAKE) uninstall || true; fi
	@if [ -d "$(BT_DIR)" ]; then cd $(BT_DIR) && sudo $(MAKE) uninstall || true; fi

patch:
	./mt7902.sh patch

patch-check:
	./mt7902.sh patch-check

help:
	@echo "MediaTek MT7902 WiFi + Bluetooth"
	@echo ""
	@echo "Тесты (сначала — не навредить системе):"
	@echo "  make test            # безопасность установщика/патча (без root)"
	@echo "  make test-hw         # проверка на железе после установки"
	@echo ""
	@echo "Установка:"
	@echo "  make quick-install   # Wi‑Fi + Bluetooth + system"
	@echo "  make install-all     # то же через mt7902.sh"
	@echo "  make install         # Wi‑Fi mt7902e"
	@echo "  make bluetooth       # Bluetooth btusb_mt7902"
	@echo ""
	@echo "Проверка:"
	@echo "  make check-status"
	@echo "  make diagnose"
	@echo ""
	@echo "Документация: README.md, GUIDE_RU.md, GUIDE_EN.md"
