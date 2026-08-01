#!/bin/bash
# shellcheck shell=bash
# Unified install orchestration for MT7902.

show_instructions() {
    echo ""
    print_success "Установка Wi‑Fi завершена!"
    echo ""
    print_info "🔄 Перезагрузка:"
    echo "  sudo reboot"
    echo ""
    print_info "📶 Bluetooth (отдельно):"
    echo "  sudo $0 bluetooth"
    echo ""
    print_info "📡 Проверка:"
    echo "  lsmod | grep -E 'mt7902e|btusb_mt7902'"
    echo "  nmcli device status"
    echo "  bluetoothctl show"
    echo ""
    print_info "↩️  Откат (вернуть исходные настройки):"
    echo "  sudo $0 rollback"
    echo ""
    print_info "📚 docs/installation.md · docs/ru/installation.md · README.md"
}

# run_install --wifi --bt --system
run_install() {
    local want_wifi=0 want_bt=0 want_system=0
    local arg

    for arg in "$@"; do
        case "$arg" in
            --wifi) want_wifi=1 ;;
            --bt) want_bt=1 ;;
            --system) want_system=1 ;;
            *)
                print_error "run_install: неизвестный флаг $arg"
                exit 1
                ;;
        esac
    done

    if [[ "$want_wifi$want_bt$want_system" == "000" ]]; then
        print_error "run_install: укажите --wifi и/или --bt и/или --system"
        exit 1
    fi

    print_header
    check_root
    check_system
    create_pre_install_backup "$want_wifi" "$want_bt" "$want_system"

    if [[ "$want_wifi" == "1" || "$want_bt" == "1" ]]; then
        install_deps
    fi

    if [[ "$want_wifi" == "1" ]]; then
        stop_services
        install_driver
        setup_autoload
    fi

    if [[ "$want_system" == "1" ]]; then
        apply_system_settings
        create_services
        enable_services
    fi

    if [[ "$want_wifi" == "1" ]]; then
        # Failures are reported by prompt_rollback_if_failed (do not abort early)
        load_driver || true
    fi

    if [[ "$want_bt" == "1" ]]; then
        install_bluetooth
    fi

    verify_installation

    if [[ "$want_wifi" == "1" || "$want_bt" == "1" ]]; then
        prompt_rollback_if_failed "$want_wifi" "$want_bt" || true
    fi

    if [[ "$want_wifi" == "1" && "$want_bt" == "1" && "$want_system" == "1" ]]; then
        echo ""
        print_success "Полная установка Wi‑Fi + Bluetooth завершена!"
        print_info "🔄 Обязательно: sudo reboot"
        print_info "📡 nmcli device status && bluetoothctl show"
        print_info "↩️  Если после reboot нет Wi‑Fi/BT: sudo $0 rollback"
    elif [[ "$want_bt" == "1" && "$want_wifi" == "0" ]]; then
        echo ""
        print_success "Bluetooth установлен!"
        print_info "🔄 Рекомендуется: sudo reboot"
        print_info "📡 Проверка: bluetoothctl show"
        print_info "↩️  Откат при проблемах: sudo $0 rollback"
    elif [[ "$want_system" == "1" && "$want_wifi" == "0" && "$want_bt" == "0" ]]; then
        print_success "Системные настройки применены!"
        print_info "🔄 Перезагрузите систему: sudo reboot"
        print_info "↩️  Откат: sudo $0 rollback"
    elif [[ "$want_wifi" == "1" ]]; then
        show_instructions
    fi
}

install_all() { run_install --wifi --bt --system; }
full_install() { run_install --wifi --system; }
install_only_driver() { run_install --wifi; }
install_only_bluetooth() { run_install --bt; }
install_only_system() { run_install --system; }
