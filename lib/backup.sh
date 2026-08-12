#!/bin/bash
# shellcheck shell=bash
# Backup / rollback / remove for MT7902 installer.

backup_one_file() {
    local src="$1"
    local rel="${src#/}"
    local dest="$BACKUP_DIR/files/$rel"
    mkdir -p "$(dirname "$dest")"
    if [[ -e "$src" ]]; then
        cp -a "$src" "$dest"
        echo "present|$src" >> "$BACKUP_DIR/manifest"
    else
        : > "${dest}.absent"
        echo "absent|$src" >> "$BACKUP_DIR/manifest"
    fi
}

create_pre_install_backup() {
    print_step "Сохранение исходных настроек (для отката)"
    mkdir -p "$BACKUP_ROOT"
    rm -rf "$BACKUP_DIR"
    mkdir -p "$BACKUP_DIR/files"
    : > "$BACKUP_DIR/manifest"

    date -Is > "$BACKUP_DIR/created_at"
    uname -r > "$BACKUP_DIR/kernel"
    {
        echo "want_wifi=${1:-0}"
        echo "want_bt=${2:-0}"
        echo "want_system=${3:-0}"
    } > "$BACKUP_DIR/intent"

    local f
    for f in "${MANAGED_FILES[@]}"; do
        backup_one_file "$f"
    done

    {
        systemctl is-enabled mt7902-driver-shutdown.service 2>/dev/null || echo "absent"
        systemctl is-enabled docker-shutdown.service 2>/dev/null || echo "absent"
    } > "$BACKUP_DIR/services_enabled.txt" || true

    lsmod > "$BACKUP_DIR/lsmod_before.txt" 2>/dev/null || true
    print_success "Бэкап сохранён: $BACKUP_DIR"
}

restore_one_file() {
    local src="$1"
    local rel="${src#/}"
    local dest="$BACKUP_DIR/files/$rel"
    if [[ -f "${dest}.absent" ]]; then
        rm -f "$src"
    elif [[ -e "$dest" ]]; then
        mkdir -p "$(dirname "$src")"
        cp -a "$dest" "$src"
    else
        rm -f "$src"
    fi
}

unload_our_modules() {
    modprobe -r "$WIFI_MOD" 2>/dev/null || true
    modprobe -r "$BT_MOD" 2>/dev/null || true
}

try_uninstall_driver_packages() {
    if [[ -d "$WIFI_DIR" ]] && [[ -f "$WIFI_DIR/Makefile" ]]; then
        print_info "Попытка make uninstall (Wi‑Fi)..."
        (cd "$WIFI_DIR" && make uninstall) 2>/dev/null || true
    fi
    if [[ -d "$BT_DIR" ]] && [[ -f "$BT_DIR/Makefile" ]]; then
        print_info "Попытка make uninstall (Bluetooth)..."
        (cd "$BT_DIR" && make uninstall) 2>/dev/null || true
    fi
}

rollback_installation() {
    print_step "Откат к исходным настройкам пользователя"

    if [[ ! -d "$BACKUP_DIR" ]] || [[ ! -f "$BACKUP_DIR/manifest" ]]; then
        print_warning "Бэкап не найден ($BACKUP_DIR) — удаляю только файлы этого пакета"
    fi

    disable_watchdog
    unload_our_modules

    local f
    if [[ -f "$BACKUP_DIR/manifest" ]]; then
        while IFS='|' read -r state path; do
            [[ -n "$path" ]] || continue
            if [[ "$state" == "absent" ]]; then
                rm -f "$path"
            elif [[ "$state" == "present" ]]; then
                restore_one_file "$path"
            fi
        done < "$BACKUP_DIR/manifest"
    else
        for f in "${MANAGED_FILES[@]}"; do
            rm -f "$f"
        done
    fi

    disable_watchdog
    systemctl disable docker-shutdown.service 2>/dev/null || true
    systemctl disable mt7902-driver-shutdown.service 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true

    if [[ ! -f /etc/modprobe.d/blacklist_btusb.conf ]]; then
        modprobe btmtk 2>/dev/null || true
        modprobe btusb 2>/dev/null || true
        systemctl restart bluetooth 2>/dev/null || true
    fi

    try_uninstall_driver_packages
    depmod -a 2>/dev/null || true

    print_success "Исходные настройки восстановлены"
    print_info "При необходимости: sudo reboot"
    print_info "Бэкап оставлен в $BACKUP_DIR (можно удалить вручную)"
}

prompt_rollback_if_failed() {
    local want_wifi="${1:-0}"
    local want_bt="${2:-0}"
    local failed=0

    if [[ "$want_wifi" == "1" ]]; then
        if wifi_seems_up; then
            print_success "Wi‑Fi: модуль $WIFI_MOD загружен"
        else
            print_error "Wi‑Fi: модуль $WIFI_MOD не загрузился"
            failed=1
        fi
    fi

    if [[ "$want_bt" == "1" ]]; then
        if bt_seems_up; then
            print_success "Bluetooth: модуль $BT_MOD загружен"
        else
            print_error "Bluetooth: модуль $BT_MOD не загрузился"
            failed=1
        fi
    fi

    echo ""
    if [[ "$failed" -eq 0 ]]; then
        print_info "Если после reboot Wi‑Fi/BT всё ещё нет — откат:"
        echo "  sudo $0 rollback"
        return 0
    fi

    print_warning "Установка не дала рабочий интерфейс прямо сейчас."
    print_info "Бэкап исходных настроек: $BACKUP_DIR"

    local do_rb=""
    if [[ "${MT7902_AUTO_ROLLBACK:-}" == "1" ]]; then
        do_rb="y"
        print_warning "MT7902_AUTO_ROLLBACK=1 — выполняю откат автоматически"
    elif [[ -t 0 ]]; then
        read -r -p "Откатить настройки к состоянию до установки? [Y/n]: " do_rb
        do_rb="${do_rb:-Y}"
    else
        print_warning "Нет TTY — откат не запрошен. Выполните: sudo $0 rollback"
        return 1
    fi

    if [[ "$do_rb" =~ ^[Yy]$ ]]; then
        rollback_installation
        return 2
    fi

    print_info "Откат отложен. Позже: sudo $0 rollback"
    return 1
}

remove_installation() {
    print_step "Удаление установки"
    print_warning "Будут удалены настройки пакета; при наличии бэкапа предпочтите: sudo $0 rollback"

    read -r -p "Вы уверены? (y/N): " -n 1 REPLY
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || { print_info "Отмена"; exit 0; }

    if [[ -d "$BACKUP_DIR" ]] && [[ -f "$BACKUP_DIR/manifest" ]]; then
        print_info "Найден бэкап — восстанавливаю исходные настройки"
        rollback_installation
        return
    fi

    disable_watchdog
    unload_our_modules

    local f
    for f in "${MANAGED_FILES[@]}"; do
        rm -f "$f"
    done

    systemctl disable docker-shutdown.service 2>/dev/null || true
    systemctl disable mt7902-driver-shutdown.service 2>/dev/null || true
    systemctl daemon-reload

    modprobe btmtk 2>/dev/null || true
    modprobe btusb 2>/dev/null || true

    print_success "Конфигурация удалена (модули .ko в /lib/modules можно убрать через make uninstall в gen4-mt7902 / btusb_mt7902)"
}
