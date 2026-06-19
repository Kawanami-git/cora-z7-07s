#!/bin/sh

KEY_DIR="/etc/dropbear"

mkdir -p $KEY_DIR

[ -f "$KEY_DIR/dropbear_rsa_host_key" ] || dropbearkey -t rsa -f $KEY_DIR/dropbear_rsa_host_key
[ -f "$KEY_DIR/dropbear_ecdsa_host_key" ] || dropbearkey -t ecdsa -f $KEY_DIR/dropbear_ecdsa_host_key
[ -f "$KEY_DIR/dropbear_ed25519_host_key" ] || dropbearkey -t ed25519 -f $KEY_DIR/dropbear_ed25519_host_key
