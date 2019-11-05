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

readonly DEFAULT_CDH_URL=https://archive.cloudera.com/cdh6/6.0.0/parcels/
readonly DEFAULT_CM_REPO_URL=https://archive.cloudera.com/cm6/6.0.0/redhat7/yum/

# Prints out a usage statement
usage()
{
  cat << EOF
This script will create a new image and preload it with CDH parcels to speed up
bootstrapping time for Cloudera Altus Director.

You must ensure GCP credentials are available in the environment for this to
work properly. Please refer to Packer documentation here:
https://www.packer.io/docs/builders/googlecompute.html#authentication

Extra packer options can be provided in the PACKER_VARS environment variable
prior to executing this script.

Usage: $0 [options] <gcp-zone> <os> <gcp-project-id> [<name>] [<parcel-url>] [<repository-url>] [<repository-key-url>]

  <gcp-zone>:  The gcp zone that you want the new image to be housed in.
  <os>:          The OS family that you want to use as a base.
      Valid choices: centos-6, centos-7, rhel-6, rhel-7
  <gcp-project-id>: The id of the gcp project in which this instance will be built and be subsequently available.
  [<name>]:      An optional descriptive name for the new image. alpha-numeric lower case, embedded hyphens OK, 64 characters long. 
      Default is calculated dynamically (specified by "AUTO")
  [<parcel-url>]:      Optional parcel URL to use for preloading.
      Default ${DEFAULT_CDH_URL:?}
  [<repository-url>]:  Optional Cloudera Manager yum repo to use for preloading.
      Default ${DEFAULT_CM_REPO_URL:?}
  [<repository-key-url>]:  Optional URL for Cloudera Manager yum repo GPG key.
      Required if and only if repository-url is not at archive.cloudera.com

Be sure to specify <repository-url> for operating systems other than RHEL 7 or
CentOS 7.

OPTIONS:
  -h
    Show this help message
  -d
    Run packer in debug mode
  -j <version>
    Install a specific Java version
        Valid choices: 1.7, 1.8 (default)
  -J <jdk-repository>
    Yum repo to use for JDK RPM
        Valid choices: Director (default), CM
  -p
    Pre-extract CDH parcels
  -6
    Configure image for CDH 6

EOF
}

source scripts/building/base_images.sh

# Parses the parcel for an OS from the list of parcels at the supplied URL.
get_parcel_url()
{
  local cdh_url="$1"
  local os="$2"

  case $os in
    centos6* | centos-6* | rhel6* | rhel-6*)
      echo "${cdh_url}$(curl -L -s "${cdh_url}" | grep "el6.parcel<" | sed -E "s/.*>(.*parcel)<\/a.*/\1/" 2>/dev/null)"
      ;;
    centos7* | centos-7* | rhel7* | rhel-7*)
      echo "${cdh_url}$(curl -L -s "${cdh_url}" | grep "el7.parcel<" | sed -E "s/.*>(.*parcel)<\/a.*/\1/" 2>/dev/null)"
      ;;
    *)
      echo ""
      ;;
  esac
}

get_director_yum_url() {
  local os="$1"

  case $os in
    centos6* | centos-6* | rhel6* | rhel-6*)
      echo "https://archive.cloudera.com/director/redhat/6/x86_64/director/2.7/"
      ;;
    centos7* | centos-7* | rhel7* | rhel-7*)
      echo "https://archive.cloudera.com/director/redhat/7/x86_64/director/2.7/"
      ;;
    *)
      echo ""
      ;;
  esac
}

AMI_OPT=
C6=
DEBUG=
JAVA_VERSION=1.8
JDK_REPO=Director
PRE_EXTRACT=
while getopts "a:dj:J:p6h" opt; do
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
    6)
      C6=1
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


# Gather arguments into variables
GCP_ZONE=$1
OS=$2
PROJECT_ID=$3
NAME=${4-AUTO}
CDH_URL=${5-${DEFAULT_CDH_URL}}
CM_REPO_URL=${6-${DEFAULT_CM_REPO_URL:?}}
CM_GPG_KEY_URL=$7

# Assume C6 if CDH_URL is not provided or is the default value, and the -6
# option wasn't given
if [[ $CDH_URL == "$DEFAULT_CDH_URL" && -z $C6 ]]; then
  C6=1
fi

# Validate OS TBD

# Validate CM_GPG_KEY_URL
if [[ -z $CM_GPG_KEY_URL && ! $CM_REPO_URL =~ ^https?://archive.cloudera.com ]]; then
  echo "The URL for the RPM GPG key must be supplied for a custom Cloudera Manager repository"
  exit 3
fi

# Compute name if necessary
if [[ -z $NAME || $NAME == "AUTO" ]]; then
  NAME="${OS-cdh-cm-preload}"
fi
[[ "$NAME" =~ ^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$ ]] || { 
    cat <<EOF
ERROR: $0: Invalid name ($NAME). Must be alphanumeric, lower case, embedded hyphens permitted.
Must match regexp(7) expression: ^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$
EOF

    exit 2
}

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
PACKER_VARS_ARRAY=( $PACKER_VARS )
PACKER_VARS_ARRAY+=(-var "image_name=${NAME:?}")
PACKER_VARS_ARRAY+=(-var "project_id=${PROJECT_ID:?}")
PACKER_VARS_ARRAY+=(-var "zone=${GCP_ZONE:?}" -var "parcel_url=$PARCEL_URL" -var "cm_repository_url=$CM_REPO_URL")
if [[ -n $CM_GPG_KEY_URL ]]; then
  PACKER_VARS_ARRAY+=(-var "cm_gpg_key_url=$CM_GPG_KEY_URL")
fi
PACKER_VARS_ARRAY+=(-var "jdk_repository_url=$JDK_REPO_URL")
PACKER_VARS_ARRAY+=(-var "source_image_family=$OS")
PACKER_VARS_ARRAY+=(-var "java_version=$JAVA_VERSION")
if [[ -n $PRE_EXTRACT ]]; then
  PACKER_VARS_ARRAY+=(-var "preextract_parcel=true")
fi
if [[ -z $C6 ]]; then
  PACKER_VARS_ARRAY+=(-var "c6=false")
fi

# Set up other packer options
PACKER_OPTS=()
if [[ -n $DEBUG ]]; then
  PACKER_OPTS+=(-debug)
fi

JSON=gcp.json

packer build "${PACKER_VARS_ARRAY[@]}" "${PACKER_OPTS[@]}" packer-json/"$JSON"
cat <<EOF
Use this image uri: $(gcloud compute images list --filter="name ~ ${NAME:?}\$" --uri)

use the following command to find that uri in the future:

 gcloud compute images list --filter="name ~ ${NAME:?}\$" --uri


EOF


