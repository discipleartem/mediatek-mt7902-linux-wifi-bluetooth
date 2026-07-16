#!/usr/bin/env bash
# Set GitHub About description + topics for AI/search discoverability.
# Requires: gh auth login   OR   export GH_TOKEN=...
set -euo pipefail
REPO="${1:-discipleartem/mediatek-mt7902-linux-wifi-bluetooth}"
export PATH="${HOME}/.local/bin:${PATH}"

# Front-load chip ID + modules + the BT error agents/users paste from dmesg.
DESC='Linux fix for MediaTek MT7902 / Filogic 310 (PCI 14c3:7902, AzureWave 1a3b:5524): mt7902e + btusb_mt7902. Fixes unclaimed WiFi and Bluetooth Opcode 0x0c03 failed -110 / zero BD address on Acer Aspire/Extensa.'

TOPICS=(
  mt7902
  mediatek
  filogic-310
  filogic
  wifi
  bluetooth
  linux-driver
  linux
  ubuntu
  linux-mint
  fedora
  acer
  acer-aspire
  mt7902e
  btusb
  dkms
  out-of-tree
  wireless
  networking
)

# Topics that are typos or dilute the primary chip signal — remove if present.
REMOVE_TOPICS=(
  filogic-310-
  mt7921
  mt7961
)

echo "Updating description for $REPO ..."
gh repo edit "$REPO" --description "$DESC"

echo "Removing stale/typo topics (ignore errors) ..."
for t in "${REMOVE_TOPICS[@]}"; do
  gh api -X DELETE "repos/${REPO}/topics/${t}" 2>/dev/null || true
  # older gh: --remove-topic
  gh repo edit "$REPO" --remove-topic "$t" 2>/dev/null || true
done

echo "Updating topics ..."
for t in "${TOPICS[@]}"; do
  gh repo edit "$REPO" --add-topic "$t" 2>/dev/null || true
done

echo "Done. Check: https://github.com/${REPO}"
gh repo view "$REPO" --json description,repositoryTopics -q '{description: .description, topics: [.repositoryTopics[].name]}'
