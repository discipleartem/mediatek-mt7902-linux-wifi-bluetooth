#!/usr/bin/env bash
# Set GitHub About description + topics for AI/search discoverability.
# Requires: gh auth login   OR   export GH_TOKEN=...
set -euo pipefail
REPO="${1:-discipleartem/mediatek-mt7902-linux-wifi-bluetooth}"
export PATH="${HOME}/.local/bin:${PATH}"

# Front-load chip ID + user search phrases (WiFi not working / Ubuntu).
DESC='MediaTek MT7902 Linux WiFi and Bluetooth driver (PCI 14c3:7902). Fix WiFi not working / Bluetooth missing on Ubuntu 24.04+. mt7902e + btusb_mt7902.'

TOPICS=(
  mt7902
  mediatek
  linux
  wifi
  bluetooth
  ubuntu
  driver
  kernel
  wireless
  pcie
  mtk
  linux-driver
  filogic-310
  mt7902e
  dkms
  fedora
  acer
  acer-aspire
  filogic
)

# Topics that are typos or dilute the primary chip signal — remove if present.
REMOVE_TOPICS=(
  filogic-310-
  mt7921
  mt7961
  out-of-tree
  networking
  linux-mint
  btusb
)

echo "Updating description for $REPO ..."
gh repo edit "$REPO" --description "$DESC"

echo "Removing stale/typo topics (ignore if absent) ..."
for t in "${REMOVE_TOPICS[@]}"; do
  # Only --remove-topic; there is no DELETE /topics/{name} REST endpoint.
  gh repo edit "$REPO" --remove-topic "$t" >/dev/null 2>&1 || true
done

echo "Updating topics ..."
for t in "${TOPICS[@]}"; do
  gh repo edit "$REPO" --add-topic "$t" 2>/dev/null || true
done

echo "Done. Check: https://github.com/${REPO}"
gh repo view "$REPO" --json description,repositoryTopics -q '{description: .description, topics: [.repositoryTopics[].name]}'
