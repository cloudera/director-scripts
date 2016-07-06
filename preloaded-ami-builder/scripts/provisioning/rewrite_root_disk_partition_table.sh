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
if [ "$VIRTUALIZATION_TYPE" = "paravirtual" ]; then
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

# Detect if the root parition is GPT or MBR (the strategy is different)

if ! (fdisk -l "${ROOT_DEVICE}" 2>/dev/null | grep -q -i 'GPT'); then

    # MBR partitions can be resized using fdisk or parted by rewriting the partition table

    ROOT_PARTITION="${ROOT_DEVICE}1"
    PARTITION_INFO=$(echo p | fdisk -l "${ROOT_DEVICE}" | grep "${ROOT_PARTITION}")
    TOGGLE_BOOTABLE_IF_NEEDED=$(echo $PARTITION_INFO | grep -q '*' && echo "echo a; echo 1")
    START_BLOCK=$(echo $PARTITION_INFO | awk '{if (NF == 7){print $3} else {print $2}}')
    START_SECTOR=$( (echo x; echo p) | fdisk "${ROOT_DEVICE}" 2>/dev/null | grep -e "^ 1" | awk '{print $9}')
    CHANGE_START_SECTOR="echo x; echo b; echo 1; echo $START_SECTOR"
    (echo d; echo n; echo p; echo 1; echo "${START_BLOCK}"; echo; sh -c "${TOGGLE_BOOTABLE_IF_NEEDED}"; sh -c "$CHANGE_START_SECTOR"; echo w;) | fdisk "${ROOT_DEVICE}" 2>/dev/null

    # To complete the process resize2fs needs to be called after reboot (if there is no cloud-init)

    if ! hash cloud-init; then
        echo "resize2fs \"${ROOT_PARTITION}\"" >> /etc/rc.local
    fi

else

    # GPT partitions require gdisk for resizing as documented here:
    # http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/storage_expand_partition.html#part-resize-gdisk

    PARTITION_GUID=$(echo p | gdisk "${ROOT_DEVICE}" | grep GUID | awk '{ print $4 }')
    (echo o; echo Y; echo n; echo 1; echo 2048; echo ''; echo 'EF00'; \
     echo c; echo ''; echo x; echo g; echo "${PARTITION_GUID}"; echo w; echo Y) | gdisk "${ROOT_DEVICE}"

fi

exit 0
