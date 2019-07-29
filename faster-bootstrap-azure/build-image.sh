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

# Bash 4+ required
if (( ${BASH_VERSION%%.*} < 4 )); then
  echo "bash 4 or higher is required. The current version is ${BASH_VERSION}."
  exit 1
fi

# Prints out a usage statement
usage()
{
  cat << EOF
This script will create a new Managed Image and preload it with CDH parcels
to speed up bootstrapping time for Cloudera Altus Director.

You must ensure Azure credentials are placed into credentials.json for the
script to work properly. See the credentials.json.example file for the proper
format.

Extra packer options can be provided in the PACKER_VARS environment variable
prior to executing this script.

Usage: $0 [options] <azure-region> <resource-group> <os> [<name>] [<parcel-url>] [<repository-url>]

  <azure-region>:  The Azure region where you want the new Image to be created.
  <resource-group>: The Azure resource group where the new image should be created.
  <os>:  The OS that you want to use as a base.
      Valid choices: centos67|centos68|centos72|centos74|centos75
                     rhel67|rhel68|rhel69|rhel610|rhel72|rhel73|rhel74|rhel74|rhel75
  [<name>]:  An optional descriptive name for the new Image.
      Default is calculated dynamically (specified by "AUTO")
  [<parcel-url>]:  Optional parcel URL to use for preloading.
      Default https://archive.cloudera.com/cdh6/6.3/parcels/
  [<repository-url>]:  Optional Cloudera Manager yum repo to use for preloading.
      Default https://archive.cloudera.com/cm6/6.3/redhat7/yum/ or https://archive.cloudera.com/cm6/6.3/redhat6/yum/
  [<repository-key-url>]:  Optional URL for Cloudera Manager yum repo GPG key.
      Required only if repository-url is not at archive.cloudera.com

Be sure to specify <repository-url> for operating systems other than RHEL 7 or
CentOS 7.

OPTIONS:
  -h
    Show this help message
  -d
    Run packer in debug mode
  -j <version>
    Install a specific Java version
        Valid choices: 1.7 , 1.8 (default)
  -J <jdk-repository>
    Yum repo to use for JDK RPM
        Valid choices: Director (default), CM
  -p
    Pre-extract CDH parcels
  -6
    Configure image for CDH 6
  -s
    Image OS Volume Size in GB
  -C <Azure Cloud Environment>
        Valid choices:  Public (default), China, Germany, USGovernment

EOF
}

# Populates BASE_IMAGES and BASE_PLANS arrays
source scripts/building/base_images.sh

# Finds the base image for selected OS
find_base_image()
{
  local os="$1"
  echo "${BASE_IMAGES[$os]}"
}

# Finds the base image for selected OS
find_base_image_plan()
{
  local os="$1"
  echo "${BASE_PLANS[$os]}"
}

# Parses the parcel for an OS from the list of parcels at the supplied URL.
get_parcel_url()
{
  local cdh_url="$1"
  local os="$2"

  case $os in
    centos6* | rhel6*)
      echo "${cdh_url}$(curl -L -s "${cdh_url}" | grep "el6.parcel<" | sed -E "s/.*>(.*parcel)<\\/a.*/\\1/" 2>/dev/null)"
      ;;
    centos7* | rhel7*)
      echo "${cdh_url}$(curl -L -s "${cdh_url}" | grep "el7.parcel<" | sed -E "s/.*>(.*parcel)<\\/a.*/\\1/" 2>/dev/null)"
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
      echo "https://archive.cloudera.com/director/redhat/6/x86_64/director/2.7/"
      ;;
    centos7* | rhel7*)
      echo "https://archive.cloudera.com/director/redhat/7/x86_64/director/2.7/"
      ;;
    *)
      echo ""
      ;;
  esac
}

C6=
DEBUG=
JAVA_VERSION=1.8
JDK_REPO=Director
PRE_EXTRACT=
CLOUD=Public
OS_VOL_SIZE=
while getopts "dj:J:p6C:s:h" opt; do
  case $opt in
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
    6)
      C6=1
      ;;
    C)
      CLOUD="$OPTARG"
      ;;
    s)
      OS_VOL_SIZE="$OPTARG"
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

