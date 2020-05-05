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

. ./vars.sh

DISK_NAME=$1
MOUNT_POINT=$2
USAGE=<<EOF
Usage: $0 [OPTIONS] disk-name [mount-point] <auto>
EOF

if [ ! -n "$DISK_NAME" ];
then
    echo -e $USAGE
    exit 1
fi

if [ ! -n "$MOUNT_POINT" ];
then
    echo "Warning: No MOUNT_POINT env var set. Using $HOME/mounted-$DISK_NAME"
    MOUNT_POINT="$HOME/mounted-$DISK_NAME"
fi

if [ ! -f "$DISK_HOME/$DISK_NAME.disk" ];
then
    echo "Error: $DISK_NAME could not be found!"
    exit 1
fi
if [ ! -f "$DISK_HOME/$DISK_NAME.key.gpg" ];
then
    echo "Error: Key for $DISK_NAME could not be found!"
    exit 1
fi
if [ -f "$DISK_HOME/$DISK_NAME.mounted" ];
then
    if [ "$3" == "auto" ];
    then
        exit 0
    else
        echo "Error: Disk $DISK_NAME is already mounted!"
        exit 1
    fi
fi
if [ -f "$MOUNT_POINT" ];
then
    echo "Error: $MOUNT_POINT already exists!"
    exit 1
fi

mkdir "$MOUNT_POINT"
LO_MOUNT=`sudo losetup -f`
VG_MOUNT=`date +%s | sha1sum | head -c 8`
sudo losetup $LO_MOUNT "$DISK_HOME/$DISK_NAME.disk"
gpg --batch --yes --trust-model always --decrypt "$DISK_HOME/$DISK_NAME.key.gpg" | sudo cryptsetup luksOpen $LO_MOUNT $VG_MOUNT -d -
sudo mount /dev/mapper/$VG_MOUNT "$MOUNT_POINT"
echo "$LO_MOUNT:$VG_MOUNT:$MOUNT_POINT" >"$DISK_HOME/$DISK_NAME.mounted"
sudo -k
unset PASSPHRASE
exit 0
