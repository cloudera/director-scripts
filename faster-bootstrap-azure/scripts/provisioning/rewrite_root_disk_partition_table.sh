#!/bin/sh
#
# (c) Copyright 2018 Cloudera, Inc.
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

# Display the current size of all the available block devices

lsblk
df -h

# Detect the name of the root device. Xen is "/dev/xvda", KVM and VMWare is "/dev/sda",
# OpenStack is "/dev/vda"

ROOT_PARTITION_DEVICE=$(findmnt -n --evaluate -o SOURCE --target /)
ROOT_DEVICE=$(echo $ROOT_PARTITION_DEVICE | sed -e "s/[0-9]*$//")
PARTITION_NUMBER="${ROOT_PARTITION_DEVICE: -1: 1}"

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

    PARTITION_INFO=$(echo p | fdisk -l "${ROOT_DEVICE}" | grep "${ROOT_PARTITION_DEVICE}")
    TOGGLE_BOOTABLE_IF_NEEDED=$(echo "$PARTITION_INFO" | grep -q '*' && echo "echo a; echo ${PARTITION_NUMBER}")
    START_BLOCK=$(echo $PARTITION_INFO | awk '{if (NF == 7){print $3} else {print $2}}')
    (echo p; echo d; echo "${PARTITION_NUMBER}"; echo n; echo p; echo "${PARTITION_NUMBER}"; echo "${START_BLOCK}"; echo; sh -c "${TOGGLE_BOOTABLE_IF_NEEDED}"; echo p; echo w;) | fdisk "${ROOT_DEVICE}" 2>/dev/null
else

    # GPT partitions require gdisk for resizing.

    # Get first non-BIOS boot (filesystem EF02) partition
    PARTITION_INFO=$(sgdisk -p ${ROOT_DEVICE} | grep "^\\s*${PARTITION_NUMBER}")

    # Get partition number, starting sector, and filesystem of the first non-BIOS boot partition
    STARTING_SECTOR=$(echo ${PARTITION_INFO} | cut -d' ' -f 2)
    FILESYSTEM=$(echo ${PARTITION_INFO} | cut -d' ' -f 6)

    PARTITION_GUID_INFO=$(sgdisk -i ${PARTITION_NUMBER} ${ROOT_DEVICE} | grep "unique GUID")
    PARTITION_GUID=$(echo ${PARTITION_GUID_INFO##*:})
    PARTITION_NAME_INFO=$(sgdisk -i ${PARTITION_NUMBER} ${ROOT_DEVICE} | grep "Partition name")
    PARTITION_NAME=$(echo ${PARTITION_NAME_INFO##*:} | sed -e "s/^'//" -e "s/'$//" -e "s/\"/\\\"/g"  -e "s/\"/\\\\\"/g")

    sgdisk -d ${PARTITION_NUMBER} -n ${PARTITION_NUMBER}:${STARTING_SECTOR}:0 \
           -c ${PARTITION_NUMBER}:"${PARTITION_NAME}" -u ${PARTITION_NUMBER}:${PARTITION_GUID} \
           -t ${PARTITION_NUMBER}:${FILESYSTEM} ${ROOT_DEVICE}

fi

exit 0
