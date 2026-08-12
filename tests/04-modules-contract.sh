#!/bin/bash
# shellcheck shell=bash
# 4) Module / CLI contract

echo "4) Installer targets correct modules (not in-tree mt7921e hijack)"
assert_installer_contains "WIFI_DIR=gen4-mt7902" '^WIFI_DIR="gen4-mt7902"$'
assert_installer_contains "BT_DIR=btusb_mt7902" '^BT_DIR="btusb_mt7902"$'
assert_installer_contains "WIFI_MOD=mt7902e" '^WIFI_MOD="mt7902e"$'
assert_installer_contains "BT_MOD=btusb_mt7902" '^BT_MOD="btusb_mt7902"$'
assert_installer_contains "WIFI_BRANCH=backport" '^WIFI_BRANCH="backport"$'
assert_installer_contains "BT_BRANCH=bluetooth_backport" '^BT_BRANCH="bluetooth_backport"$'
assert_installer_contains "PCI ID 14c3:7902 in check_system" '14c3:7902'
assert_installer_contains "case has install-all" 'install-all\|all\)'
assert_installer_contains "case has bluetooth" 'bluetooth\|bt\)'
assert_installer_contains "case has diagnose" 'diagnose\)'
assert_installer_contains "case has remove" 'remove\)'
assert_installer_contains "case has rollback" 'rollback\|restore\)'
assert_installer_not_contains "WIFI_MOD is not stock mt7921e" '^WIFI_MOD="mt7921e"$'
assert_contains "mt7902.sh version 6.0.1" "mt7902.sh" 'Версия: 6\.0\.1'
assert_contains "CHANGELOG has 6.0.1" "CHANGELOG.md" '^## 6\.0\.1'
echo ""
