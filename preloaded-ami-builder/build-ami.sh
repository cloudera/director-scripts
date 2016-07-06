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

# Prints out a usage statement
usage()
{
  cat << EOF
This script will create a new AMI and preload it with CDH parcels to speed up
bootstrapping time for Cloudera Director. You must supply the ID of a CentOS
or RHEL 6.4-6.6 AMI to use as a base for the preloaded AMI.

Additionally, you must ensure AWS credentials are available in the environment
for this to work properly. Please refer to Packer's documentation here:
https://www.packer.io/docs/builders/amazon-ebs.html.

Extra packer options can be provided in the PACKER_VARS environment variable
prior to executing this script.

Usage: $0 <aws-region> <ami> <name> [parcel-url] [repository-url]

  <aws-region>:  The AWS region that you want the new AMI to be housed on.
  <ami>:         The AMI you want to use as a base.
  <name>:        A descriptive name for the new AMI.
  [parcel-url]:  Optional parcel URL to use for preloading.
                 Defaults to http://archive.cloudera.com/cdh5/parcels/5.7/
  [repository-url]:  Optional Cloudera Manager yum repository URL to use for preloading.
                     Defaults to http://archive.cloudera.com/cm5/redhat/6/x86_64/cm/

EOF
}

# Parses the el6 (CentOS/RHEL 6) parcel from the list of parcels at the supplied URL.
get_rhel_parcel_url()
{
  PARCEL_URL=$1$(curl -s $1 | grep "el6.parcel<" | sed -E "s/.*>(.*parcel)<\/a.*/\1/" 2>/dev/null)
}

if [ $# -lt 3 ] || [ $# -gt 5 ]; then
    usage
    exit 1
fi

if ! which packer > /dev/null; then
    echo "Packer is not installed or is not on the system path. Please correct this before continuing."
    exit 2
else
    echo "Found packer version: $(packer version)"
fi

# Gather arguments into variables
AWS_REGION=$1
AMI=$2
NAME=$3
CDH_URL=${4-"http://archive.cloudera.com/cdh5/parcels/5.7/"}
CM_REPO_URL=${5-"http://archive.cloudera.com/cm5/redhat/6/x86_64/cm/"}

# Get the appropriate parcel file
get_rhel_parcel_url $CDH_URL

# Set up packer variables
PACKER_VARS="$PACKER_VARS -var region=$AWS_REGION -var parcel_url=$PARCEL_URL -var cm_repository_url=$CM_REPO_URL"

packer build $PACKER_VARS -var ami=$AMI -var ami_prefix="$NAME" packer-json/rhel.json
