#!/bin/bash
# shellcheck shell=bash
# 2) Permissions & syntax

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
if [[ -x "$ROOT/scripts/mt7902-watchdog.sh" ]]; then
    ok "scripts/mt7902-watchdog.sh is executable"
else
    fail "scripts/mt7902-watchdog.sh is not executable"
fi

local_fail=0
while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    if bash -n "$f"; then
        ok "bash -n ${f#"$ROOT"/}"
    else
        fail "bash -n ${f#"$ROOT"/}"
        local_fail=1
    fi
done < <(all_shell_scripts)
unset local_fail
echo ""
