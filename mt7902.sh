#!/bin/bash

# MediaTek MT7902 WiFi + Bluetooth — универсальный скрипт
# Версия: 6.1.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
SCRIPT_ARGS=("$@")

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/deps.sh
source "$SCRIPT_DIR/lib/deps.sh"
# shellcheck source=lib/sources.sh
source "$SCRIPT_DIR/lib/sources.sh"
# shellcheck source=lib/wifi.sh
source "$SCRIPT_DIR/lib/wifi.sh"
# shellcheck source=lib/bluetooth.sh
source "$SCRIPT_DIR/lib/bluetooth.sh"
# shellcheck source=lib/systemd.sh
source "$SCRIPT_DIR/lib/systemd.sh"
# shellcheck source=lib/backup.sh
source "$SCRIPT_DIR/lib/backup.sh"
# shellcheck source=lib/verify.sh
source "$SCRIPT_DIR/lib/verify.sh"
# shellcheck source=lib/install.sh
source "$SCRIPT_DIR/lib/install.sh"

case "${1:-help}" in
    install-all|all) install_all ;;
    install) full_install ;;
    driver) install_only_driver ;;
    bluetooth|bt) install_only_bluetooth ;;
    system) install_only_system ;;
    verify|status) check_status ;;
    rollback|restore)
        print_header
        check_root
        rollback_installation
        ;;
    remove)
        print_header
        check_root
        remove_installation
        ;;
    diagnose) run_diagnose ;;
    watchdog)
        print_header
        check_root
        enable_watchdog
        ;;
    watchdog-stop|watchdog-off)
        print_header
        check_root
        disable_watchdog
        systemctl daemon-reload 2>/dev/null || true
        print_success "mt7902-watchdog остановлен"
        ;;
    help|--help|-h) show_help ;;
    *)
        print_error "Неизвестная команда: $1"
        show_help
        exit 1
        ;;
esac
