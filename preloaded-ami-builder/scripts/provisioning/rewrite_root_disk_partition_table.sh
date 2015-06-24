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

# Detect the name of the root device. Xen uses "xvd" as a prefix, KVM sticks to the default "sd"

ROOT_DEVICE=/dev/xvda
if [ -b '/dev/sda' ]; then
    ROOT_DEVICE=/dev/sda
fi

# Detect if the root parition is GPT or MBR (the strategy is different)

if ! (fdisk -l "${ROOT_DEVICE}" 2>/dev/null | grep -q 'GPT'); then

    # MBR partitions can be resized using fdisk or parted by rewriting the partition table

    ROOT_PARTITION="${ROOT_DEVICE}1"
    START_BLOCK=$(echo p | fdisk "${ROOT_DEVICE}" 2>/dev/null | grep "${ROOT_PARTITION}" | awk {'print $2'})
    (echo d; echo n; echo p; echo 1; echo "${START_BLOCK}"; echo; echo w;) | fdisk "${ROOT_DEVICE}" 2>/dev/null

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
