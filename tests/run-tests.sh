#!/bin/bash
# Smoke / regression tests for the MT7902 fix pack (no root, no hardware).
# Run first before install or editing installer logic:
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

echo "MT7902 repo tests"
echo "================="
echo "Root: $ROOT"
echo ""

echo "1) Required files"
assert_file "mt7902.sh"
assert_file "Makefile"
assert_file "README.md"
assert_file "GUIDE_RU.md"
assert_file "GUIDE_EN.md"
assert_file "AGENTS.md"
assert_file "llms.txt"
assert_file "llms-full.txt"
assert_file "LICENSE"
assert_file "patches/README.md"
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

UNKNOWN_RC=0
UNKNOWN_OUT="$(bash "$ROOT/mt7902.sh" definitely-not-a-command 2>&1)" || UNKNOWN_RC=$?
assert_eq "unknown command exits non-zero" "1" "$UNKNOWN_RC"
if echo "$UNKNOWN_OUT" | grep -qi "Неизвестная\|unknown\|help"; then
    ok "unknown command shows help-like message"
else
    fail "unknown command shows help-like message"
fi
echo ""

echo "4) Installer constants"
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
assert_contains "blacklist btusb" "mt7902.sh" 'blacklist btusb'
assert_contains "blacklist btmtk" "mt7902.sh" 'blacklist btmtk'
echo ""

echo "5) Makefile targets"
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

echo "6) Docs: PCI/USB IDs & entrypoints stay in sync"
for doc in README.md GUIDE_RU.md GUIDE_EN.md AGENTS.md llms.txt llms-full.txt; do
    assert_contains "$doc has 14c3:7902" "$doc" '14c3:7902'
done
assert_contains "README has mt7902e" "README.md" 'mt7902e'
assert_contains "README has btusb_mt7902" "README.md" 'btusb_mt7902'
assert_contains "README has install-all" "README.md" 'install-all'
assert_contains "AGENTS.md mentions tests first" "AGENTS.md" 'tests/run-tests\.sh|make test'
assert_contains "README mentions tests" "README.md" 'tests/run-tests\.sh|make test'
assert_contains "GUIDE_RU mentions tests" "GUIDE_RU.md" 'tests/run-tests\.sh|make test'
assert_contains "GUIDE_EN mentions tests" "GUIDE_EN.md" 'tests/run-tests\.sh|make test'
echo ""

echo "7) Optional: shellcheck"
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

echo "8) Optional: cloned driver trees look sane"
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
echo "================="
echo -e "Result: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${SKIP} skipped${NC} (of $TOTAL)"
if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
exit 0
