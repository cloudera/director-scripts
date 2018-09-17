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

declare -A BASE_IMAGES=(
  ["centos67"]="cloudera:cloudera-centos-os:6_7:latest"
  ["centos68"]="cloudera:cloudera-centos-os:6_8:latest"
  ["centos72"]="cloudera:cloudera-centos-os:7_2:latest"
  ["centos74"]="cloudera:cloudera-centos-os:7_4:latest"
  ["rhel67"]="RedHat:RHEL:6.7:latest"
  ["rhel68"]="RedHat:RHEL:6.8:latest"
  ["rhel69"]="RedHat:RHEL:6.9:latest"
  ["rhel610"]="RedHat:RHEL:6.10:latest"
  ["rhel72"]="RedHat:RHEL:7.2:latest"
  ["rhel73"]="RedHat:RHEL:7.3:latest"
  ["rhel74"]="RedHat:RHEL:7.4:latest"
  ["rhel75"]="RedHat:RHEL:7.5:latest"
)
declare -A BASE_PLANS=(
  ["centos67"]="cloudera:cloudera-centos-os:6_7"
  ["centos68"]="cloudera:cloudera-centos-os:6_8"
  ["centos72"]="cloudera:cloudera-centos-os:7_2"
  ["centos74"]="cloudera:cloudera-centos-os:7_4"
)
