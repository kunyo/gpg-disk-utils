# gpg-disk-utils
## Setup
```
sudo apt install cryptsetup
```
## Usage
### Create encryption key
```
./createkey.sh disk-encryption-key
```
### Create encryption key
```
./createkey.sh disk-recovery-key
```
### Create disk
```
DISK_HOME=./disks KEY_HOME=./keyrings ./createdisk.sh <disk name> <encryption key id> <recovery key id>
```
### Mount disk
```
DISK_HOME=./disks KEY_HOME=./keyrings ./mountdisk.sh <disk name>
```
### Unmount disk
```
DISK_HOME=./disks ./unmountdisk.sh <disk name>
```
