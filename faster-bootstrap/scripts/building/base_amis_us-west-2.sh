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

# These are base AMIs for various operating systems that the Cloudera Director
# team uses for their own testing in the us-west-2 region. While they are
# considered good choices, we cannot guarantee that they will always work.

declare -A BASE_AMIS=(
#  ["centos64"]="ami-b3bf2f83 pv ec2-user /dev/sda1"
#  ["centos65"]="ami-b6bdde86 pv ec2-user /dev/sda"
  ["centos67"]="ami-05cf2265 hvm centos /dev/sda1"
  ["centos72"]="ami-d2c924b2 hvm centos /dev/sda1"
  ["centos73"]="ami-f4533694 hvm centos /dev/sda1"
  ["centos74"]="ami-b63ae0ce hvm centos /dev/sda1"
#  ["rhel64"]="ami-b8a63b88 pv ec2-user /dev/sda1"
#  ["rhel65"]="ami-7df0bd4d pv ec2-user /dev/sda1"
  ["rhel66"]="ami-2faa861f hvm ec2-user /dev/sda1"
  ["rhel67"]="ami-75f3f145 hvm ec2-user /dev/sda1"
  ["rhel71"]="ami-c15a52f1 hvm ec2-user /dev/sda1"
  ["rhel72"]="ami-a3fa16c3 hvm ec2-user /dev/sda1"
)
