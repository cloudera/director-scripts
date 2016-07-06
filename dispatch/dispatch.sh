#!/bin/bash
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

RANDOM_TOKEN=$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-z0-9' | fold -w 12 | head -n 1)

set -o errexit -o pipefail -o nounset


# Check for additional commands that need to be installed for this to work
if [[ ! -x "$(command -v jq)" ]]; then
    echo "Required jq (https://stedolan.github.io/jq/) command not found"
    exit -1
fi

if [[ ! -x "$(command -v wget)" ]]; then
    echo "Required wget command not found"
    exit -1
fi

#
# Cloudera Director server credentials and URL
#

DIRECTOR_SERVER="http://localhost:7189"
DIRECTOR_USER=admin
DIRECTOR_PASSWORD=admin

SSH_USERNAME="ec2-user"
SSH_PRIVATE_KEY="~/.ssh/id_rsa"

#
# Optional overrides for config entity names
#

ENVIRONMENT_NAME="Test Environment"
DEPLOYMENT_NAME="Test Cloudera Manager"
CLUSTER_NAME="job_${RANDOM_TOKEN}"

GATEWAY_GROUP_NAME="masters"
PROVISION_CONFIG="None"
TERMINATE="false"

function usage {
    cat <<USAGE_TEXT
Usage: $0 <optional arguments> -f=cluster.conf job-script.sh [file1.jar file2.zip ...]"

Optional arguments:

 -s, --server            server URL (default ${DIRECTOR_SERVER})
 -u, --user              server API admin user (default ${DIRECTOR_USER})
 -p, --password          server API admin password
 -e, --environment       environment name (default ${ENVIRONMENT_NAME})
 -d, --deployment        deployment name (default ${DEPLOYMENT_NAME})
 -c, --cluster           cluster name (random by default with prefix job_)
 -g, --gateway-group     gateway group name (default ${GATEWAY_GROUP_NAME})
 -n, --ssh-username      SSH username to use to connect to the gateway (default ${SSH_USERNAME})
 -i, --ssh-private-key   SSH private key to use to  connect to the gateway (default ${SSH_PRIVATE_KEY})
 -f, --provision-config  Provision a new cluster with the given config file
 -t, --terminate         Terminate the cluster (default ${TERMINATE})

Example usage:

  $0 -u=admin -i=test.pem -f=cluster.conf -t job1.sh data.zip

USAGE_TEXT
}

for i in "$@"
do
case $i in
    -s=*|--server=*)
    DIRECTOR_SERVER="${i#*=}"
    shift
    ;;
    -u=*|--user=*)
    DIRECTOR_USER="${i#*=}"
    shift # past argument=value
    ;;
    -p=*|--password=*)
    DIRECTOR_PASSWORD="${i#*=}"
    shift # past argument=value
    ;;
    -e=*|--environment=*)
    ENVIRONMENT_NAME="${i#*=}"
    shift # past argument=value
    ;;
    -d=*|--deployment=*)
    DEPLOYMENT_NAME="${i#*=}"
    shift # past argument=value
    ;;
    -c=*|--cluster=*)
    CLUSTER_NAME="${i#*=}"
    shift # past argument=value
    ;;
    -g=*|--gateway-group=*)
    GATEWAY_GROUP_NAME="${i#*=}"
    shift # past argument=value
    ;;
    -n=*|--ssh-username=*)
    SSH_USERNAME="${i#*=}"
    shift # past argument=value
    ;;
    -i=*|--ssh-private-key=*)
    SSH_PRIVATE_KEY="${i#*=}"
    shift # past argument=value
    ;;
    -f=*|--provision-config=*)
    PROVISION_CONFIG="${i#*=}"
    shift # past argument=value
    ;;
    -t|--terminate)
    TERMINATE="true"
    shift
    ;;
    -h|--help)
    usage
    exit 0
    shift
    ;;
    *)
          # unknown option
    ;;
esac
done

CLUSTER_URL="${DIRECTOR_SERVER}/api/v4/environments/${ENVIRONMENT_NAME}/deployments/${DEPLOYMENT_NAME}/clusters/${CLUSTER_NAME}"

WGET="wget -O - --content-on-error --no-verbose --user ${DIRECTOR_USER} --password ${DIRECTOR_PASSWORD} --auth-no-challenge"

