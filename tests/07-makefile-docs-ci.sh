#!/bin/bash
# shellcheck shell=bash
# 7) Makefile + docs ID sync + shellcheck + optional trees

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
if grep -qE '^all:[[:space:]]*help' "$ROOT/Makefile"; then
    ok "Makefile all defaults to help"
else
    fail "Makefile all defaults to help"
fi
if grep -q 'mt7921e_simple_patch' "$ROOT/Makefile"; then
    fail "Makefile must not reference stub patch driver"
else
    ok "Makefile has no stub patch driver"
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
CANON_URL='mediatek-mt7902-linux-wifi-bluetooth'
for doc in README.md AGENTS.md llms.txt llms-full.txt; do
    assert_contains "$doc has canonical repo URL" "$doc" "$CANON_URL"
done
assert_contains "llms.txt has agent instructions" "llms.txt" 'Instructions for AI agents'
assert_contains "llms.txt has Opcode -110" "llms.txt" 'Opcode 0x0c03 failed'
assert_contains "llms-full.txt has former repo name" "llms-full.txt" 'FIX-MediaTek-MT7902-MT7921-MT7961-WIFI'
echo ""

echo "9) shellcheck"
SHELLCHECK=""
if [[ -x "$ROOT/tools/shellcheck" ]]; then
    SHELLCHECK="$ROOT/tools/shellcheck"
elif command -v shellcheck >/dev/null 2>&1; then
    SHELLCHECK="$(command -v shellcheck)"
fi
SC_FILES=()
while IFS= read -r f; do
    [[ -f "$f" ]] && SC_FILES+=("$f")
done < <(all_shell_scripts)

if [[ -n "$SHELLCHECK" ]]; then
    if "$SHELLCHECK" -e SC2086,SC2164,SC2181,SC2034,SC1091 "${SC_FILES[@]}"; then
        ok "shellcheck installer + tests"
    else
        fail "shellcheck installer + tests"
    fi
elif [[ "${SHELLCHECK_REQUIRED:-}" == "1" ]]; then
    fail "shellcheck required but not installed"
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
