#!/usr/bin/env bash
#
# (c) Copyright 2017 Cloudera, Inc.
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

# These are base AMIs for various operating systems that the Cloudera Director
# team uses for their own testing in the eu-central-1 region. While they are
# considered good choices, we cannot guarantee that they will always work.

declare -A BASE_AMIS=(
#  ["centos64"]="ami-b3bf2f83 pv ec2-user /dev/sda1" - does not exist in eu-central-1
#  ["centos65"]="ami-b6bdde86 pv ec2-user /dev/sda" - does not exist in eu-central-1
  ["centos67"]="ami-2bf11444 hvm centos /dev/sda1"
  ["centos72"]="ami-9bf712f4 hvm centos /dev/sda1"
  ["centos73"]="ami-fa2df395 hvm centos /dev/sda1"
  ["centos74"]="ami-1e038d71 hvm centos /dev/sda1"
#  ["rhel64"]="ami-58eadc45 pv ec2-user /dev/sda1"
#  ["rhel65"]="ami-6aeadc77 pv ec2-user /dev/sda1"
  ["rhel66"]="ami-fa0538e7 hvm ec2-user /dev/sda1"
  ["rhel67"]="ami-8e96ac93 hvm ec2-user /dev/sda1"
  ["rhel71"]="ami-38d2d625 hvm ec2-user /dev/sda1"
  ["rhel72"]="ami-b6688dd9 hvm ec2-user /dev/sda1"
  ["rhel73"]="ami-e4c63e8b hvm ec2-user /dev/sda1"
)
