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

ROOT_PARTITION_DEVICE=$(findmnt -n --evaluate -o SOURCE --target /)
ROOT_PARTITION_FILESYSTEM=$(findmnt -n --evaluate -o FSTYPE --target /)

case "$ROOT_PARTITION_FILESYSTEM" in
    xfs)
      xfs_growfs /
      ;;
    ext4|ext2)
      resize2fs "$ROOT_PARTITION_DEVICE"
      ;;
  *)
    echo "Warning! Filesystem Resize Skipped due to unknown FSTYPE"
    ;;
esac

exit 0