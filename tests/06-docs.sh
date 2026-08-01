#!/bin/bash
# shellcheck shell=bash
# 6) Docs side effects

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
