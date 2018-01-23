#!/usr/bin/env bash
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

echo "Destroying SSH host keys:"
sudo ls /etc/ssh/*_key /etc/ssh/*_key.pub

if hash shred 2>/dev/null; then
  sudo shred -u /etc/ssh/*_key /etc/ssh/*_key.pub
else
  sudo rm -f /etc/ssh/*_key /etc/ssh/*_key.pub
fi

exit 0
