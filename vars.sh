#!/usr/bin/env bash

# The directory used to store user disks
if [ -z "$DISK_HOME" ]; then
    DISK_HOME=`realpath ~/.gpgdisks`
else
    DISK_HOME=`realpath $DISK_HOME`
fi

# The filename of the gpg keyring
KEYRING_FILENAME='disks.gpg'