terminate() {
    for i in {5..0}; do
        echo -ne "Terminating cluster ${CLUSTER_NAME} in $i seconds"'\r'
        sleep 1
    done

    ${WGET} --method DELETE "${CLUSTER_URL}"

    STAGE=$(${WGET} -q "${CLUSTER_URL}/status" | jq -r ".stage");
    if [[ "${STAGE}" != "TERMINATING" ]]; then
        echo "Unable to terminate cluster. Stage is ${STAGE}."
        echo "Please terminate cluster ${CLUSTER_NAME} manually!"
        exit -1
    fi

    while ${WGET} -q "${CLUSTER_URL}/status"; do
        echo "Cluster ${CLUSTER_NAME} is terminating. Waiting for 10 seconds ..."
        sleep 10
    done
    echo "Cluster ${CLUSTER_NAME} is terminated"
}

#
# Import and job dispatch logic
#

# Provision the cluster if not in job-submission mode
PROVISIONED="false"
if [[ -f "${PROVISION_CONFIG}" ]]; then
    # Path to config file with all the details needed to create the cluster

    # Import client config to Director
    PROVISIONED="true"
    echo "Importing client config ${PROVISION_CONFIG} to ${DIRECTOR_SERVER}"

    ${WGET} --header="Content-Type: text/plain" --post-file "${PROVISION_CONFIG}" \
        "${DIRECTOR_SERVER}/api/v4/import?clusterName=${CLUSTER_NAME}&deploymentName=${DEPLOYMENT_NAME}&environmentName=${ENVIRONMENT_NAME}"
    echo

    # Iterate on status endpoint for cluster based on response

    echo "Waiting for cluster ${CLUSTER_NAME} to get to READY stage ..."

    while
        STAGE=$(${WGET} -q "${CLUSTER_URL}/status" | jq -r ".stage");
        [ "${STAGE}" != "READY" ];
    do
        if [ "${STAGE}" == "BOOTSTRAP_FAILED" ]; then
            echo "Cluster ${CLUSTER_NAME} failed to  bootstrap. Please check server logs."
            exit -1
        fi
        if [[ -z "${STAGE}" ]]; then
            echo "Unable to retrieve status for cluster ${CLUSTER_NAME}. Please check server logs."
            exit -1
        fi
        echo "Stage is ${STAGE}. Waiting for 30 seconds ..."
        sleep 30
    done

    echo "Cluster ${CLUSTER_NAME} is provisioned successfully"
    echo "Cluster ${CLUSTER_NAME} is ready to accept jobs"
    echo
fi

# Check the existence of the cluster
${WGET} -q "${CLUSTER_URL}/status" || { echo "Cluster ${CLUSTER_NAME} not found" >&2; exit -1; }

SUBMIT_JOB="false"
if [[ -n "$@" ]]; then
    SUBMIT_JOB="true"
    # All the arguments are expected to be valid file paths
    for ARG in "$@"
    do
        if ! [ -f "${ARG}" ]; then
            echo "File '${ARG}' not found"
            usage
            exit -2
        fi
    done
fi

if [[ "${SUBMIT_JOB}" == "true" ]]; then
    # Submit the job
    # Find the IP address for a gateway
    echo "Submitting a new job"
    GATEWAY_IP=$(${WGET} -q "${CLUSTER_URL}" \
            | jq -r ".instances | map(select(.virtualInstance.template.name == \"${GATEWAY_GROUP_NAME}\"))[0] | .ipAddress")

    echo "Using instance with IP ${GATEWAY_IP} as a gateway to run job ..."

    # Copy all the local files referenced on the command line


    JOB_ID="j-${RANDOM_TOKEN}"
    echo "Dispatching job: ${JOB_ID}"

    REMOTE="${SSH_USERNAME}@${GATEWAY_IP}"
    SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY/#\~/$HOME}"

    SSH="ssh -o StrictHostKeyChecking=no -i ${SSH_PRIVATE_KEY} ${REMOTE}"
    SCP="scp -o StrictHostKeyChecking=no -i ${SSH_PRIVATE_KEY}"

    JOB_DIR="/tmp/${JOB_ID}"
    ${SSH} mkdir ${JOB_DIR}

    for PART in "$@"
    do
        ${SCP} ${PART} ${REMOTE}:${JOB_DIR}/
    done

    JOB_SCRIPT=$(basename $1)
    shift

    #
    # Run the job script remotely. The expectation is that the script will block until all the work is done
    #
    echo "Starting job: ${JOB_ID}"
    ${SSH} -t sudo sh -e "${JOB_DIR}/${JOB_SCRIPT}"
fi

# Terminate only the cluster so that the next run will take
# advantage of an existing Cloudera Manager

if [[ "${TERMINATE}" == "true" ]]; then
    terminate
else
    if [[ "${PROVISIONED}" == "true" ]]; then
        echo "Exit without terminating the cluster. You need to manually terminate cluster ${CLUSTER_NAME}."
    elif [[ "${SUBMIT_JOB}" == "false" ]]; then
        usage
        exit -2
    fi
fi

exit 0
