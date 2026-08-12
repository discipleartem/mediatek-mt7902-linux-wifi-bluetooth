#!/bin/bash
# shellcheck shell=bash
# 1) Required files

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
assert_file "archive/mt7921-pci-id/README.md"
assert_file "docs/installation.md"
assert_file "docs/supported-hardware.md"
assert_file "docs/faq.md"
assert_file "docs/ru/installation.md"
assert_file "docs/ru/supported-hardware.md"
assert_file "docs/ru/faq.md"
assert_file "tests/harness.sh"
assert_file "scripts/mt7902-watchdog.sh"
echo ""
