#!/bin/bash
# Runtime repair for MediaTek MT7902 Wi‑Fi / Bluetooth.
# Reloads mt7902e / btusb_mt7902 when they drop — does NOT reinstall.
#
#   sudo mt7902-watchdog              # loop (systemd)
#   sudo mt7902-watchdog --once       # one check + repair if needed
#   mt7902-watchdog --check           # status only (no root)
#
# Skips repair if rfkill/NM radio is off (user intent) or MT7902 is absent.
# Rate-limited so a broken module cannot hammer the system.

set -u

WIFI_MOD="${WIFI_MOD:-mt7902e}"
BT_MOD="${BT_MOD:-btusb_mt7902}"
INTERVAL="${MT7902_WATCHDOG_INTERVAL:-15}"
COOLDOWN="${MT7902_WATCHDOG_COOLDOWN:-45}"
MAX_PER_HOUR="${MT7902_WATCHDOG_MAX_PER_HOUR:-8}"
STATE_DIR="${MT7902_WATCHDOG_STATE_DIR:-/run/mt7902-watchdog}"
REPAIR_LOG="${STATE_DIR}/repairs"

log() {
    local msg="$*"
    echo "$(date -Is) $msg"
    if command -v logger >/dev/null 2>&1; then
        logger -t mt7902-watchdog -- "$msg" || true
    fi
}

want_wifi() { [[ -f /etc/modules-load.d/mt7902.conf ]]; }
want_bt() {
    [[ -f /etc/modules-load.d/btusb_mt7902.conf ]] || [[ -f /etc/modprobe.d/blacklist_btusb.conf ]]
}

hardware_present() {
    lspci -nn 2>/dev/null | grep -qi '14c3:7902' && return 0
    lsusb 2>/dev/null | grep -qi '13d3:3594' && return 0
    lsmod 2>/dev/null | grep -qE "$WIFI_MOD|$BT_MOD" && return 0
    return 1
}

rfkill_blocked() {
    local kind="$1"
    command -v rfkill >/dev/null 2>&1 || return 1
    rfkill list "$kind" 2>/dev/null | grep -qi 'yes'
}

wifi_intentionally_off() {
    rfkill_blocked wifi && return 0
    rfkill_blocked wlan && return 0
    if command -v nmcli >/dev/null 2>&1; then
        [[ "$(nmcli radio wifi 2>/dev/null || true)" == "disabled" ]] && return 0
    fi
    return 1
}

bt_intentionally_off() {
    rfkill_blocked bluetooth && return 0
    return 1
}

wifi_ok() {
    lsmod 2>/dev/null | grep -q "$WIFI_MOD" || return 1
    ip -br link 2>/dev/null | grep -qiE 'wlan|wlp' || return 1
    return 0
}

bt_ok() {
    lsmod 2>/dev/null | grep -q "$BT_MOD" || return 1
    if command -v bluetoothctl >/dev/null 2>&1; then
        local show
        show="$(bluetoothctl show 2>/dev/null || true)"
        echo "$show" | grep -qi 'Powered: yes' || return 1
        echo "$show" | grep -q '00:00:00:00:00:00' && return 1
    fi
    return 0
}

prune_repairs() {
    local cutoff now
    now="$(date +%s)"
    cutoff=$((now - 3600))
    mkdir -p "$STATE_DIR"
    if [[ -f "$REPAIR_LOG" ]]; then
        awk -v c="$cutoff" '$1+0 >= c {print}' "$REPAIR_LOG" > "${REPAIR_LOG}.new" 2>/dev/null || true
        mv -f "${REPAIR_LOG}.new" "$REPAIR_LOG" 2>/dev/null || true
    else
        : > "$REPAIR_LOG"
    fi
}

repairs_this_hour() {
    prune_repairs
    if [[ -f "$REPAIR_LOG" ]]; then
        wc -l < "$REPAIR_LOG" | tr -d ' '
    else
        echo 0
    fi
}

note_repair() {
    mkdir -p "$STATE_DIR"
    date +%s >> "$REPAIR_LOG"
}

