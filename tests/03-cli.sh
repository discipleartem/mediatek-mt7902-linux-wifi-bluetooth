#!/bin/bash
# shellcheck shell=bash
# 3) CLI help & unknown

echo "3) CLI: help & unknown command"
HELP_OUT="$(bash "$ROOT/mt7902.sh" help 2>&1 || true)"
for cmd in install-all install driver bluetooth system verify rollback remove diagnose status watchdog; do
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

WD_HELP="$(bash "$ROOT/scripts/mt7902-watchdog.sh" --help 2>&1 || true)"
if echo "$WD_HELP" | grep -q "mt7902e"; then
    ok "watchdog --help mentions mt7902e"
else
    fail "watchdog --help mentions mt7902e"
fi
WD_CHECK="$(bash "$ROOT/scripts/mt7902-watchdog.sh" --check 2>&1 || true)"
if echo "$WD_CHECK" | grep -qE 'wifi:|bluetooth:'; then
    ok "watchdog --check prints status"
else
    fail "watchdog --check prints status"
fi
WD_BAD_RC=0
bash "$ROOT/scripts/mt7902-watchdog.sh" --not-a-flag >/dev/null 2>&1 || WD_BAD_RC=$?
assert_eq "watchdog unknown flag exits non-zero" "1" "$WD_BAD_RC"

UNKNOWN_RC=0
UNKNOWN_OUT="$(bash "$ROOT/mt7902.sh" definitely-not-a-command 2>&1)" || UNKNOWN_RC=$?
assert_eq "unknown command exits non-zero" "1" "$UNKNOWN_RC"
if echo "$UNKNOWN_OUT" | grep -qi "Неизвестная\|unknown\|help"; then
    ok "unknown command shows help-like message"
else
    fail "unknown command shows help-like message"
fi
echo ""
