#!/usr/bin/env bash
#
# (c) Copyright 2016 Cloudera, Inc.
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

# Source this script in other provisioning scripts.

if hash systemctl 2>/dev/null; then
  USE_SYSTEMCTL=1
fi

service_control() {
  local service="$1"
  local operation="$2"

  if [[ -n $USE_SYSTEMCTL ]]; then
    case $operation in
      enable)
        sudo systemctl enable "${service}.service"
        ;;
      disable)
        sudo systemctl disable "${service}.service"
        ;;
      start)
        sudo systemctl start "${service}.service"
        ;;
      stop)
        sudo systemctl stop "${service}.service"
        ;;
      *)
        echo "Invalid operation $operation"
        exit 1
        ;;
    esac
  else
    case $operation in
      enable)
        sudo chkconfig "$service" on
        ;;
      disable)
        sudo chkconfig "$service" off
        ;;
      start)
        sudo service "$service" start
        ;;
      stop)
        sudo service "$service" stop
        ;;
      *)
        echo "Invalid operation $operation"
        exit 1
        ;;
    esac
  fi
}
