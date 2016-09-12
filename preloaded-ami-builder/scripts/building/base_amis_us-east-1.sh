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
# team uses for their own testing in the us-east-1 region. While they are
# considered good choices, we cannot guarantee that they will always work.

declare -A BASE_AMIS=(
  ["centos64"]="ami-26cc934e pv ec2-user /dev/sda1"
  ["centos65"]="ami-9ade2af2 pv ec2-user /dev/sda"
  ["centos67"]="ami-1c221e76 hvm centos /dev/sda1"
  ["centos72"]="ami-6d1c2007 hvm centos /dev/sda1"
  ["rhel64"]="ami-a25415cb pv ec2-user /dev/sda1"
  ["rhel65"]="ami-1643ff7e pv ec2-user /dev/sda1"
  ["rhel66"]="ami-b0fed2d8 hvm ec2-user /dev/sda1"
  ["rhel67"]="ami-0d28fe66 hvm ec2-user /dev/sda1"
  ["rhel71"]="ami-dbc96ab0 hvm ec2-user /dev/sda1"
  ["rhel72"]="ami-85241def hvm ec2-user /dev/sda1"
)