if [ $# -lt 2 ] || [ $# -gt 6 ]; then
    usage
    exit 1
fi

if ! hash packer 2> /dev/null; then
    echo "Packer is not installed or is not on the path. Please correct this before continuing."
    exit 2
else
    echo "Found packer version: $(packer version)"
fi

DEFAULT_CDH_URL=https://archive.cloudera.com/cdh6/6.3/parcels/

# Gather arguments into variables
AZURE_REGION=$1
RG=$2
OS=$3
NAME=${4-AUTO}
CDH_URL=${5-${DEFAULT_CDH_URL}}
if [[ $OS =~ ^(centos|rhel)7.*$ ]]; then
  CM_REPO_URL=${6-"https://archive.cloudera.com/cm6/6.3/redhat7/yum/"}
else
  CM_REPO_URL=${6-"https://archive.cloudera.com/cm6/6.3/redhat6/yum/"}
fi
CM_GPG_KEY_URL=$7

# Validate OS TBD

# Validate CM_GPG_KEY_URL
if [[ -z $CM_GPG_KEY_URL && ! $CM_REPO_URL =~ ^https?://archive.cloudera.com ]]; then
  echo "The URL for the RPM GPG key must be supplied for a custom Cloudera Manager repository"
  exit 3
fi

IMAGE=$(find_base_image "$OS" )
IFS=":" read -r -a IMAGE_PARTS <<< "$IMAGE"
IMAGE_PUBLISHER=${IMAGE_PARTS[0]}
IMAGE_OFFER=${IMAGE_PARTS[1]}
IMAGE_SKU=${IMAGE_PARTS[2]}
IMAGE_VERSION=${IMAGE_PARTS[3]}

IMAGE_PLAN=$(find_base_image_plan "$OS" )
IFS=":" read -r -a IMAGE_PLAN_PARTS <<< "$IMAGE_PLAN"
IMAGE_PLAN_PUBLISHER=${IMAGE_PLAN_PARTS[0]}
IMAGE_PLAN_PRODUCT=${IMAGE_PLAN_PARTS[1]}
IMAGE_PLAN_NAME=${IMAGE_PLAN_PARTS[2]}

echo "Using Image '${IMAGE}' for OS $OS"
echo "Using Plan '${IMAGE_PLAN}' for OS $OS"

# Compute name if necessary
if [[ -z $NAME || $NAME == "AUTO" ]]; then
  NAME="${OS}_CM_CDH_preload_"$(date +"%Y%m%dT%H%M")
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
    JDK_REPO_URL="$CM_REPO_URL"
    ;;
  Director)
    JDK_REPO_URL=$(get_director_yum_url "$OS")
    if [[ -z $JDK_REPO_URL ]]; then
      echo "Cloudera Altus Director yum repo is not available for OS $OS"
      exit 6
    fi
    ;;
  *)
    echo "Invalid choice for JDK repo: $JDK_REPO"
    usage
    exit 6
esac

# Set up packer variables
IFS=" " read -r -a PACKER_VARS_ARRAY <<< "$PACKER_VARS"
PACKER_VARS_ARRAY+=(-var "azure_location=$AZURE_REGION" -var "parcel_url=$PARCEL_URL" -var "cm_repository_url=$CM_REPO_URL")

PACKER_VARS_ARRAY+=(-var "jdk_repository_url=$JDK_REPO_URL")
PACKER_VARS_ARRAY+=(-var "azure_cloud_environment=$CLOUD")

if [[ -n $CM_GPG_KEY_URL ]]; then
  PACKER_VARS_ARRAY+=(-var "cm_gpg_key_url=$CM_GPG_KEY_URL")
fi
PACKER_VARS_ARRAY+=(-var "jdk_repository_url=$JDK_REPO_URL")

PACKER_VARS_ARRAY+=(-var "azure_managed_image_name=$NAME")
PACKER_VARS_ARRAY+=(-var "azure_managed_image_resource_group=$RG")

PACKER_VARS_ARRAY+=(-var "azure_image_publisher=$IMAGE_PUBLISHER")
PACKER_VARS_ARRAY+=(-var "azure_image_offer=$IMAGE_OFFER")
PACKER_VARS_ARRAY+=(-var "azure_image_sku=$IMAGE_SKU")
PACKER_VARS_ARRAY+=(-var "azure_image_version=$IMAGE_VERSION")

if [[ -n $IMAGE_PLAN ]]; then
    PACKER_VARS_ARRAY+=(-var "azure_image_plan_publisher=$IMAGE_PLAN_PUBLISHER")
    PACKER_VARS_ARRAY+=(-var "azure_image_plan_product=$IMAGE_PLAN_PRODUCT")
    PACKER_VARS_ARRAY+=(-var "azure_image_plan_name=$IMAGE_PLAN_NAME")
fi

PACKER_VARS_ARRAY+=(-var "java_version=$JAVA_VERSION")
if [[ -n $PRE_EXTRACT ]]; then
  PACKER_VARS_ARRAY+=(-var "preextract_parcel=true")
fi
if [[ -n $PUBLIC_IP ]]; then
  PACKER_VARS_ARRAY+=(-var "associate_public_ip_address=true")
fi
if [[ -z $C6 ]]; then
  PACKER_VARS_ARRAY+=(-var "c6=false")
fi

if [[ -n $OS_VOL_SIZE ]]; then
  PACKER_VARS_ARRAY+=(-var "os_disk_size_gb=$OS_VOL_SIZE")
fi

# Set up other packer options
PACKER_OPTS=()
if [[ -n $DEBUG ]]; then
  PACKER_OPTS+=(-debug)
fi

JSON=rhel.json

packer build "${PACKER_VARS_ARRAY[@]}" "${PACKER_OPTS[@]}" -var-file credentials.json packer-json/"$JSON"
