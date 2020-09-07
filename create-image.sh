#!/bin/bash

function sd () {
    systemd-nspawn -E "DEBIAN_FRONTEND=$DEBIAN_FRONTEND" \
                   -E "DEBCONF_NONINTERACTIVE_SEEN=$DEBCONF_NONINTERACTIVE_SEEN" \
                   -D /mnt \
                   --bind "$_mnt_tmp_dir/boot:/boot" \
                   -- "$@"
}

function sd-apt-get () {
    sd /usr/bin/apt-get -y "$@"
}

function sd-bootctl () {
    "$_mnt_tmp_dir/usr/bin/bootctl" --boot-path="$_mnt_tmp_dir/boot" --esp-path="$_mnt_tmp_dir/boot" "$@"
}

# komma seperated list of additional packages
declare -a _system_pkgs=('apt' 'binutils' 'cloud-init' 'dbus' 'dracut' 'libpam-systemd' 'linux-generic' 'openssh-server' 'open-vm-tools' 'systemd' 'zypper')
declare -x -r DEBIAN_FRONTEND='noninteractive'
declare -x -r DEBCONF_NONINTERACTIVE_SEEN='true'

declare _mnt_tmp_dir
_mnt_tmp_dir="$(mktemp -d)"

echo "* Allocating Image of 5GiB"
fallocate -l 5GiB kiwi-host.img
echo "* Partitioning Image"
sgdisk -n 0:0:+256M -t 0:ef00 -c 0:KIWI_BOOT -n 0:0:0 -t 0:8304 -c KIWI_ROOT kiwi-host.img
echo "* Loop Mounting Image"
_loop_dev="$(sudo losetup --show -f -P kiwi-host.img)"
partprobe -s "$_loop_dev"
echo "* Creating FAT32 on ${_loop_dev}p1"
mkfs.vfat -F32 -n KIWI_BOOT "${_loop_dev}p1" || exit 1
echo "* Creating XFS on ${_loop_dev}p2"
mkfs.xfs -L KIWI_ROOT "${_loop_dev}p2" || exit 1
echo "* Mounting ${_loop_dev}p1 to $_mnt_tmp_dir"
mount "${_loop_dev}p1" "$_mnt_tmp_dir" || exit 1
echo "* Mounting ${_loop_dev}p2 to $_mnt_tmp_dir/boot"
mkdir "$_mnt_tmp_dir/boot"
mount "${_loop_dev}p2" "$_mnt_tmp_dir/boot" || exit 1
echo "* Starting debootstrap into $_mnt_tmp_dir"
debootstrap --variant=minbase \
    --merged-usr \
    --components=main,universe \
    focal "$_mnt_tmp_dir" http://azure.archive.ubuntu.com/ubuntu
echo "* Update and Install Packages into Image"
sd-apt-get -y update
sd-apt-get -y install "${_system_pkgs[@]}"
echo "* Installing boot loader"
sd-bootctl install
umount "$_mnt_tmp_dir/boot" "$_mnt_tmp_dir"
losetup -D
