#!/bin/bash
# shellcheck shell=bash

verify_installation() {
    print_step "Проверка установки"

    echo -e "\n📊 Wi‑Fi:"
    lsmod | grep -q "$WIFI_MOD" && echo "  ✅ Модуль $WIFI_MOD загружен" || echo "  ❌ Модуль $WIFI_MOD не загружен"
    lspci -nn 2>/dev/null | grep -qi "14c3:7902" && echo "  ✅ PCI 14c3:7902 обнаружен" || echo "  ❌ PCI 14c3:7902 не найден"
    ip -br link 2>/dev/null | grep -qiE 'wlan|wlp' && echo "  ✅ Беспроводной интерфейс есть" || echo "  ❌ Wi‑Fi интерфейс не найден"

    echo -e "\n📶 Bluetooth:"
    lsmod | grep -q "$BT_MOD" && echo "  ✅ Модуль $BT_MOD загружен" || echo "  ❌ Модуль $BT_MOD не загружен"
    [[ -f /etc/modprobe.d/blacklist_btusb.conf ]] && echo "  ✅ blacklist btusb/btmtk" || echo "  ❌ blacklist btusb не настроен"
    if command -v bluetoothctl &>/dev/null; then
        bluetoothctl show 2>/dev/null | grep -qi "Powered: yes" && echo "  ✅ Контроллер Powered" || echo "  ⚠️  Контроллер не Powered / недоступен"
    fi

    echo -e "\n⚙️ Сервисы:"
    systemctl is-enabled mt7902-driver-shutdown.service &>/dev/null && echo "  ✅ mt7902-driver-shutdown.service" || echo "  ❌ mt7902-driver-shutdown.service"
    systemctl is-enabled docker-shutdown.service &>/dev/null && echo "  ✅ docker-shutdown.service" || echo "  ⚠️  docker-shutdown.service"

    echo -e "\n📁 Конфигурации:"
    [[ -f /etc/systemd/system.conf.d/99-timeouts.conf ]] && echo "  ✅ Системные таймауты" || echo "  ❌ Системные таймауты"
    [[ -f /etc/modules-load.d/mt7902.conf ]] && echo "  ✅ Автозагрузка Wi‑Fi" || echo "  ❌ Автозагрузка Wi‑Fi"
    [[ -f /etc/modules-load.d/btusb_mt7902.conf ]] && echo "  ✅ Автозагрузка Bluetooth" || echo "  ⚠️  Автозагрузка Bluetooth"

    if [[ -d "$BACKUP_DIR" ]]; then
        echo -e "\n💾 Откат:"
        echo "  ✅ Бэкап настроек: $BACKUP_DIR"
        echo "  → если после reboot нет Wi‑Fi/BT: sudo $0 rollback"
    fi
}

check_status() {
    print_header
    verify_installation
}

run_diagnose() {
    print_header
    echo "🔍 Полная диагностика:"
    echo "======================"
    echo ""
    echo "📋 Система:"
    uname -a
    echo ""
    echo "💻 DMI:"
    cat /sys/class/dmi/id/sys_vendor 2>/dev/null; cat /sys/class/dmi/id/product_name 2>/dev/null
    echo ""
    echo "🔧 Модули:"
    lsmod | grep -E 'mt7902|btusb|btmtk|cfg80211|mac80211' || true
    echo ""
    echo "📡 PCI:"
    lspci -nnk | grep -A3 -i 'network\|mediatek\|7902' || true
    echo ""
    echo "🔌 USB:"
    lsusb | grep -iE '13d3|0e8d|Wireless|Bluetooth|MediaTek|Realtek' || true
    echo ""
    echo "🌐 Интерфейсы:"
    ip -br link || true
    echo ""
    echo "📶 Bluetooth:"
    bluetoothctl show 2>/dev/null | head -20 || echo "  bluetoothctl недоступен"
    echo ""
    echo "📝 Логи:"
    journalctl -b -p err 2>/dev/null | tail -5 || true
}

show_help() {
    echo -e "${BLUE}MediaTek MT7902 WiFi + Bluetooth${NC}"
    echo ""
    echo "Использование: $0 [команда]"
    echo ""
    echo "🚀 Установка:"
    echo "  install-all  Wi‑Fi + Bluetooth + systemd (рекомендуется)"
    echo "  install      Wi‑Fi + системные настройки"
    echo "  driver       Только Wi‑Fi (mt7902e)"
    echo "  bluetooth    Только Bluetooth (btusb_mt7902)"
    echo "  system       Только systemd-оптимизации"
    echo "  verify       Проверка установки"
    echo "  rollback     Откат к настройкам до установки (если нет Wi‑Fi/BT)"
    echo "  remove       Удаление конфигурации (через бэкап, если есть)"
    echo ""
    echo "🔍 Диагностика:"
    echo "  status       Статус (alias: verify)"
    echo "  diagnose     Полная диагностика"
    echo ""
    echo "Алиасы: all→install-all, bt→bluetooth, restore→rollback"
    echo ""
    echo "Примеры:"
    echo "  sudo $0 install-all"
    echo "  sudo $0 rollback"
    echo "  MT7902_AUTO_ROLLBACK=1 sudo $0 install-all   # откат без вопроса при сбое"
    echo ""
    echo "📚 docs/installation.md · docs/ru/installation.md · README.md"
}
