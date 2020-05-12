# gpg-disk-utils
## Setup
```
sudo apt install cryptsetup
```
## Usage
### Create encryption key
```
./createkey.sh <key name>
```
### Create disk
```
./createdisk.sh <disk name> <encryption key id> <recovery key id>
```
### Mount disk
```
./mountdisk.sh <disk name>
```
### Unmount disk
```
./unmountdisk.sh <disk name>
```
### Backup a disk to a portable device
```
./backupdisk.sh <disk name> <device name>
```