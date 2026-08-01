#!/bin/bash
# shellcheck shell=bash
# 3) CLI help & unknown

echo "3) CLI: help & unknown command"
HELP_OUT="$(bash "$ROOT/mt7902.sh" help 2>&1 || true)"
for cmd in install-all install driver bluetooth system verify rollback remove diagnose status; do
    if echo "$HELP_OUT" | grep -q "$cmd"; then
        ok "help lists $cmd"
    else
        fail "help lists $cmd"
    fi
done
if echo "$HELP_OUT" | grep -qiE 'all→install-all|all->install-all|Алиасы'; then
    ok "help documents aliases"
else
    fail "help documents aliases"
fi
if echo "$HELP_OUT" | grep -qiE 'patch-check|^[[:space:]]*patch[[:space:]]'; then
    fail "help must not list removed patch CLI"
else
    ok "help has no patch CLI"
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
