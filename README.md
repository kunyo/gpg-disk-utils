# gpg-disk-utils
## Setup
```
sudo apt install cryptsetup
```
## Usage
### Create encryption key
```
./gpgdisk.sh newkey <key name>
```
### Create disk
```
./gpgdisk.sh newdisk <disk name> <encryption key id> <recovery key id>
```
### Mount disk
```
./gpgdisk.sh mount <disk name>
```
### Unmount disk
```
./gpgdisk.sh unmount <disk name>
```
### Backup a disk to a portable device
```
./gpgdisk.sh backup <disk name> <device name>
```
### Sync disk content with a disk stored on a portable device
```
./gpgdisk.sh sync <disk name> <device name>
```