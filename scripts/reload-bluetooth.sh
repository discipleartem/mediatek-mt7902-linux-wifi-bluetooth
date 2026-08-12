#!/bin/bash
# Reset MT7902 Bluetooth (btusb_mt7902) and scan.
# Acer Aspire: USB BT is usually 13d3:3594 on bus path like 3-10.
set -e
WIFI_OFF=0
if [[ "${1:-}" == "--wifi-off" ]]; then WIFI_OFF=1; fi

pkill -f gnome-control-center 2>/dev/null || true
systemctl stop bluetooth || true
rfkill block bluetooth || true
sleep 1

modprobe -r rfcomm 2>/dev/null || true
modprobe -r bnep 2>/dev/null || true
modprobe -r btusb_mt7902 2>/dev/null || true
modprobe -r btusb 2>/dev/null || true
modprobe -r btmtk 2>/dev/null || true
sleep 1

# USB hard reset of MediaTek Wireless_Device
for d in /sys/bus/usb/devices/*; do
  [ -f "$d/idVendor" ] || continue
  if [ "$(cat "$d/idVendor")" = "13d3" ] && [ "$(cat "$d/idProduct" 2>/dev/null)" = "3594" ]; then
    echo "USB reset $(basename "$d")"
    echo 0 > "$d/authorized" 2>/dev/null || true
    sleep 1
    echo 1 > "$d/authorized" 2>/dev/null || true
    sleep 1
  fi
done

modprobe btusb_mt7902
rfkill unblock bluetooth
sleep 2
systemctl start bluetooth
sleep 2
bluetoothctl power on
bluetoothctl pairable on
bluetoothctl discoverable on

if [[ "$WIFI_OFF" -eq 1 ]]; then
  echo "Wi‑Fi off for coexistence test..."
  nmcli radio wifi off || true
fi

echo "=== scan 30s — earbuds in PAIRING now ==="
timeout 30 bluetoothctl scan on || true
echo "=== devices ==="
bluetoothctl devices

if [[ "$WIFI_OFF" -eq 1 ]]; then
  nmcli radio wifi on || true
  echo "Wi‑Fi back on"
fi

# Hint if empty
if ! bluetoothctl devices | grep -q .; then
  echo
  echo "VERDICT: controller UP but inquiry empty."
  echo "Check journal: Failed to set mode (0x03) / MSFT (-56) = HCI scan broken."
  echo "Next: USB Bluetooth dongle, or forget HOCO on phone and retry pairing mode."
fi
