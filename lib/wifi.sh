#!/bin/bash
# shellcheck shell=bash

stop_services() {
    print_step "Остановка конфликтующих сервисов"
    if systemctl is-active --quiet NetworkManager; then
        systemctl stop NetworkManager || true
    fi
    modprobe -r "$WIFI_MOD" 2>/dev/null || true
    modprobe -r mt7902 2>/dev/null || true
    if systemctl is-active --quiet docker; then
        systemctl stop docker || true
    fi
    print_success "Сервисы остановлены"
}

install_driver() {
    print_step "Установка Wi‑Fi драйвера ($WIFI_MOD)"
    ensure_wifi_sources
    [[ ! -d "$WIFI_DIR" ]] && { print_error "Директория $WIFI_DIR не найдена"; exit 1; }

    (
        cd "$WIFI_DIR"
        print_info "Сборка..."
        make -j"$(nproc)"
        print_info "Установка модуля..."
        make install -j"$(nproc)"
        print_info "Установка прошивки..."
        make install_fw
    )
    print_success "Wi‑Fi драйвер установлен"
}

setup_autoload() {
    print_step "Настройка автозагрузки Wi‑Fi"
    echo "$WIFI_MOD" > /etc/modules-load.d/mt7902.conf
    cat > /etc/modprobe.d/mt7902.conf << EOF
# MediaTek MT7902 WiFi — модуль $WIFI_MOD
EOF
    print_success "Автозагрузка Wi‑Fi настроена"
}

load_driver() {
    print_step "Загрузка Wi‑Fi драйвера"
    depmod -a
    modprobe "$WIFI_MOD" || { print_error "Драйвер $WIFI_MOD не загружен"; return 1; }
    lsmod | grep -q "$WIFI_MOD" && print_success "Драйвер $WIFI_MOD загружен"

    systemctl start NetworkManager 2>/dev/null || true
    if systemctl is-active --quiet NetworkManager; then
        print_success "NetworkManager запущен"
    fi

    if command -v docker &>/dev/null; then
        systemctl start docker 2>/dev/null || true
    fi
}

wifi_seems_up() {
    # Success = module loaded (iface may appear only after reboot / NM settle)
    lsmod | grep -q "$WIFI_MOD" || return 1
    if ip -br link 2>/dev/null | grep -qiE 'wlan|wlp'; then
        return 0
    fi
    return 0
}
