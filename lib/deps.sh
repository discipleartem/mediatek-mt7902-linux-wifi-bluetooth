#!/bin/bash
# shellcheck shell=bash

check_system() {
    print_info "Проверка системы..."
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        print_info "Дистрибутив: $PRETTY_NAME"
    fi
    print_info "Ядро: $(uname -r)"

    if lspci -nn 2>/dev/null | grep -qi "14c3:7902\|mediatek.*7902"; then
        print_success "MediaTek MT7902 (PCIe) обнаружен"
    else
        print_warning "MediaTek MT7902 (14c3:7902) не обнаружен в lspci"
    fi

    if lsusb 2>/dev/null | grep -qi "13d3:3594\|MediaTek"; then
        print_info "Возможный USB Bluetooth MediaTek/IMC найден"
    fi

    command -v systemctl &>/dev/null || { print_error "systemd не найден"; exit 1; }
    print_success "Система проверена"
}

install_deps() {
    print_step "Установка зависимостей"
    if command -v apt-get &>/dev/null; then
        apt-get update && apt-get install -y build-essential "linux-headers-$(uname -r)" git dkms
    elif command -v yum &>/dev/null; then
        yum groupinstall -y "Development Tools" && yum install -y "kernel-devel-$(uname -r)" git dkms
    elif command -v dnf &>/dev/null; then
        dnf groupinstall -y "Development Tools" && dnf install -y "kernel-devel-$(uname -r)" git dkms
    else
        print_error "Не поддерживаемый пакетный менеджер"; exit 1
    fi
    print_success "Зависимости установлены"
}
