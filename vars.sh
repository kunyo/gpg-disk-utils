#!/usr/bin/env bash

# The directory used to store user disks
if [ -z "$DISK_HOME" ]; then
    DISK_HOME=`realpath ~/.gpgdisks`
fi
