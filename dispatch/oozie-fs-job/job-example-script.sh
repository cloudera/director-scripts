#!/bin/bash
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

# This script is used with dispatch.sh as part of the demonstration of the
# capability to interact with Oozie service and fulfill an actual workflow
# job which contains FS(hdfs) actions.
#
# At the beginning, it sets up the file structure on the HDFS of the running
# cluster. And then it prepares and submits a simple Oozie job to delete it
# and fetches the job result at the end.

set -x -e

BASEDIR=$(dirname "$0")
JOB_ID=$(basename "${BASEDIR}")

# Get the hostname of the EC2 instance where the script is running on.
# By default, all EC2 instance meta-data can be retrieved from
# http://169.254.169.254, which AWS uses to host instance metadata. Please see
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html
HOSTNAME="$(curl http://169.254.169.254/latest/meta-data/hostname)"
HDFS_DIR="/user/test/app/${JOB_ID}"

# Set up the file structure on HDFS
sudo -u hdfs hdfs dfs -mkdir -p "${HDFS_DIR}"
sudo -u hdfs hdfs dfs -put "${BASEDIR}/workflow.xml" "${HDFS_DIR}"
sudo -u hdfs hdfs dfs -mkdir -p /user/test/data/to_be_delete
sudo -u hdfs hdfs dfs -ls -R /user/test/data/

# Prepare the job.properties file used by the following Oozie job
JOB_PROP="${BASEDIR}/job.properties"

cat << JOB_PROP_EOF > "${JOB_PROP}"
nameNode=hdfs://${HOSTNAME}:8020
oozie.wf.application.path=\${nameNode}${HDFS_DIR}
JOB_PROP_EOF

# Submit the Oozie workflow job

# This script is uploaded to and run on the master node of the remote cluster
# that is provisioned by Cloudera Altus Director. And OOZIE_URL is defined to point
# to the Oozie service that is running on this master node.
OOZIE_URL="http://localhost:11000/oozie"
OOZIE_RET="$(sudo -u hdfs oozie job -oozie ${OOZIE_URL} -run -config ${JOB_PROP})"
OOZIE_JOB="$(echo ${OOZIE_RET} | cut -f 2 -d ' ')"

# Fetch the job result
echo "Check job results ..."
sudo -u hdfs hdfs dfs -ls -R /user/test/data/
sudo -u hdfs oozie job -oozie ${OOZIE_URL} -info "${OOZIE_JOB}"

exit 0
