#!/bin/bash

function sd () {
    systemd-nspawn -D /mnt -- "$@"
}

function sd-apt-get () {
    sd /usr/bin/apt-get -y "$@"
}

function sd-bootctl () {
    sd /usr/bin/bootctl "$@"
}

# komma seperated list of additional packages
declare -a _system_pkgs=('binutils' 'cloud-init' 'dbus' 'dracut' 'libpam-systemd' 'linux-generic' 'openssh-server' 'open-vm-tools' 'systemd')

fallocate -l 5GiB kiwi-host.img
sgdisk -n 0:0:+256M -t 0:ef00 -c 0:KIWI_BOOT -n 0:0:0 -t 0:8304 -c KIWI_ROOT kiwi-host.img
_loop_dev="$(sudo losetup --show -f -P kiwi-host.img)"
partprobe -s "$_loop_dev"
mkfs.vfat -F32 -n KIWI_BOOT "${_loop_dev}p1"
mkfs.xfs -L KIWI_ROOT "${_loop_dev}p2"
mount "${_loop_dev}p1" /mnt
mkdir /mnt/boot
mount -o rw,exec,dev,suid "${_loop_dev}p2" /mnt/boot
debootstrap --variant=minbase \
    --merged-usr \
    --components=main,universe \
    focal /mnt http://azure.archive.ubuntu.com/ubuntu
sd-apt-get -y update
sd-apt-get -y install "${_system_pkgs[@]}"
sd-bootctl install
umount /mnt/boot /mnt
losetup -D
