#!/bin/bash
# shellcheck shell=bash

install_bluetooth() {
    print_step "Установка Bluetooth драйвера ($BT_MOD)"
    ensure_bt_sources
    [[ ! -d "$BT_DIR" ]] && { print_error "Директория $BT_DIR не найдена"; exit 1; }

    systemctl stop bluetooth 2>/dev/null || true
    modprobe -r btusb 2>/dev/null || true
    modprobe -r btmtk 2>/dev/null || true

    (
        cd "$BT_DIR"
        print_info "Сборка..."
        make -j"$(nproc)"
        print_info "Установка модуля..."
        make install -j"$(nproc)"
        print_info "Установка прошивки BT..."
        make install_fw
    )

    print_step "Blacklist штатных btusb/btmtk"
    cat > /etc/modprobe.d/blacklist_btusb.conf << 'EOF'
# Stock modules conflict with btusb_mt7902 (MediaTek MT7902 Bluetooth)
blacklist btusb
blacklist btmtk
EOF

    echo "$BT_MOD" > /etc/modules-load.d/btusb_mt7902.conf

    depmod -a
    modprobe "$BT_MOD" || print_warning "modprobe $BT_MOD не удался — перезагрузите систему"
    systemctl start bluetooth 2>/dev/null || true

    print_success "Bluetooth драйвер установлен"
    print_warning "Bluetooth на USB‑адаптерах через штатный btusb больше не будет работать"
}

bt_seems_up() {
    lsmod | grep -q "$BT_MOD" || return 1
    return 0
}
