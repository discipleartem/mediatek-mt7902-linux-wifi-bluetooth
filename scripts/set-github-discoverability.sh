#!/usr/bin/env bash
# Set GitHub About description + topics for AI/search discoverability.
# Requires: gh auth login   OR   export GH_TOKEN=...
set -euo pipefail
REPO="${1:-discipleartem/FIX-MediaTek-MT7902-MT7921-MT7961-WIFI}"
export PATH="${HOME}/.local/bin:${PATH}"

DESC='Linux fix for MediaTek MT7902 (14c3:7902) WiFi + Bluetooth: mt7902e, btusb_mt7902, Acer Aspire/Extensa. Fixes unclaimed WiFi and Opcode 0x0c03 failed -110.'

TOPICS=(
  mt7902
  mediatek
  wifi
  bluetooth
  linux-driver
  acer
  acer-aspire
  filogic
  mt7902e
  btusb
  ubuntu
  dkms
  out-of-tree
  networking
  wireless
)

echo "Updating description for $REPO ..."
gh repo edit "$REPO" --description "$DESC"

echo "Updating topics ..."
# gh repo edit --add-topic one at a time (API limit friendly)
for t in "${TOPICS[@]}"; do
  gh repo edit "$REPO" --add-topic "$t" 2>/dev/null || true
done

echo "Done. Check: https://github.com/${REPO}"
gh repo view "$REPO" --json description,repositoryTopics -q '{description: .description, topics: [.repositoryTopics[].name]}'
