#!/bin/bash

# MediaTek MT7902 WiFi + Bluetooth — универсальный скрипт
# Версия: 5.0
# Дата: 16 июля 2026

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

WIFI_DIR="gen4-mt7902"
BT_DIR="btusb_mt7902"
WIFI_MOD="mt7902e"
BT_MOD="btusb_mt7902"
WIFI_REPO="https://github.com/hmtheboy154/mt7902.git"
WIFI_BRANCH="backport"
BT_BRANCH="bluetooth_backport"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_step() { echo -e "${CYAN}🔄 $1${NC}"; }

print_header() {
    echo -e "${BLUE}"
    echo "🚀 MediaTek MT7902 WiFi + Bluetooth"
    echo "===================================="
    echo -e "${NC}"
}

check_root() {
    [[ $EUID -ne 0 ]] && { print_error "Требуются права суперпользователя: sudo $0 $*"; exit 1; }
}

check_system() {
    print_info "Проверка системы..."
    [[ -f /etc/os-release ]] && source /etc/os-release && print_info "Дистрибутив: $PRETTY_NAME"
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

ensure_wifi_sources() {
    if [[ ! -d "$WIFI_DIR/.git" && ! -f "$WIFI_DIR/Makefile" ]]; then
        print_step "Клонирование Wi‑Fi драйвера ($WIFI_BRANCH)"
        git clone --depth 1 -b "$WIFI_BRANCH" "$WIFI_REPO" "$WIFI_DIR"
    fi
}

ensure_bt_sources() {
    if [[ ! -d "$BT_DIR/.git" && ! -f "$BT_DIR/Makefile" ]]; then
        print_step "Клонирование Bluetooth драйвера ($BT_BRANCH)"
        git clone --depth 1 -b "$BT_BRANCH" "$WIFI_REPO" "$BT_DIR"
    fi
}

stop_services() {
    print_step "Остановка конфликтующих сервисов"
    systemctl is-active --quiet NetworkManager && systemctl stop NetworkManager || true
    modprobe -r "$WIFI_MOD" 2>/dev/null || true
    modprobe -r mt7902 2>/dev/null || true
    systemctl is-active --quiet docker && systemctl stop docker || true
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

setup_autoload() {
    print_step "Настройка автозагрузки Wi‑Fi"
    echo "$WIFI_MOD" > /etc/modules-load.d/mt7902.conf
    cat > /etc/modprobe.d/mt7902.conf << EOF
# MediaTek MT7902 WiFi — модуль $WIFI_MOD
EOF
    print_success "Автозагрузка Wi‑Fi настроена"
}

apply_system_settings() {
    print_step "Применение системных настроек"

    mkdir -p /etc/systemd/system.conf.d
    cat > /etc/systemd/system.conf.d/99-timeouts.conf << 'EOF'
# MediaTek MT7902 — оптимизация таймаутов
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=30s
DefaultTimeoutAbortSec=10s
ShutdownWatchdogSec=1min
EOF

    mkdir -p /etc/systemd/system/docker.service.d
    cat > /etc/systemd/system/docker.service.d/override.conf << 'EOF'
[Service]
TimeoutStartSec=60s
TimeoutStopSec=30s
KillMode=mixed
KillSignal=SIGINT
SendSIGKILL=yes
EOF

    mkdir -p /etc/systemd/system/NetworkManager.service.d
    cat > /etc/systemd/system/NetworkManager.service.d/override.conf << 'EOF'
[Service]
TimeoutStartSec=30s
TimeoutStopSec=15s
KillMode=mixed
SendSIGKILL=yes
EOF

    print_success "Системные настройки применены"
}

create_services() {
    print_step "Создание сервисов"

    cat > /etc/systemd/system/docker-shutdown.service << 'EOF'
[Unit]
Description=Stop Docker containers before shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/bin/docker stop $(/usr/bin/docker ps -q) 2>/dev/null || true'
ExecStart=/bin/bash -c '/usr/bin/docker kill $(/usr/bin/docker ps -q) 2>/dev/null || true'
TimeoutStartSec=30s
RemainAfterExit=yes

[Install]
WantedBy=halt.target reboot.target shutdown.target
EOF

    cat > /etc/systemd/system/mt7902-driver-shutdown.service << EOF
[Unit]
Description=Unload ${WIFI_MOD} driver before shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target
After=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/sbin/modprobe -r ${WIFI_MOD}
TimeoutStartSec=10s
RemainAfterExit=yes

[Install]
WantedBy=halt.target reboot.target shutdown.target
EOF

    print_success "Сервисы созданы"
}

enable_services() {
    print_step "Активация сервисов"
    systemctl daemon-reload
    command -v docker &>/dev/null && systemctl enable docker-shutdown.service || true
    systemctl enable mt7902-driver-shutdown.service
    print_success "Сервисы активированы"
}

load_driver() {
    print_step "Загрузка Wi‑Fi драйвера"
    depmod -a
    modprobe "$WIFI_MOD" || { print_error "Драйвер $WIFI_MOD не загружен"; return 1; }
    lsmod | grep -q "$WIFI_MOD" && print_success "Драйвер $WIFI_MOD загружен"

    systemctl start NetworkManager 2>/dev/null || true
    systemctl is-active --quiet NetworkManager && print_success "NetworkManager запущен" || true

    command -v docker &>/dev/null && systemctl start docker 2>/dev/null || true
}

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
}

remove_installation() {
    print_step "Удаление установки"
    print_warning "Удаление драйверных настроек и системных файлов..."

    read -r -p "Вы уверены? (y/N): " -n 1 REPLY
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || { print_info "Отмена"; exit 0; }

    modprobe -r "$WIFI_MOD" 2>/dev/null || true
    modprobe -r "$BT_MOD" 2>/dev/null || true

    rm -f /etc/modules-load.d/mt7902.conf
    rm -f /etc/modules-load.d/btusb_mt7902.conf
    rm -f /etc/modprobe.d/mt7902.conf
    rm -f /etc/modprobe.d/blacklist_btusb.conf
    rm -f /etc/systemd/system.conf.d/99-timeouts.conf
    rm -f /etc/systemd/system/docker.service.d/override.conf
    rm -f /etc/systemd/system/NetworkManager.service.d/override.conf
    rm -f /etc/systemd/system/docker-shutdown.service
    rm -f /etc/systemd/system/mt7902-driver-shutdown.service

    systemctl disable docker-shutdown.service 2>/dev/null || true
    systemctl disable mt7902-driver-shutdown.service 2>/dev/null || true
    systemctl daemon-reload

    print_success "Конфигурация удалена (модули .ko в /lib/modules можно убрать через make uninstall в gen4-mt7902 / btusb_mt7902)"
}

# ===== PATCH HELPERS (unchanged logic for kernel tree) =====

print_patch_header() {
    echo -e "${BLUE}"
    echo "📤 Подготовка патча для отправки в ядро Linux"
    echo "=========================================="
    echo -e "${NC}"
}

check_patch_environment() {
    print_info "1. Проверка окружения для патчей..."
    command -v git &>/dev/null || { print_error "Git не установлен"; exit 1; }
    if [[ ! -f "MAINTAINERS" ]] || [[ ! -d "drivers/net/wireless/mediatek/mt76" ]]; then
        print_error "Не в дереве исходников ядра Linux"
        exit 1
    fi
    print_success "Окружение для патчей проверено"
}

check_patches() {
    print_info "2. Проверка патчей..."
    PATCHES_DIR=""
    if [[ -f "patches/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch" ]]; then
        PATCHES_DIR="patches"
    elif [[ -f "0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch" ]]; then
        PATCHES_DIR="."
    else
        print_error "Патч не найден"; exit 1
    fi
    scripts/checkpatch.pl "$PATCHES_DIR/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch" || {
        print_error "Патч не прошел checkpatch.pl"; exit 1
    }
    print_success "Формат патча корректен"
}

get_maintainers() {
    print_info "3. Получение списка мейнтейнеров..."
    MAINTAINERS=$(scripts/get_maintainer.pl "$PATCHES_DIR/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch")
    echo "$MAINTAINERS"
    TO_EMAIL=$(echo "$MAINTAINERS" | grep -E '<.*@.*>' | head -5 | tr '\n' ' ')
    CC_LIST=$(echo "$MAINTAINERS" | grep -E '<.*@.*>' | tail -n +6 | tr '\n' ' ')
    print_success "Список мейнтейнеров получен"
}

create_submission_command() {
    print_info "4. Создание команды отправки..."
    echo ""
    echo "git send-email --to=\"$TO_EMAIL\" --cc=\"$CC_LIST\" \\"
    echo "  --cc-cmd='scripts/get_maintainer.pl --norolestats $PATCHES_DIR/0001-*.patch' \\"
    echo "  --subject-prefix='PATCH net-next' \\"
    echo "  $PATCHES_DIR/0001-net-wireless-mediatek-mt76-mt7921-Add-support-for-PCI-ID-7902.patch"
    echo ""
}

create_project_patch() {
    print_info "Создание полного патча проекта..."
    mkdir -p patches
    cat > patches/MT7902-complete-fix.patch << 'EOF'
From: MediaTek MT7902 WiFi Project <maintainer@example.com>
Subject: [PATCH] Complete MediaTek MT7902 WiFi fix with system optimizations

See project README / GUIDE for out-of-tree mt7902e + btusb_mt7902 installation.
For in-tree, prefer MediaTek upstream MT7902 series (Linux 7.1+).

BugLink: https://github.com/discipleartem/FIX-MediaTek-MT7902-MT7921-MT7961-WIFI
Signed-off-by: MediaTek MT7902 WiFi Project <maintainer@example.com>
EOF
    print_success "Заглушка патча: patches/MT7902-complete-fix.patch"
}

full_install() {
    print_header
    check_root
    check_system
    install_deps
    stop_services
    install_driver
    setup_autoload
    apply_system_settings
    create_services
    enable_services
    load_driver
    verify_installation
    show_instructions
}

install_only_driver() {
    print_header
    check_root
    check_system
    install_deps
    stop_services
    install_driver
    setup_autoload
    load_driver
    verify_installation
    show_instructions
}

install_only_bluetooth() {
    print_header
    check_root
    check_system
    install_deps
    install_bluetooth
    verify_installation
    echo ""
    print_success "Bluetooth установлен!"
    print_info "🔄 Рекомендуется: sudo reboot"
    print_info "📡 Проверка: bluetoothctl show"
}

install_all() {
    print_header
    check_root
    check_system
    install_deps
    stop_services
    install_driver
    setup_autoload
    apply_system_settings
    create_services
    enable_services
    load_driver
    install_bluetooth
    verify_installation
    echo ""
    print_success "Полная установка Wi‑Fi + Bluetooth завершена!"
    print_info "🔄 Обязательно: sudo reboot"
    print_info "📡 nmcli device status && bluetoothctl show"
}

install_only_system() {
    print_header
    check_root
    check_system
    apply_system_settings
    create_services
    enable_services
    verify_installation
    print_success "Системные настройки применены!"
    print_info "🔄 Перезагрузите систему: sudo reboot"
}

prepare_patches() {
    print_patch_header
    check_patch_environment
    check_patches
    get_maintainers
    create_submission_command
    create_project_patch
    print_success "Подготовка патчей завершена!"
}

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
    print_info "📚 GUIDE_EN.md / GUIDE_RU.md"
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
    echo "  remove       Удаление конфигурации"
    echo ""
    echo "📤 Патчи:"
    echo "  patch        Подготовка патчей для ядра"
    echo "  patch-check  Проверка формата патчей"
    echo ""
    echo "🔍 Диагностика:"
    echo "  status       Статус"
    echo "  diagnose     Полная диагностика"
    echo ""
    echo "Примеры:"
    echo "  sudo $0 install-all"
    echo "  sudo $0 bluetooth"
    echo ""
    echo "📚 GUIDE_EN.md / GUIDE_RU.md / README.md"
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

case "${1:-help}" in
    install-all|all) install_all ;;
    install) full_install ;;
    driver) install_only_driver ;;
    bluetooth|bt) install_only_bluetooth ;;
    system) install_only_system ;;
    verify|status) check_status ;;
    remove)
        print_header
        check_root
        remove_installation
        ;;
    patch) prepare_patches ;;
    patch-check)
        print_patch_header
        check_patch_environment
        check_patches
        ;;
    diagnose) run_diagnose ;;
    help|--help|-h) show_help ;;
    *)
        print_error "Неизвестная команда: $1"
        show_help
        exit 1
        ;;
esac
