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

# For this script to work properly, you need to supply a URL to a parcel file,
# e.g. http://archive-primary.cloudera.com/cdh5/parcels/5.5.0/CDH-5.5.0-1.cdh5.5.0.p0.8-wheezy.parcel

# You can do this one of two ways:
# 1. Set a PARCEL_URL environment variable.
# 2. Supply an argument that is a PARCEL_URL.

# This script will have to be re-run for each parcel you want to cache on the
# image that you are building.

if [ -z ${PARCEL_URL+set} ]
then
  if [ "$#" -ne 1 ]
  then
    echo "Usage: $0 <parcel-url>"
    echo ""
    echo "Alternatively, set the environment variable PARCEL_URL prior to"
    echo "running this script."
    exit 1
  else
    PARCEL_URL=$1
  fi
fi

sudo useradd -r cloudera-scm
sudo mkdir -p /opt/cloudera/parcels /opt/cloudera/parcel-repo /opt/cloudera/parcel-cache

PARCEL_NAME="${PARCEL_URL##*/}"

echo "Downloading parcel from $PARCEL_URL"
sudo curl "${PARCEL_URL}" -o "/opt/cloudera/parcel-repo/$PARCEL_NAME"
sudo curl "${PARCEL_URL}.sha1" -o "/opt/cloudera/parcel-repo/$PARCEL_NAME.sha"

for parcel_path in /opt/cloudera/parcel-repo/*.parcel
do
    sudo ln "$parcel_path" "/opt/cloudera/parcel-cache/$(basename $parcel_path)"
done

if [ "$PREEXTRACT_PARCEL" = true ]
then
  echo "Preextracting parcels..."
  sudo tar zxf "/opt/cloudera/parcel-repo/$PARCEL_NAME" -C "/opt/cloudera/parcels"
  sudo ln -s "$(ls -1 /opt/cloudera/parcels)" /opt/cloudera/parcels/CDH
  echo "Done"
fi

echo "Sleeping for 300 seconds to ensure parcels will properly sync with AWS."
sleep 300
