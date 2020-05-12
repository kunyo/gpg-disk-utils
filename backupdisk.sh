#!/usr/bin/env bash
set -ex

DISK_NAME=$1
DEVICE_NAME=$2

. ./vars.sh

if [ -z "$DISK_NAME" ] || [ -z "$DEVICE_NAME" ]; then
    >&2 echo "Usage: $0 <disk name> <device name>"
    exit 1
fi

if [ ! -d "/media/$USER/$DEVICE_NAME" ]; then
    >&2 echo "Device not mounted: $DEVICE_NAME"
    exit 1
fi

if [ ! -f "$DISK_HOME/$DISK_NAME.disk" ]; then
    >&2 echo "Disk not found: $DISK_NAME"
    exit 1
fi

if [ ! -d "/media/$USER/$DEVICE_NAME/.gpgdisks" ]; then
    mkdir "/media/$USER/$DEVICE_NAME/.gpgdisks"
fi

rsync --progress $DISK_HOME/$DISK_NAME.* "/media/$USER/$DEVICE_NAME/.gpgdisks"