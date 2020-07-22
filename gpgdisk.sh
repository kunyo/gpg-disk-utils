#!/usr/bin/env bash
set -ex

# The directory used to store user disks
if [ -z "$DISK_HOME" ]; then
    DISK_HOME="`realpath ~`/.gpgdisks"
fi

usage(){
    USAGE=$(cat <<EOF
Usage: $0 [OPTIONS...] <action>

Available actions
-------------------
backup
newkey
newdisk
mount
unmount
sync
EOF
)
    >&2 echo -e "$USAGE"
    exit 1
}

new_gpg_key(){
    KEY_LENGTH=4096
    OWNER_NAME=$1
    if [ ! -n "$OWNER_NAME" ];
    then
        echo "Usage: $0 <owner name>"
        exit 1
    fi    
    KEY_REQUEST=$(cat <<EOF
%echo Generating\n
%ask-passphrase\n
Key-Type: RSA\n
Key-Length: $KEY_LENGTH\n
Name-Real: $OWNER_NAME disk encryption\n
Expire-Date: 0\n
%commit\n
%echo Done\n
EOF
)
    # And generate
    echo -e $KEY_REQUEST | gpg --trust-model always --batch --gen-key
}

mount_gpg_disk(){
    FORCE=0
    USAGE="Usage: $0 mount [OPTIONS] disk-name [mount-point] <auto>"

    for i in "$@"
    do
    case $i in
        --force)
        FORCE=1
        shift # past argument with no value
        ;;
        *)
            # unknown option
        ;;
    esac
    done
    
    DISK_NAME=$1
    MOUNT_POINT=$2

    if [ ! -n "$DISK_NAME" ];
    then
        echo -e $USAGE
        exit 1
    fi

    if [ ! -n "$MOUNT_POINT" ];
    then
        MOUNT_POINT="$HOME/mounted-$DISK_NAME"
        echo "Warning: No MOUNT_POINT env var set. Using $MOUNT_POINT"
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
        echo "Error: Disk $DISK_NAME is already mounted!"
        if [ $FORCE -eq 0 ];
        then
            exit 1    
        else
            echo "Removing disk.mounted file: $DISK_HOME/$DISK_NAME.mounted"
            rm "$DISK_HOME/$DISK_NAME.mounted"
        fi
    fi
    if [ -f "$MOUNT_POINT" ];
    then
        echo "Error: $MOUNT_POINT already exists!"
        if [ $FORCE -eq 0 ];
        then
            exit 1    
        else
            echo "Removing mount point: $MOUNT_POINT"
            rm -rf "$MOUNT_POINT"
        fi
    fi

    mkdir "$MOUNT_POINT"
    LO_MOUNT=`sudo losetup -f`
    VG_MOUNT=`date +%s | sha1sum | head -c 8`
    sudo losetup $LO_MOUNT "$DISK_HOME/$DISK_NAME.disk"
    gpg --batch --yes --trust-model always --decrypt "$DISK_HOME/$DISK_NAME.key.gpg" | sudo cryptsetup luksOpen $LO_MOUNT $VG_MOUNT -d -
    sudo mount /dev/mapper/$VG_MOUNT "$MOUNT_POINT"
    sudo chown `id -u`:`id -g` "$MOUNT_POINT"
    sudo chmod 700 "$MOUNT_POINT"
    echo "$LO_MOUNT:$VG_MOUNT:$MOUNT_POINT" >"$DISK_HOME/$DISK_NAME.mounted"
}

unmount_gpg_disk(){
    DISK_NAME=$1
    if [ ! -n "$DISK_NAME" ];
    then
        echo "Usage: $0 unmount disk-name"
        exit 1
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
}

