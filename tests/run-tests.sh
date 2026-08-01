#!/bin/bash
# Safety / regression tests for the MT7902 fix pack.
#
# Goal: catch installer/docs regressions that could harm a user's system
# (wrong modules, silent side effects, missing warnings, broken uninstall)
# before anyone runs sudo ./mt7902.sh install-all.
#
#   ./tests/run-tests.sh
#   make test

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0
SKIP=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok() {
    echo -e "  ${GREEN}PASS${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "  ${RED}FAIL${NC} $1"
    FAIL=$((FAIL + 1))
}

skip() {
    echo -e "  ${YELLOW}SKIP${NC} $1"
    SKIP=$((SKIP + 1))
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        ok "$desc"
    else
        fail "$desc (expected='$expected' actual='$actual')"
    fi
}

assert_file() {
    local path="$1"
    if [[ -f "$ROOT/$path" ]]; then
        ok "file exists: $path"
    else
        fail "file missing: $path"
    fi
}

assert_contains() {
    local desc="$1" file="$2" pattern="$3"
    if grep -qE "$pattern" "$ROOT/$file"; then
        ok "$desc"
    else
        fail "$desc (pattern /$pattern/ in $file)"
    fi
}

assert_not_contains() {
    local desc="$1" file="$2" pattern="$3"
    if grep -qE "$pattern" "$ROOT/$file"; then
        fail "$desc (unexpected /$pattern/ in $file)"
    else
        ok "$desc"
    fi
}

echo "MT7902 safety tests"
echo "==================="
echo "Purpose: ensure the driver patch/installer will not harm user systems."
echo "Root: $ROOT"
echo ""

echo "1) Required files"
assert_file "mt7902.sh"
assert_file "Makefile"
assert_file "README.md"
assert_file "README.ru.md"
assert_file "AGENTS.md"
assert_file "llms.txt"
assert_file "llms-full.txt"
assert_file "LICENSE"
assert_file "patches/README.md"
assert_file "docs/installation.md"
assert_file "docs/supported-hardware.md"
assert_file "docs/faq.md"
assert_file "docs/ru/installation.md"
assert_file "docs/ru/supported-hardware.md"
assert_file "docs/ru/faq.md"
echo ""

echo "2) Script permissions & syntax"
if [[ -x "$ROOT/mt7902.sh" ]]; then
    ok "mt7902.sh is executable"
else
    fail "mt7902.sh is not executable"
fi
if [[ -x "$ROOT/tests/run-tests.sh" ]]; then
    ok "tests/run-tests.sh is executable"
else
    fail "tests/run-tests.sh is not executable"
fi
if bash -n "$ROOT/mt7902.sh"; then
    ok "mt7902.sh bash -n"
else
    fail "mt7902.sh bash -n"
fi
if bash -n "$ROOT/tests/run-tests.sh"; then
    ok "tests/run-tests.sh bash -n"
else
    fail "tests/run-tests.sh bash -n"
fi
echo ""

echo "3) CLI: help & unknown command"
HELP_OUT="$(bash "$ROOT/mt7902.sh" help 2>&1 || true)"
if echo "$HELP_OUT" | grep -q "install-all"; then
    ok "help lists install-all"
else
    fail "help lists install-all"
fi
if echo "$HELP_OUT" | grep -q "bluetooth"; then
    ok "help lists bluetooth"
else
    fail "help lists bluetooth"
fi
if echo "$HELP_OUT" | grep -q "diagnose"; then
    ok "help lists diagnose"
else
    fail "help lists diagnose"
fi
if echo "$HELP_OUT" | grep -q "remove"; then
    ok "help lists remove (uninstall path)"
else
    fail "help lists remove (uninstall path)"
fi
if echo "$HELP_OUT" | grep -q "rollback"; then
    ok "help lists rollback"
else
    fail "help lists rollback"
fi

UNKNOWN_RC=0
UNKNOWN_OUT="$(bash "$ROOT/mt7902.sh" definitely-not-a-command 2>&1)" || UNKNOWN_RC=$?
assert_eq "unknown command exits non-zero" "1" "$UNKNOWN_RC"
if echo "$UNKNOWN_OUT" | grep -qi "Неизвестная\|unknown\|help"; then
    ok "unknown command shows help-like message"
else
    fail "unknown command shows help-like message"
fi
echo ""

