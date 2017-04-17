#!/usr/bin/env bash
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

# Bash 4+ required
if (( ${BASH_VERSION%%.*} < 4 )); then
  echo "bash 4 or higher is required. The current version is ${BASH_VERSION}."
  exit 1
fi

# Prints out a usage statement
usage()
{
  cat << EOF
This script will create a new AMI and preload it with CDH parcels to speed up
bootstrapping time for Cloudera Director.

You must ensure AWS credentials are available in the environment for this to
work properly. Please refer to Packer documentation here:
https://www.packer.io/docs/builders/amazon-ebs.html.

Extra packer options can be provided in the PACKER_VARS environment variable
prior to executing this script.

Usage: $0 [options] <aws-region> <os> [<name>] [<parcel-url>] [<repository-url>]

  <aws-region>:  The AWS region that you want the new AMI to be housed on.
  <os>:          The OS that you want to use as a base.
      Valid choices: rhel6x, rhel7x, centos6x, centos7x (x = minor version)
  [<name>]:      An optional descriptive name for the new AMI.
      Default is calculated dynamically (specified by "AUTO")
  [<parcel-url>]:      Optional parcel URL to use for preloading.
      Default http://archive.cloudera.com/cdh5/parcels/5.11/
  [<repository-url>]:  Optional Cloudera Manager yum repo to use for preloading.
      Default http://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.11/

Be sure to specify <repository-url> for operating systems other than RHEL 7 or
CentOS 7.

OPTIONS:
  -h
    Show this help message
  -a <ami-info>
    Use a specific base AMI
  -d
    Run packer in debug mode
  -j <version>
    Install a specific Java version
        Valid choices: 1.7 (default), 1.8
  -J <jdk-repository>
    Yum repo to use for JDK RPM
        Valid choices: Director (default), CM
  -p
    Pre-extract CDH parcels
  -P
    Associate public IP address

For the -a option, specify for <ami-info> a quoted string with the following
elements, separated by spaces:

  ami-id "pv"|"hvm" ssh-username root-device-name

Example: -a "ami-00000000 hvm centos72 /dev/sda1"

EOF
}

# Finds the recommended AMI for a region and OS
find_base_ami_info()
{
  local os="$1"
  local region="$2"

  if [[ ! -f "scripts/building/base_amis_${region}.sh" ]]; then
    echo "unsupported_region"
  else
    source "scripts/building/base_amis_${region}.sh"
    echo "${BASE_AMIS[$os]}"
  fi
}

# Parses the parcel for an OS from the list of parcels at the supplied URL.
get_parcel_url()
{
  local cdh_url="$1"
  local os="$2"

  case $os in
    centos6* | rhel6*)
      echo "${cdh_url}$(curl -s "${cdh_url}" | grep "el6.parcel<" | sed -E "s/.*>(.*parcel)<\/a.*/\1/" 2>/dev/null)"
      ;;
    centos7* | rhel7*)
      echo "${cdh_url}$(curl -s "${cdh_url}" | grep "el7.parcel<" | sed -E "s/.*>(.*parcel)<\/a.*/\1/" 2>/dev/null)"
      ;;
    *)
      echo ""
      ;;
  esac
}

get_director_yum_url() {
  local os="$1"

  case $os in
    centos6* | rhel6*)
      echo "http://archive.cloudera.com/director/redhat/6/x86_64/director/2.4/"
      ;;
    centos7* | rhel7*)
      echo "http://archive.cloudera.com/director/redhat/7/x86_64/director/2.4/"
      ;;
    *)
      echo ""
      ;;
  esac
}

