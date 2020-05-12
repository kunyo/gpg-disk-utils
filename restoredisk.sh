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

if [ ! -f "/media/$USER/$DEVICE_NAME/.gpgdisks/$DISK_NAME.disk" ]; then
    >&2 echo "Disk not found: $DISK_NAME"
    exit 1
fi

if [ ! -f "/media/$USER/$DEVICE_NAME/.gpgdisks/$DISK_NAME.key.gpg" ]; then
    >&2 echo "Disk key not found: $DISK_NAME"
    exit 1
fi

if [ -f "$DISK_HOME/$DISK_NAME.disk" ] || [ -f "$DISK_HOME/$DISK_NAME.key.gpg" ]; then
    >&2 echo "Disk already exists: $DISK_NAME"
    exit 1
fi

if [ ! -d "$DISK_HOME" ]; then
    mkdir -p "$DISK_HOME"
    chmod 700 "$DISK_HOME"
fi


rsync --progress /media/$USER/$DEVICE_NAME/.gpgdisks/$DISK_NAME.* "$DISK_HOME"
chmod 600 $DISK_HOME/$DISK_NAME.*