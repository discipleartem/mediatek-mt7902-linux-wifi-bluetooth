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

# Pre-install backup of user configs (for rollback if Wi‑Fi/BT fail)
BACKUP_ROOT="/var/lib/mt7902-fix"
BACKUP_DIR="$BACKUP_ROOT/backup"
MANAGED_FILES=(
    /etc/modules-load.d/mt7902.conf
    /etc/modules-load.d/btusb_mt7902.conf
    /etc/modprobe.d/mt7902.conf
    /etc/modprobe.d/blacklist_btusb.conf
    /etc/systemd/system.conf.d/99-timeouts.conf
    /etc/systemd/system/docker.service.d/override.conf
    /etc/systemd/system/NetworkManager.service.d/override.conf
    /etc/systemd/system/docker-shutdown.service
    /etc/systemd/system/mt7902-driver-shutdown.service
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
SCRIPT_ARGS=("$@")

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
    if [[ $EUID -ne 0 ]]; then
        print_error "Требуются права суперпользователя: sudo $0 ${SCRIPT_ARGS[*]}"
        exit 1
    fi
}

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
    if command -v docker &>/dev/null; then
        systemctl enable docker-shutdown.service || true
    fi
    systemctl enable mt7902-driver-shutdown.service
    print_success "Сервисы активированы"
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

# ===== BACKUP / ROLLBACK (restore user's original settings) =====

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

wifi_seems_up() {
    lsmod | grep -q "$WIFI_MOD" || return 1
    ip -br link 2>/dev/null | grep -qiE 'wlan|wlp' && return 0
    # Module loaded is enough pre-reboot; iface may appear after NM settles
    return 0
}

bt_seems_up() {
    lsmod | grep -q "$BT_MOD" || return 1
    return 0
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
        # No backup entry — remove our file if present
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

    systemctl disable docker-shutdown.service 2>/dev/null || true
    systemctl disable mt7902-driver-shutdown.service 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true

    # Stock BT stack was blacklisted — try to bring it back
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

See project README / docs/installation.md for out-of-tree mt7902e + btusb_mt7902 installation.
For in-tree, prefer MediaTek upstream MT7902 series (Linux 7.1+).

BugLink: https://github.com/discipleartem/mediatek-mt7902-linux-wifi-bluetooth
Signed-off-by: MediaTek MT7902 WiFi Project <maintainer@example.com>
EOF
    print_success "Заглушка патча: patches/MT7902-complete-fix.patch"
}

full_install() {
    print_header
    check_root
    check_system
    create_pre_install_backup 1 0 1
    install_deps
    stop_services
    install_driver
    setup_autoload
    apply_system_settings
    create_services
    enable_services
    load_driver
    verify_installation
    prompt_rollback_if_failed 1 0 || true
    show_instructions
}

install_only_driver() {
    print_header
    check_root
    check_system
    create_pre_install_backup 1 0 0
    install_deps
    stop_services
    install_driver
    setup_autoload
    load_driver
    verify_installation
    prompt_rollback_if_failed 1 0 || true
    show_instructions
}

install_only_bluetooth() {
    print_header
    check_root
    check_system
    create_pre_install_backup 0 1 0
    install_deps
    install_bluetooth
    verify_installation
    prompt_rollback_if_failed 0 1 || true
    echo ""
    print_success "Bluetooth установлен!"
    print_info "🔄 Рекомендуется: sudo reboot"
    print_info "📡 Проверка: bluetoothctl show"
    print_info "↩️  Откат при проблемах: sudo $0 rollback"
}

install_all() {
    print_header
    check_root
    check_system
    create_pre_install_backup 1 1 1
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
    prompt_rollback_if_failed 1 1 || true
    echo ""
    print_success "Полная установка Wi‑Fi + Bluetooth завершена!"
    print_info "🔄 Обязательно: sudo reboot"
    print_info "📡 nmcli device status && bluetoothctl show"
    print_info "↩️  Если после reboot нет Wi‑Fi/BT: sudo $0 rollback"
}

install_only_system() {
    print_header
    check_root
    check_system
    create_pre_install_backup 0 0 1
    apply_system_settings
    create_services
    enable_services
    verify_installation
    print_success "Системные настройки применены!"
    print_info "🔄 Перезагрузите систему: sudo reboot"
    print_info "↩️  Откат: sudo $0 rollback"
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
    print_info "↩️  Откат (вернуть исходные настройки):"
    echo "  sudo $0 rollback"
    echo ""
    print_info "📚 docs/installation.md · docs/ru/installation.md · README.md"
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
    echo "  sudo $0 rollback"
    echo "  MT7902_AUTO_ROLLBACK=1 sudo $0 install-all   # откат без вопроса при сбое"
    echo ""
    echo "📚 docs/installation.md · docs/ru/installation.md · README.md"
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
