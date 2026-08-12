#!/bin/bash
# Shared test helpers for MT7902 safety suite.
# shellcheck shell=bash

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

# Grep installer sources: entrypoint + optional lib/*.sh
installer_sources() {
    local f
    echo "$ROOT/mt7902.sh"
    if [[ -d "$ROOT/lib" ]]; then
        shopt -s nullglob
        for f in "$ROOT"/lib/*.sh; do
            echo "$f"
        done
        shopt -u nullglob
    fi
}

assert_installer_contains() {
    local desc="$1" pattern="$2"
    local f
    while IFS= read -r f; do
        if grep -qE "$pattern" "$f"; then
            ok "$desc"
            return 0
        fi
    done < <(installer_sources)
    fail "$desc (pattern /$pattern/ in mt7902.sh|lib/*.sh)"
}

assert_installer_not_contains() {
    local desc="$1" pattern="$2"
    local f
    while IFS= read -r f; do
        if grep -qE "$pattern" "$f"; then
            fail "$desc (unexpected /$pattern/ in ${f#"$ROOT"/})"
            return 1
        fi
    done < <(installer_sources)
    ok "$desc"
}

all_shell_scripts() {
    local f
    echo "$ROOT/mt7902.sh"
    echo "$ROOT/tests/run-tests.sh"
    echo "$ROOT/tests/harness.sh"
    shopt -s nullglob
    for f in "$ROOT"/tests/[0-9]*.sh "$ROOT"/lib/*.sh "$ROOT"/scripts/*.sh; do
        echo "$f"
    done
    shopt -u nullglob
}