echo "4) Installer targets correct modules (not in-tree mt7921e hijack)"
assert_contains "WIFI_DIR=gen4-mt7902" "mt7902.sh" '^WIFI_DIR="gen4-mt7902"$'
assert_contains "BT_DIR=btusb_mt7902" "mt7902.sh" '^BT_DIR="btusb_mt7902"$'
assert_contains "WIFI_MOD=mt7902e" "mt7902.sh" '^WIFI_MOD="mt7902e"$'
assert_contains "BT_MOD=btusb_mt7902" "mt7902.sh" '^BT_MOD="btusb_mt7902"$'
assert_contains "WIFI_BRANCH=backport" "mt7902.sh" '^WIFI_BRANCH="backport"$'
assert_contains "BT_BRANCH=bluetooth_backport" "mt7902.sh" '^BT_BRANCH="bluetooth_backport"$'
assert_contains "PCI ID 14c3:7902 in check_system" "mt7902.sh" '14c3:7902'
assert_contains "case has install-all" "mt7902.sh" 'install-all\|all\)'
assert_contains "case has bluetooth" "mt7902.sh" 'bluetooth\|bt\)'
assert_contains "case has diagnose" "mt7902.sh" 'diagnose\)'
assert_contains "case has remove" "mt7902.sh" 'remove\)'
assert_contains "case has rollback" "mt7902.sh" 'rollback\|restore\)'
assert_not_contains "WIFI_MOD is not stock mt7921e" "mt7902.sh" '^WIFI_MOD="mt7921e"$'
echo ""

echo "5) Safety: side effects are scoped and reversible"
# Blacklist only the conflicting BT stack — not Wi‑Fi USB drivers
assert_contains "blacklist btusb" "mt7902.sh" '^blacklist btusb$'
assert_contains "blacklist btmtk" "mt7902.sh" '^blacklist btmtk$'
assert_not_contains "does not blacklist rtw88" "mt7902.sh" 'blacklist rtw'
assert_not_contains "does not blacklist mt7921e" "mt7902.sh" 'blacklist mt7921'
# User must see the Realtek USB BT side effect
assert_contains "warns that stock btusb adapters stop working" "mt7902.sh" \
    'штатный btusb больше не будет'
# Autoload files are MT7902-specific
assert_contains "Wi‑Fi modules-load path" "mt7902.sh" '/etc/modules-load\.d/mt7902\.conf'
assert_contains "BT modules-load path" "mt7902.sh" '/etc/modules-load\.d/btusb_mt7902\.conf'
# Backup + rollback restore original user settings
assert_contains "pre-install backup dir" "mt7902.sh" '/var/lib/mt7902-fix'
assert_contains "create_pre_install_backup" "mt7902.sh" 'create_pre_install_backup'
assert_contains "rollback_installation" "mt7902.sh" 'rollback_installation'
assert_contains "prompt_rollback_if_failed" "mt7902.sh" 'prompt_rollback_if_failed'
assert_contains "case has rollback" "mt7902.sh" 'rollback\|restore\)'
assert_contains "help lists rollback" "mt7902.sh" 'rollback'
assert_contains "AUTO_ROLLBACK env" "mt7902.sh" 'MT7902_AUTO_ROLLBACK'
# Uninstall exists, confirms, and only removes our files (rm -f, not rm -rf /)
assert_contains "remove asks for confirmation" "mt7902.sh" 'Вы уверены\?'
assert_contains "remove deletes blacklist file" "mt7902.sh" 'blacklist_btusb\.conf'
assert_not_contains "no recursive rm of /" "mt7902.sh" 'rm -rf[[:space:]]+/($|[[:space:]])'
assert_not_contains "no rm -rf /etc" "mt7902.sh" 'rm -rf[[:space:]]+/etc'
# Reasonable systemd timeouts (not zero / infinity)
assert_contains "DefaultTimeoutStopSec=30s" "mt7902.sh" 'DefaultTimeoutStopSec=30s'
assert_not_contains "does not set TimeoutStop infinity" "mt7902.sh" 'TimeoutStopSec=infinity'
echo ""

echo "6) Docs warn users about side effects"
for doc in README.md README.ru.md docs/faq.md docs/ru/faq.md AGENTS.md; do
    assert_contains "$doc warns about btusb blacklist" "$doc" 'blacklist|блокир'
done
assert_contains "README mentions Realtek BT side effect" "README.md" 'Realtek'
assert_contains "AGENTS.md mentions Secure Boot" "AGENTS.md" 'Secure Boot'
assert_contains "docs say run tests to protect users / before install" "AGENTS.md" \
    'harm|навред|protect|safety|не навред|before.*install|перед.*установ'
