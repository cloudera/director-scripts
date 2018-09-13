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

# These are base AMIs for various operating systems that the Cloudera Altus Director
# team uses for their own testing in the us-west-1 region. While they are
# considered good choices, we cannot guarantee that they will always work.

declare -A BASE_AMIS=(
#  ["centos64"]="ami-b5886cf1 pv ec2-user /dev/sda1"
#  ["centos65"]="ami-a05753e5 pv ec2-user /dev/sda"
  ["centos67"]="ami-ac5f2fcc hvm centos /dev/sda1"
  ["centos69"]="ami-8adb3fe9 hvm centos /dev/sda1"
  ["centos72"]="ami-af4333cf hvm centos /dev/sda1"
  ["centos73"]="ami-f5d7f195 hvm centos /dev/sda1"
  ["centos74"]="ami-b1a59fd1 hvm centos /dev/sda1"
  ["centos75"]="ami-4826c22b hvm centos /dev/sda1"
#  ["rhel64"]="ami-6283a827 pv ec2-user /dev/sda1"
#  ["rhel65"]="ami-2b171d6e pv ec2-user /dev/sda1"
  ["rhel66"]="ami-f3a243b7 hvm ec2-user /dev/sda1"
  ["rhel67"]="ami-5b8a781f hvm ec2-user /dev/sda1"
  ["rhel71"]="ami-c1996685 hvm ec2-user /dev/sda1"
  ["rhel72"]="ami-f7eb9b97 hvm ec2-user /dev/sda1"
  ["rhel73"]="ami-2cade64c hvm ec2-user /dev/sda1"
  ["rhel74"]="ami-c8020fa8 hvm ec2-user /dev/sda1"
  ["rhel75"]="ami-18726478 hvm ec2-user /dev/sda1"
)
