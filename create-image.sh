#!/bin/bash

declare sd () {
    systemd-nspawn -D /mnt -- "$@"
}

declare sd-apt-get () {
    sd /usr/bin/apt-get -y "$@"
}

declare sd-bootctl () {
    sd /usr/bin/bootctl "$@"
}

fallocate -l 5GiB kiwi-host.img
sgdisk -n 0:0:+512M -t 0:ef00 -c 0:KIWI_BOOT -n 0:0:0 -t 0:8304 -c KIWI_ROOT kiwi-host.img
_loop_dev="$(sudo losetup --show -f -P kiwi-host.img)"
partprobe -s "$_loop_dev"
until test -e /dev/disk/by-partlabel/KIWI_BOOT; do
    sleep 0.2
done
mkfs.vfat -F32 -n KIWI_BOOT /dev/disk/by-partlabel/KIWI_BOOT
until test -e /dev/disk/by-partlabel/KIWI_ROOT; do
    sleep 0.2
done
mkfs.xfs -L KIWI_ROOT /dev/disk/by-partlabel/KIWI_ROOT
mount LABEL=KIWI_ROOT /mnt
mkdir /mnt/boot
mount LABEL=KIWI_BOOT /mnt/boot
cdebootstrap -f minimal focal /mnt
sd-apt-get -y update
sd-apt-get -y install dracut dracut-config-generic linux-image-generic
sd-apt-get -y install cloud-init openssh-server open-vm-tools
sd-bootctl install
umount /mnt/boot /mnt
losetup -D
