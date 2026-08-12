#!/bin/bash
# shellcheck shell=bash
# 5) Safety / side effects + managed paths contract

echo "5) Safety: side effects are scoped and reversible"
assert_installer_contains "blacklist btusb" '^blacklist btusb$'
assert_installer_contains "blacklist btmtk" '^blacklist btmtk$'
assert_installer_not_contains "does not blacklist rtw88" 'blacklist rtw'
assert_installer_not_contains "does not blacklist mt7921e" 'blacklist mt7921'
assert_installer_contains "warns that stock btusb adapters stop working" \
    'штатный btusb больше не будет'
assert_installer_contains "Wi‑Fi modules-load path" '/etc/modules-load\.d/mt7902\.conf'
assert_installer_contains "BT modules-load path" '/etc/modules-load\.d/btusb_mt7902\.conf'
assert_installer_contains "pre-install backup dir" '/var/lib/mt7902-fix'
assert_installer_contains "create_pre_install_backup" 'create_pre_install_backup'
assert_installer_contains "rollback_installation" 'rollback_installation'
assert_installer_contains "prompt_rollback_if_failed" 'prompt_rollback_if_failed'
assert_installer_contains "AUTO_ROLLBACK env" 'MT7902_AUTO_ROLLBACK'
assert_installer_contains "remove asks for confirmation" 'Вы уверены\?'
assert_installer_contains "blacklist_btusb.conf managed" 'blacklist_btusb\.conf'
assert_installer_not_contains "no recursive rm of /" 'rm -rf[[:space:]]+/($|[[:space:]])'
assert_installer_not_contains "no rm -rf /etc" 'rm -rf[[:space:]]+/etc'
assert_installer_contains "DefaultTimeoutStopSec=30s" 'DefaultTimeoutStopSec=30s'
assert_installer_not_contains "does not set TimeoutStop infinity" 'TimeoutStopSec=infinity'

# Managed paths contract (rollback must know these)
for path in \
    '/etc/modules-load.d/mt7902.conf' \
    '/etc/modules-load.d/btusb_mt7902.conf' \
    '/etc/modprobe.d/mt7902.conf' \
    '/etc/modprobe.d/blacklist_btusb.conf' \
    '/etc/systemd/system.conf.d/99-timeouts.conf' \
    '/etc/systemd/system/docker.service.d/override.conf' \
    '/etc/systemd/system/NetworkManager.service.d/override.conf' \
    '/etc/systemd/system/docker-shutdown.service' \
    '/etc/systemd/system/mt7902-driver-shutdown.service' \
    '/etc/systemd/system/mt7902-watchdog.service' \
    '/usr/local/sbin/mt7902-watchdog'
do
    assert_installer_contains "managed path $path" "$path"
done
assert_installer_contains "shutdown unit unload wifi" 'modprobe -r.*WIFI_MOD|modprobe -r \$\{WIFI_MOD\}'
assert_installer_contains "diagnose filters MediaTek logs" 'mt7902\|btusb_mt7902\|mediatek'
assert_installer_not_contains "diagnose does not dump unrelated -p err" 'journalctl -b -p err'
echo ""
