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
# e.g. http://archive-primary.cloudera.com/cdh5/parcels/5.7.0/CDH-5.7.0-1.cdh5.7.0.p0.45-el7.parcel

# You can do this one of two ways:
# 1. Set a PARCEL_URL environment variable.
# 2. Supply an argument that is a PARCEL_URL.

# This script will have to be re-run for each parcel you want to cache on the
# image that you are building.

if [ -z "${PARCEL_URL+set}" ]
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
sudo curl -s -S "${PARCEL_URL}" -o "/opt/cloudera/parcel-repo/$PARCEL_NAME"
sudo curl -s -S "${PARCEL_URL}.sha1" -o "/opt/cloudera/parcel-repo/$PARCEL_NAME.sha1"
sudo cp "/opt/cloudera/parcel-repo/$PARCEL_NAME.sha1" "/opt/cloudera/parcel-repo/$PARCEL_NAME.sha"

echo "Verifying parcel checksum"
sudo sed "s/$/  ${PARCEL_NAME}/" "/opt/cloudera/parcel-repo/$PARCEL_NAME.sha1" |
  sudo tee "/opt/cloudera/parcel-repo/$PARCEL_NAME.shacheck" > /dev/null
if ! eval "cd /opt/cloudera/parcel-repo && sha1sum -c \"$PARCEL_NAME.shacheck\""; then
  echo "Checksum verification failed"
  exit 1
fi
sudo rm "/opt/cloudera/parcel-repo/$PARCEL_NAME.shacheck"

for parcel_path in /opt/cloudera/parcel-repo/*.parcel
do
    sudo ln "$parcel_path" "/opt/cloudera/parcel-cache/$(basename "$parcel_path")"
done
sudo chown -R cloudera-scm:cloudera-scm /opt/cloudera

if [ "$PREEXTRACT_PARCEL" = true ]
then
  echo "Preextracting parcels..."
  sudo tar zxf "/opt/cloudera/parcel-repo/$PARCEL_NAME" -C "/opt/cloudera/parcels"
  sudo ln -s "$(ls -1 /opt/cloudera/parcels)" /opt/cloudera/parcels/CDH
  sudo touch /opt/cloudera/parcels/CDH/.dont_delete
  echo "Done"
fi

echo "Sleeping for 300 seconds to ensure parcels will properly sync with EBS."
sleep 300
