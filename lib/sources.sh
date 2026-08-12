#!/bin/bash
# shellcheck shell=bash

ensure_wifi_sources() {
    if [[ ! -d "$WIFI_DIR/.git" && ! -f "$WIFI_DIR/Makefile" ]]; then
        print_step "Клонирование Wi‑Fi драйвера ($WIFI_BRANCH)"
        git clone --depth 1 -b "$WIFI_BRANCH" "$WIFI_REPO" "$WIFI_DIR"
    fi
}

ensure_bt_sources() {
    if [[ ! -d "$BT_DIR/.git" && ! -f "$BT_DIR/Makefile" ]]; then
        print_step "Клонирование Bluetooth драйвера ($BT_BRANCH)"
        git clone --depth 1 -b "$BT_BRANCH" "$WIFI_REPO" "$BT_DIR"
    fi
}