assert_contains "docs/installation.md explains script is not a daemon" "docs/installation.md" \
    'not.*daemon|not.*added to boot'
assert_contains "docs/ru/installation.md explains script is not a daemon" "docs/ru/installation.md" \
    'не.*демон|не прописывается в автозагрузку'
assert_contains "README mentions modules-load autoload" "README.md" 'modules-load\.d'
echo ""

echo "7) Makefile targets"
for target in test test-hw check-status diagnose help install-all bluetooth quick-install; do
    if grep -qE "^${target}([ :]|$)" "$ROOT/Makefile"; then
        ok "Makefile has target: $target"
    else
        fail "Makefile has target: $target"
    fi
done
if grep -q 'tests/run-tests.sh' "$ROOT/Makefile"; then
    ok "Makefile test runs tests/run-tests.sh"
else
    fail "Makefile test runs tests/run-tests.sh"
fi
echo ""

echo "8) Docs: PCI/USB IDs & entrypoints stay in sync"
for doc in README.md README.ru.md AGENTS.md llms.txt llms-full.txt \
    docs/installation.md docs/supported-hardware.md docs/faq.md \
    docs/ru/installation.md docs/ru/supported-hardware.md docs/ru/faq.md; do
    assert_contains "$doc has 14c3:7902" "$doc" '14c3:7902'
done
assert_contains "README has mt7902e" "README.md" 'mt7902e'
assert_contains "README has btusb_mt7902" "README.md" 'btusb_mt7902'
assert_contains "README has install-all" "README.md" 'install-all'
assert_contains "AGENTS.md mentions tests" "AGENTS.md" 'tests/run-tests\.sh|make test'
assert_contains "README mentions tests" "README.md" 'tests/run-tests\.sh|make test'
assert_contains "docs/installation.md mentions tests" "docs/installation.md" 'tests/run-tests\.sh|make test'
assert_contains "docs/ru/installation.md mentions tests" "docs/ru/installation.md" 'tests/run-tests\.sh|make test'
# Agent discoverability: canonical URL + match keywords stay citable
CANON_URL='mediatek-mt7902-linux-wifi-bluetooth'
for doc in README.md AGENTS.md llms.txt llms-full.txt; do
    assert_contains "$doc has canonical repo URL" "$doc" "$CANON_URL"
done
assert_contains "llms.txt has agent instructions" "llms.txt" 'Instructions for AI agents'
assert_contains "llms.txt has Opcode -110" "llms.txt" 'Opcode 0x0c03 failed'
assert_contains "llms-full.txt has former repo name" "llms-full.txt" 'FIX-MediaTek-MT7902-MT7921-MT7961-WIFI'
echo ""

echo "9) Optional: shellcheck"
SHELLCHECK=""
if [[ -x "$ROOT/tools/shellcheck" ]]; then
    SHELLCHECK="$ROOT/tools/shellcheck"
elif command -v shellcheck >/dev/null 2>&1; then
    SHELLCHECK="$(command -v shellcheck)"
fi
if [[ -n "$SHELLCHECK" ]]; then
    if "$SHELLCHECK" -e SC2086,SC2164,SC2181 "$ROOT/mt7902.sh" "$ROOT/tests/run-tests.sh"; then
        ok "shellcheck mt7902.sh + tests"
    else
        fail "shellcheck mt7902.sh + tests"
    fi
else
    skip "shellcheck not installed"
fi
echo ""

echo "10) Optional: cloned driver trees look sane"
if [[ -f "$ROOT/gen4-mt7902/Makefile" ]]; then
    ok "gen4-mt7902/Makefile present"
else
    skip "gen4-mt7902/ not cloned (ok; install will clone)"
fi
if [[ -f "$ROOT/btusb_mt7902/Makefile" ]]; then
    ok "btusb_mt7902/Makefile present"
else
    skip "btusb_mt7902/ not cloned (ok; install will clone)"
fi
echo ""

TOTAL=$((PASS + FAIL + SKIP))
echo "==================="
echo -e "Result: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${SKIP} skipped${NC} (of $TOTAL)"
if [[ "$FAIL" -gt 0 ]]; then
    echo "Failing tests mean the pack may be unsafe to install — fix before sudo install-all."
    exit 1
fi
exit 0
