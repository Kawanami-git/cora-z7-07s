#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       program_linux.sh
# \brief      Flash a Linux image to a removable device (SD/USB) safely.
# \author     Kawanami
# \version    1.0
# \date       18/06/2025
#
# \details
#   Interactively lists removable devices, prompts for a target (e.g., sdb),
#   confirms the destructive operation, then writes the provided image with `dd`
#   using sane defaults (`bs=4M`, `status=progress`, `conv=fsync`).
#
# \remarks
#   - Requires sufficient privileges to write to block devices (may prompt via sudo).
#   - Double-check the selected device to avoid data loss.
#
# \section program_linux_sh_version_history Version history
# | Version | Date       | Author     | Description      |
# |:-------:|:----------:|:-----------|:-----------------|
# | 1.0     | 18/06/2025 | Kawanami   | Initial version. |
# ********************************************************************************
# */

# Check if image file is provided
if [ -z "$1" ]; then
  echo "Usage: $0 path/to/image.img"
  exit 1
fi

IMAGE="$1"

if [ ! -f "$IMAGE" ]; then
  echo "Error: The image '$IMAGE' does not exist."
  exit 1
fi

echo "Detecting removable devices..."
echo "------------------------------"

# List removable devices
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,TRAN,RM | grep -E 'usb|mmc|1$' | grep -v "loop"

echo
read -p "Enter the device name to flash (e.g., sdb): " DEVICE

if [ ! -b "/dev/$DEVICE" ]; then
  echo "Error: /dev/$DEVICE does not exist."
  exit 1
fi

echo
echo "⚠️  WARNING: All data on /dev/$DEVICE will be lost!"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
  echo "Operation cancelled."
  exit 0
fi

echo
echo "🔄 Flashing $IMAGE to /dev/$DEVICE ..."
sudo dd if="$IMAGE" of="/dev/$DEVICE" bs=4M status=progress conv=fsync

echo
echo "✅ Flash completed. You can now safely eject /dev/$DEVICE."
