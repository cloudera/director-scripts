#!/bin/sh
#
# (c) Copyright 2015 Cloudera, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Generic script for resizing the root disk partition for a cloud virtual machine

set -o pipefail
set -x

# Just use resize2fs if this is a paravirtual VM and exit.
if [ "$VIRTUALIZATION_TYPE" = "pv" ]; then
    resize2fs $(sudo mount | grep "on / type" | awk '{ print $1 }')
    exit 0
fi

# Display the current size of all the available block devices

lsblk
df -h

# Detect the name of the root device. Xen is "/dev/xvda", KVM and VMWare is "/dev/sda",
# OpenStack is "/dev/vda"

ROOT_PARTITION_DEVICE=$(findmnt -n --evaluate -o SOURCE --target /)
ROOT_DEVICE=$(echo $ROOT_PARTITION_DEVICE | sed -e "s/[0-9]*$//")

# If the root partition is already using 95% or more of the root device skip the resize operation

ROOT_DEVICE_SIZE=$(blockdev --getsize64 ${ROOT_DEVICE})
ROOT_PARTITION_SIZE=$(blockdev --getsize64 ${ROOT_PARTITION_DEVICE})

USAGE_PERCENTAGE=$((${ROOT_PARTITION_SIZE} * 100 / ${ROOT_DEVICE_SIZE}))

if [ "${USAGE_PERCENTAGE}" -gt "95" ]; then
    echo "No resize needed. The root disk partition already has the desired size"
    # http://www.tldp.org/LDP/abs/html/exitcodes.html
    exit 0
fi

# Detect if the root partition is GPT or MBR (the strategy is different)

if ! (fdisk -l "${ROOT_DEVICE}" 2>/dev/null | grep -q -i 'GPT'); then

    # MBR partitions can be resized using fdisk or parted by rewriting the partition table

    # fdisk automatically selects the first partition if there is only one, so form
    # commands for fdisk depending on that
    NUM_PARTITIONS=$(fdisk -l "${ROOT_DEVICE}" | grep -c "${ROOT_DEVICE}[0-9]")

    ROOT_PARTITION="${ROOT_DEVICE}1"
    PARTITION_INFO=$(echo p | fdisk -l "${ROOT_DEVICE}" | grep "${ROOT_PARTITION}")
    if [ "$NUM_PARTITIONS" -gt 1 ]; then
       TOGGLE_BOOTABLE_IF_NEEDED=$(echo "$PARTITION_INFO" | grep -q '*' && echo "echo a; echo 1")
    else
       TOGGLE_BOOTABLE_IF_NEEDED=$(echo "$PARTITION_INFO" | grep -q '*' && echo "echo a")
    fi
    START_BLOCK=$(echo $PARTITION_INFO | awk '{if (NF == 7){print $3} else {print $2}}')
    START_SECTOR=$( (echo x; echo p) | fdisk "${ROOT_DEVICE}" 2>/dev/null | grep -e "^ 1" | awk '{print $9}')
    if [ "$NUM_PARTITIONS" -gt 1 ]; then
       CHANGE_START_SECTOR="echo x; echo b; echo 1; echo $START_SECTOR"
    else
       CHANGE_START_SECTOR="echo x; echo b; echo $START_SECTOR"
    fi
    (echo d; echo n; echo p; echo 1; echo "${START_BLOCK}"; echo; sh -c "${TOGGLE_BOOTABLE_IF_NEEDED}"; sh -c "$CHANGE_START_SECTOR"; echo w;) | fdisk "${ROOT_DEVICE}" 2>/dev/null

    # To complete the process resize2fs needs to be called after reboot (if there is no cloud-init)

    if ! hash cloud-init; then
        echo "resize2fs \"${ROOT_PARTITION}\"" >> /etc/rc.local
    fi

else

    # GPT partitions require gdisk for resizing.

    # Get first non-BIOS boot (filesystem EF02) partition
    PARTITION_INFO=$(sgdisk -p ${ROOT_DEVICE} | grep "^\\s*[[:digit:]]" | grep -vi EF02 | head -n 1)

    # Get partition number, starting sector, and filesystem of the first non-BIOS boot partition
    PARTITION_NUMBER=$(echo ${PARTITION_INFO} | cut -d' ' -f 1)
    STARTING_SECTOR=$(echo ${PARTITION_INFO} | cut -d' ' -f 2)
    FILESYSTEM=$(echo ${PARTITION_INFO} | cut -d' ' -f 6)

    PARTITION_GUID_INFO=$(sgdisk -i ${PARTITION_NUMBER} ${ROOT_DEVICE} | grep "unique GUID")
    PARTITION_GUID=$(echo ${PARTITION_GUID_INFO##*:})
    PARTITION_NAME_INFO=$(sgdisk -i ${PARTITION_NUMBER} ${ROOT_DEVICE} | grep "Partition name")
    PARTITION_NAME=$(echo ${PARTITION_NAME_INFO##*:} | sed -e "s/^'//" -e "s/'$//" -e "s/\"/\\\"/g"  -e "s/\"/\\\\\"/g")

    sgdisk -e -d ${PARTITION_NUMBER} -n ${PARTITION_NUMBER}:${STARTING_SECTOR}:0 \
           -c ${PARTITION_NUMBER}:"${PARTITION_NAME}" -u ${PARTITION_NUMBER}:${PARTITION_GUID} \
           -t ${PARTITION_NUMBER}:${FILESYSTEM} ${ROOT_DEVICE}

fi

exit 0
