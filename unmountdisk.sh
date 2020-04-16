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

# Configuration
DISK_NAME=$1
if [ ! -n "$DISK_NAME" ];
then
    echo "Usage: $0 disk-name"
    exit 1
fi

set -ex

. ./vars.sh

if [ -z "$DISK_HOME" ]; then
    DISK_HOME=`dirname $0`"/disks"
else
    DISK_HOME=`realpath $DISK_HOME`
fi

# Get disk info
if [ ! -f "$DISK_HOME/$DISK_NAME.mounted" ];
then
    echo "Disk $DISK_NAME was not mounted!"
    exit -1
fi

MOUNT_INFO="`cat "$DISK_HOME/$DISK_NAME.mounted"`"
LO_MOUNT="`echo $MOUNT_INFO | awk -F":" '{print $1}'`"
VG_MOUNT="`echo $MOUNT_INFO | awk -F":" '{print $2}'`"
MOUNT_POINT="`echo $MOUNT_INFO | awk -F":" '{print $3}'`"
sudo umount "$MOUNT_POINT"
sudo cryptsetup luksClose /dev/mapper/$VG_MOUNT
sudo losetup --detach $LO_MOUNT
rm -f "$DISK_HOME/$DISK_NAME.mounted"
rmdir "$MOUNT_POINT"
sudo -k
exit 0
