#!/bin/bash
# Safety / regression tests for the MT7902 fix pack.
#
# Goal: catch installer/docs regressions that could harm a user's system
# before anyone runs sudo ./mt7902.sh install-all.
#
#   ./tests/run-tests.sh
#   make test
#   SHELLCHECK_REQUIRED=1 ./tests/run-tests.sh   # CI

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=harness.sh
source "$ROOT/tests/harness.sh"

echo "MT7902 safety tests"
echo "==================="
echo "Purpose: ensure the driver patch/installer will not harm user systems."
echo "Root: $ROOT"
echo ""

# shellcheck source=/dev/null
source "$ROOT/tests/01-files.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/02-syntax.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/03-cli.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/04-modules-contract.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/05-safety-static.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/06-docs.sh"
# shellcheck source=/dev/null
source "$ROOT/tests/07-makefile-docs-ci.sh"

TOTAL=$((PASS + FAIL + SKIP))
echo "==================="
echo -e "Result: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${SKIP} skipped${NC} (of $TOTAL)"
if [[ "$FAIL" -gt 0 ]]; then
    echo "Failing tests mean the pack may be unsafe to install — fix before sudo install-all."
    exit 1
fi
exit 0