AMI_OPT=
DEBUG=
JAVA_VERSION=1.7
JDK_REPO=Director
PRE_EXTRACT=
PUBLIC_IP=
while getopts "a:dj:J:pPh" opt; do
  case $opt in
    a)
      AMI_OPT="$OPTARG"
      ;;
    d)
      DEBUG=1
      ;;
    j)
      JAVA_VERSION="$OPTARG"
      ;;
    J)
      JDK_REPO="$OPTARG"
      ;;
    p)
      PRE_EXTRACT=1
      ;;
    P)
      PUBLIC_IP=1
      ;;
    h)
      usage
      exit
      ;;
    ?)
      usage
      exit
      ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -lt 2 ] || [ $# -gt 5 ]; then
    usage
    exit 1
fi

if ! hash packer 2> /dev/null; then
    echo "Packer is not installed or is not on the path. Please correct this before continuing."
    exit 2
else
    echo "Found packer version: $(packer version)"
fi

# Gather arguments into variables
AWS_REGION=$1
OS=$2
NAME=${3-AUTO}
CDH_URL=${4-"http://archive.cloudera.com/cdh5/parcels/5.11/"}
CM_REPO_URL=${5-"http://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.11/"}

# Validate OS TBD

# Look up AMI if necessary
if [[ -z $AMI_OPT ]]; then
  AMI_INFO=( $(find_base_ami_info "$OS" "$AWS_REGION") )
  if [[ ${AMI_INFO[0]} == "unsupported_region" ]]; then
    echo "Base AMIs for region $AWS_REGION are not recorded, use -a to specify an AMI"
    exit 3
  elif [[ -z "${AMI_INFO[@]}" ]]; then
    echo "A base AMI is not recorded for OS $OS in $AWS_REGION, use -a to specify an AMI"
    exit 3
  fi
else
  AMI_INFO=( $AMI_OPT )
fi
echo "Using AMI ${AMI_INFO[0]} for OS $OS"

AMI=${AMI_INFO[0]}
VIRTUALIZATION=${AMI_INFO[1]}
if [[ $VIRTUALIZATION != "pv" && $VIRTUALIZATION != "hvm" ]]; then
  echo "Invalid AMI virtualization type $VIRTUALIZATION"
  usage
  exit 3
fi
USERNAME=${AMI_INFO[2]}
ROOT_DEVICE_NAME=${AMI_INFO[3]}

# Compute name if necessary
if [[ -z $NAME || $NAME == "AUTO" ]]; then
  NAME="$OS CM/CDH preload"
fi

# Get the appropriate parcel file
PARCEL_URL="$(get_parcel_url "$CDH_URL" "$OS")"
if [[ -z $PARCEL_URL ]]; then
  echo "No parcels available for OS $OS"
  exit 4
fi

# Validate the Java version
VALID_JAVA_VERSIONS=("1.7" "1.8")
for v in "${VALID_JAVA_VERSIONS[@]}"; do
  if [[ "$JAVA_VERSION" == "$v" ]]; then
    JAVA_VERSION_VALID=1
    break
  fi
done
if [[ -z $JAVA_VERSION_VALID ]]; then
  echo "Invalid Java version $JAVA_VERSION"
  exit 5
fi

# Validate JDK repo, set JDK repo URL
case $JDK_REPO in
  CM)
    # Only 1.7 is available
    if [[ $JAVA_VERSION != "1.7" ]]; then
      echo "JDK $JAVA_VERSION is not available from the Cloudera Manager repository"
      echo "Use '-J Director' for JDK $JAVA_VERSION"
      exit 6
    fi
    JDK_REPO_URL="$CM_REPO_URL"
    ;;
  Director)
    # 1.7 and 1.8 are available
    JDK_REPO_URL=$(get_director_yum_url "$OS")
    if [[ -z $JDK_REPO_URL ]]; then
      echo "Cloudera Director yum repo is not available for OS $OS"
      exit 6
    fi
    ;;
  *)
    echo "Invalid choice for JDK repo: $JDK_REPO"
    usage
    exit 6
esac

# Set up packer variables
PACKER_VARS_ARRAY=( $PACKER_VARS )
PACKER_VARS_ARRAY+=(-var "region=$AWS_REGION" -var "parcel_url=$PARCEL_URL" -var "cm_repository_url=$CM_REPO_URL")
PACKER_VARS_ARRAY+=(-var "jdk_repository_url=$JDK_REPO_URL")
PACKER_VARS_ARRAY+=(-var "ami=$AMI" -var "ami_virtualization_type=$VIRTUALIZATION" -var "ssh_username=$USERNAME" -var "root_device_name=$ROOT_DEVICE_NAME")
PACKER_VARS_ARRAY+=(-var "ami_prefix=$NAME")
PACKER_VARS_ARRAY+=(-var "java_version=$JAVA_VERSION")
if [[ -n $PRE_EXTRACT ]]; then
  PACKER_VARS_ARRAY+=(-var "preextract_parcel=true")
fi
if [[ -n $PUBLIC_IP ]]; then
  PACKER_VARS_ARRAY+=(-var "associate_public_ip_address=true")
fi

# Set up other packer options
PACKER_OPTS=()
if [[ -n $DEBUG ]]; then
  PACKER_OPTS+=(-debug)
fi

JSON=rhel.json

packer build "${PACKER_VARS_ARRAY[@]}" "${PACKER_OPTS[@]}" packer-json/"$JSON"
