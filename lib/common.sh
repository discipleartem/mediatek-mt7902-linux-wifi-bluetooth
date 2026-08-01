#!/bin/bash
# shellcheck shell=bash
# Common globals, logging, root check for MT7902 installer.

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
