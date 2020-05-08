#!/usr/bin/env bash
# Copyright (c) 2013, Patrick Uiterwijk <patrick@uiterwijk.org>
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met: 
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer. 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution. 
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

set -ex

if [ $# -ne 4 ]; then
    2>&1 echo "Usage: $0 <disk name> <disk size (mb)> <key id> <recovery key id>"
    exit 1
fi

# Check configuration
DISK_NAME="$1"
DISK_BLOCK_COUNT=`expr $2 \* 1000 \* 1000`
DISK_SIZE_MB=$2
DISK_KEY_ID=$3
DISK_RECOVERY_KEY_ID=$4

if [ ! -n "$DISK_NAME" ]; then
    2>&1 echo "Usage: $0 <disk name> <disk size (mb)> <key id> <recovery key id>"
    exit 1
fi
if [ ! -n "$DISK_KEY_ID" ]; then
    2>&1 echo "Usage: $0 <disk name> <disk size (mb)> <key id> <recovery key id>"
    exit 1
fi
if [ ! -n "$DISK_RECOVERY_KEY_ID" ]; then
    2>&1 echo "Usage: $0 <disk name> <disk size (mb)> <key id> <recovery key id>"
    exit 1
fi

. ./vars.sh

if [ -f "$DISK_HOME/$DISK_NAME.disk" ]; then
    2>&1 echo "Disk already exists!"
    exit 1
fi

# Force creation of DISK_HOME and KEY_HOME directories
test -d "$DISK_HOME" || mkdir -p "$DISK_HOME"
test -d "$KEY_HOME" || mkdir -p "$KEY_HOME" && chmod 700 "$KEY_HOME"

# Create the key
# First try to retrieve the DISK_RECOVERY_KEY_ID
#gpg --no-default-keyring --secret-keyring "$KEY_HOME/secret.gpg" --keyring "$KEY_HOME/public.gpg" --trustdb-name "$KEY_HOME/trustdb.gpg" --keyserver hkp://pgp.surfnet.nl:80 --recv-keys $DISK_RECOVERY_KEY_ID
head -c66 /dev/random | openssl base64 -A  | gpg --trust-model always --armor --encrypt -r $DISK_KEY_ID -r $DISK_RECOVERY_KEY_ID >"$DISK_HOME/$DISK_NAME.key.gpg"
LO_MOUNT=`sudo losetup -f`
VG_MOUNT=`date +%s | sha1sum | head -c 8`
TMP_MOUNT=`mktemp -d`
#dd if=/dev/zero of="$DISK_HOME/$DISK_NAME.disk" bs=1024 count=$DISK_BLOCK_COUNT
fallocate -l "${DISK_SIZE_MB}M" "$DISK_HOME/$DISK_NAME.disk"
sudo losetup -f "$DISK_HOME/$DISK_NAME.disk"
sudo losetup $LO_MOUNT
gpg --use-agent --trust-model always --decrypt "$DISK_HOME/$DISK_NAME.key.gpg" | sudo cryptsetup luksFormat $LO_MOUNT - 
gpg --use-agent --trust-model always --decrypt "$DISK_HOME/$DISK_NAME.key.gpg" | sudo cryptsetup luksOpen $LO_MOUNT $VG_MOUNT -d -
gnome-keyring-daemon --replace
sudo mkfs.ext4 /dev/mapper/$VG_MOUNT
# Now set current user as owner
sudo mount /dev/mapper/$VG_MOUNT "$TMP_MOUNT"
sudo chown -R $USERNAME:$USERNAME "$TMP_MOUNT"
# And close everything
sudo umount "$TMP_MOUNT"
rmdir "$TMP_MOUNT"
sudo cryptsetup luksClose $VG_MOUNT
sudo losetup --detach $LO_MOUNT
sudo -k
exit 0