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

# These are base AMIs for various operating systems that the Cloudera Altus Director
# team uses for their own testing in the us-east-2 region. While they are
# considered good choices, we cannot guarantee that they will always work.

declare -A BASE_AMIS=(
  ["centos69"]="ami-24093741 hvm centos /dev/sda1"
  ["centos73"]="ami-18f8df7d hvm centos /dev/sda1"
  ["centos74"]="ami-e0eac385 hvm centos /dev/sda1"
  ["centos75"]="ami-9c0638f9 hvm centos /dev/sda1"
  ["rhel73"]="ami-0932686c hvm ec2-user /dev/sda1"
  ["rhel74"]="ami-cebe94ab hvm ec2-user /dev/sda1"
  ["rhel75"]="ami-03291866 hvm ec2-user /dev/sda1"
)