rate_limited() {
    local n
    n="$(repairs_this_hour)"
    if [[ "$n" -ge "$MAX_PER_HOUR" ]]; then
        log "rate limit: $n repairs in last hour (max $MAX_PER_HOUR) — skipping"
        return 0
    fi
    return 1
}

repair_wifi() {
    log "Wi-Fi down — reloading $WIFI_MOD"
    /sbin/modprobe "$WIFI_MOD" || {
        log "modprobe $WIFI_MOD failed"
        return 1
    }
    if command -v systemctl >/dev/null 2>&1; then
        systemctl start NetworkManager 2>/dev/null || true
    fi
    sleep 3
    if wifi_ok; then
        log "Wi-Fi repaired"
        return 0
    fi
    log "Wi-Fi still down after reload"
    return 1
}

repair_bt() {
    log "Bluetooth down — reloading $BT_MOD"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop bluetooth 2>/dev/null || true
    fi
    /sbin/modprobe -r "$BT_MOD" 2>/dev/null || true
    /sbin/modprobe -r btusb 2>/dev/null || true
    /sbin/modprobe -r btmtk 2>/dev/null || true
    /sbin/modprobe "$BT_MOD" || {
        log "modprobe $BT_MOD failed"
        return 1
    }
    if command -v rfkill >/dev/null 2>&1; then
        rfkill unblock bluetooth 2>/dev/null || true
    fi
    if command -v systemctl >/dev/null 2>&1; then
        systemctl start bluetooth 2>/dev/null || true
    fi
    sleep 2
    if command -v bluetoothctl >/dev/null 2>&1; then
        bluetoothctl power on >/dev/null 2>&1 || true
    fi
    sleep 1
    if bt_ok; then
        log "Bluetooth repaired"
        return 0
    fi
    log "Bluetooth still down after reload"
    return 1
}

print_status() {
    echo "hardware: $(hardware_present && echo present || echo absent)"
    if want_wifi; then
        echo -n "wifi: "
        if wifi_intentionally_off; then
            echo "intentionally-off"
        elif wifi_ok; then
            echo "ok"
        else
            echo "down"
        fi
    else
        echo "wifi: not-managed"
    fi
    if want_bt; then
        echo -n "bluetooth: "
        if bt_intentionally_off; then
            echo "intentionally-off"
        elif bt_ok; then
            echo "ok"
        else
            echo "down"
        fi
    else
        echo "bluetooth: not-managed"
    fi
}

tick() {
    local did=0
    hardware_present || return 0

    if want_wifi && ! wifi_intentionally_off && ! wifi_ok; then
        if rate_limited; then
            return 1
        fi
        repair_wifi || true
        note_repair
        did=1
    fi

    if want_bt && ! bt_intentionally_off && ! bt_ok; then
        if rate_limited; then
            return 1
        fi
        repair_bt || true
        note_repair
        did=1
    fi

    [[ "$did" -eq 1 ]] && return 2
    return 0
}

usage() {
    echo "mt7902-watchdog — reload mt7902e / btusb_mt7902 when they drop"
    echo "  --check   print status, do not repair"
    echo "  --once    one check + repair if needed"
    echo "  --help    this help"
    echo "  (default) loop every ${INTERVAL}s (systemd)"
}

cmd="${1:-}"
case "$cmd" in
    --help|-h)
        usage
        exit 0
        ;;
    --check)
        print_status
        exit 0
        ;;
    --once)
        if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
            echo "sudo required for --once" >&2
            exit 1
        fi
        tick
        rc=$?
        [[ "$rc" -eq 2 ]] && exit 0
        exit "$rc"
        ;;
    "")
        if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
            echo "sudo required for watchdog loop (or use --check)" >&2
            exit 1
        fi
        mkdir -p "$STATE_DIR"
        log "started interval=${INTERVAL}s cooldown=${COOLDOWN}s max/hour=${MAX_PER_HOUR}"
        while true; do
            tick
            rc=$?
            if [[ "$rc" -eq 2 ]]; then
                sleep "$COOLDOWN"
            else
                sleep "$INTERVAL"
            fi
        done
        ;;
    *)
        echo "unknown option: $cmd" >&2
        usage
        exit 1
        ;;
esac