sync_gpg_disk(){
    DISK_NAME=$1
    DEVICE_NAME=$2

    if [ -z "$DISK_NAME" ] || [ -z "$DEVICE_NAME" ]; then
        >&2 echo "Usage: $0 sync <disk name> <device name>"
        exit 1
    fi

    if [ ! -d "/media/$USER/$DEVICE_NAME" ]; then
        >&2 echo "Device not mounted: $DEVICE_NAME"
        exit 1
    fi

    if [ ! -f "/media/$USER/$DEVICE_NAME/.gpgdisks/$DISK_NAME.disk" ]; then
        >&2 echo "Target disk not found: $DISK_NAME; device name: $DEVICE_NAME"
        exit 1
    fi

    if [ -f "/media/$USER/$DEVICE_NAME/.gpgdisks/$DISK_NAME.mounted" ]; then
        >&2 echo "Target disk already mounted: $DISK_NAME"
        exit 1
    fi

    if [ ! -f "$DISK_HOME/$DISK_NAME.disk" ]; then
        >&2 echo "Source disk not found: $DISK_NAME"
        exit 1
    fi

    if [  -f "$DISK_HOME/$DISK_NAME.mounted" ]; then
        >&2 echo "Source disk already mounted: $DISK_NAME"
        exit 1
    fi

    SRC_MOUNT_POINT=~/.sync-$DISK_NAME-src-`head -c 48 /dev/urandom | sha1sum | head -c 10`
    DST_MOUNT_POINT=~/.sync-$DISK_NAME-dst-`head -c 48 /dev/urandom | sha1sum | head -c 10`
    mount_gpg_disk $DISK_NAME $SRC_MOUNT_POINT
    DISK_HOME=/media/$USER/$DEVICE_NAME/.gpgdisks mount_gpg_disk $DISK_NAME $DST_MOUNT_POINT
    ls -la $SRC_MOUNT_POINT
    ls -la $DST_MOUNT_POINT
    sudo rsync -avh --delete --exclude 'lost+found' $SRC_MOUNT_POINT/ $DST_MOUNT_POINT
    unmount_gpg_disk $DISK_NAME $SRC_MOUNT_POINT
    DISK_HOME=/media/$USER/$DEVICE_NAME/.gpgdisks unmount_gpg_disk $DISK_NAME $DST_MOUNT_POINT
    rm -rf $SRC_MOUNT_POINT
    rm -rf $DST_MOUNT_POINT
    exit 0
}

backup_gpg_disk(){
    DISK_NAME=$1
    DEVICE_NAME=$2

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
}

restore_gpg_disk(){
    DISK_NAME=$1
    DEVICE_NAME=$2

    if [ -z "$DISK_NAME" ] || [ -z "$DEVICE_NAME" ]; then
        >&2 echo "Usage: $0 restore <disk name> <device name>"
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
}

new_gpg_disk(){
    if [ $# -ne 4 ]; then
        2>&1 echo "Usage: $0 <disk name> <disk size (mb)> <key id> <recovery key id>"
        exit 1
    fi

    # Check configuration
    DISK_NAME="$1"
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

    if [ -f "$DISK_HOME/$DISK_NAME.disk" ]; then
        2>&1 echo "Disk already exists!"
        exit 1
    fi

    # Force creation of DISK_HOME and KEY_HOME directories
    test -d "$DISK_HOME" || mkdir -p "$DISK_HOME"

    # Create the key
    # First try to retrieve the DISK_RECOVERY_KEY_ID
    #gpg --no-default-keyring --secret-keyring "$KEY_HOME/secret.gpg" --keyring "$KEY_HOME/public.gpg" --trustdb-name "$KEY_HOME/trustdb.gpg" --keyserver hkp://pgp.surfnet.nl:80 --recv-keys $DISK_RECOVERY_KEY_ID
    head -c66 /dev/random | openssl base64 -A  | gpg --trust-model always --armor --encrypt -r $DISK_KEY_ID -r $DISK_RECOVERY_KEY_ID >"$DISK_HOME/$DISK_NAME.key.gpg"
    chmod 600 "$DISK_HOME/$DISK_NAME.key.gpg"
    LO_MOUNT=`sudo losetup -f`
    VG_MOUNT=`date +%s | sha1sum | head -c 8`
    TMP_MOUNT=`mktemp -d`
    #dd if=/dev/zero of="$DISK_HOME/$DISK_NAME.disk" bs=1M count=$DISK_SIZE_MB
    fallocate -l "${DISK_SIZE_MB}M" "$DISK_HOME/$DISK_NAME.disk"
    chmod 600 "$DISK_HOME/$DISK_NAME.disk"
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
}

for i in "$@"
do
case $i in
    -e=*|--extension=*)
    EXTENSION="${i#*=}"
    shift # past argument=value
    ;;
    --default)
    DEFAULT=YES
    shift # past argument with no value
    ;;
esac
done

if [ $# -eq 0 ]; then
    usage
fi
GPGDISKACTION=$1
shift
case $GPGDISKACTION in
    backup)
    backup_gpg_disk $@
    ;;
    restore)
    restore_gpg_disk $@
    ;;    
    newdisk)
    new_gpg_disk $@
    ;;
    newkey)
    new_gpg_key $@    
    ;;    
    mount)
    mount_gpg_disk $@
    sudo -k
    gpgconf --kill gpg-agent
    ;;
    unmount)
    unmount_gpg_disk $@
    sudo -k    
    gpgconf --kill gpg-agent
    ;;
    sync)
    sync_gpg_disk $@
    sudo -k
    gpgconf --kill gpg-agent
    ;;
esac
