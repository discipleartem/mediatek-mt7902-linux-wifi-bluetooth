#!/bin/bash
# shellcheck shell=bash

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
After=mt7902-watchdog.service

[Service]
Type=oneshot
ExecStart=/sbin/modprobe -r ${WIFI_MOD}
TimeoutStartSec=10s
RemainAfterExit=yes

[Install]
WantedBy=halt.target reboot.target shutdown.target
EOF

    install_watchdog_files
    print_success "Сервисы созданы"
}

install_watchdog_files() {
    local src="$SCRIPT_DIR/scripts/mt7902-watchdog.sh"
    if [[ ! -f "$src" ]]; then
        print_warning "watchdog script missing: $src"
        return 0
    fi
    install -m 0755 "$src" /usr/local/sbin/mt7902-watchdog
    cat > /etc/systemd/system/mt7902-watchdog.service << 'EOF'
[Unit]
Description=MT7902 Wi-Fi/Bluetooth watchdog (reload mt7902e / btusb_mt7902 if they drop)
Documentation=file:///usr/local/sbin/mt7902-watchdog
After=systemd-modules-load.service NetworkManager.service bluetooth.service
Before=mt7902-driver-shutdown.service
ConditionPathExists=/usr/local/sbin/mt7902-watchdog

[Service]
Type=simple
ExecStart=/usr/local/sbin/mt7902-watchdog
Restart=on-failure
RestartSec=10
Nice=10

[Install]
WantedBy=multi-user.target
EOF
}

enable_watchdog() {
    print_step "Включение watchdog Wi‑Fi/Bluetooth"
    install_watchdog_files
    systemctl daemon-reload
    systemctl enable mt7902-watchdog.service
    systemctl start mt7902-watchdog.service
    print_success "mt7902-watchdog.service запущен"
}

disable_watchdog() {
    systemctl stop mt7902-watchdog.service 2>/dev/null || true
    systemctl disable mt7902-watchdog.service 2>/dev/null || true
}

enable_services() {
    print_step "Активация сервисов"
    systemctl daemon-reload
    if command -v docker &>/dev/null; then
        systemctl enable docker-shutdown.service || true
    fi
    systemctl enable mt7902-driver-shutdown.service
    systemctl enable mt7902-watchdog.service 2>/dev/null || true
    print_success "Сервисы активированы"
}
