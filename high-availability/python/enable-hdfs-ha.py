#!/usr/bin/env python
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

from collections import namedtuple
from cm_api.api_client import ApiResource
from cm_api.endpoints.types import ApiCommand
from retrying import retry
from threading import Thread
from uuid import uuid4
import argparse
import os
import sys


class CommandWait(Thread):
    """
    A class that will wait on a command indefinitely.
    """

    def __init__(self, command):
        Thread.__init__(self)
        self.command = command

    def run(self):
        self.command.wait()


def retrieve_args():
    """
    Attempts to retrieve Cloudera Manager connection information from the environment.
    If that fails, the information is parsed from the command line.

    @rtype:  namespace
    @return: The parsed arguments.
    """

    if all(env_var in os.environ for env_var in ("DEPLOYMENT_HOST_PORT",
                                                 "CM_USERNAME", "CM_PASSWORD",
                                                 "CLUSTER_NAME")):
        write_to_stdout("Arguments detected in environment -- command line arguments being ignored.\n")
        args = namedtuple("args", ["host", "port", "username", "password", "cluster",
                          "nameservice", "wait_for_good_health"])

        parsed_url = os.environ["DEPLOYMENT_HOST_PORT"].split(":")
        args.host = parsed_url[0]
        args.port = int(parsed_url[1])
        args.username = os.environ["CM_USERNAME"]
        args.password = os.environ["CM_PASSWORD"]
        args.cluster = os.environ["CLUSTER_NAME"]
        # Generate a random nameservice for this highly available cluster
        args.nameservice = "nameservice" + str(uuid4())
        args.wait_for_good_health = True

        return args
    else:
        return parse_args()


def parse_args():
    """
    Parses host and cluster information from the given command line arguments.

    @rtype:  namespace
    @return: The parsed arguments.
    """
    parser = argparse.ArgumentParser(description="Enables HA for the HDFS service on a Cluster",
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('cluster', metavar='CLUSTER', type=str,
                        help="The name of the cluster to enable HDFS HA")
    parser.add_argument('nameservice', metavar='NAMESERVICE', type=str,
                        help="The nameservice the HDFS NameNodes will use")
    parser.add_argument('--host', metavar='HOST', type=str, default='localhost',
                        help="The Cloudera Manager host")
    parser.add_argument('--port', metavar='PORT', type=int, default=7180,
                        help="Cloudera Manager's port.")
    parser.add_argument('--username', metavar='USERNAME', type=str, default='admin',
                        help="The username to log into Cloudera Manager with.")
    parser.add_argument('--password', metavar='PASSWORD', type=str, default='admin',
                        help="The password to log into Cloudera Manager with.")
    parser.add_argument('--wait-for-good-health', action='store_true',
                        help="Whether to wait for Cloudera Manager services to be in GOOD health")
    return parser.parse_args()


def wait_for_command(msg, command):
    """
    Waits unbounded for a command to complete

    @type  msg: str
    @param msg: The message to display write out prior to waiting for the command.
    @type  command: ApiCommand
    @param command: The command to wait for.
    """
    write_to_stdout(msg)

    cmd_wait = CommandWait(command)
    cmd_wait.start()

    while cmd_wait.is_alive():
        cmd_wait.join(15.0)
        write_to_stdout('.')

    write_to_stdout(" Done.\n")


def write_to_stdout(msg):
    """
    Utility command to write to stdout and immediately flush.

    @type  msg: str
    @param msg: The message to write to stdout.
    """
    sys.stdout.write(msg)
    sys.stdout.flush()

def result_is_false(result):
    """
    Returns True if we should retry, False otherwise.

    @type  result: The result to test against
    @param result: bool
    @return: True if we should retry, False, otherwise.
    """
    return result is False

@retry(retry_on_result=result_is_false, wait_fixed=10000, stop_max_delay=600000)
def wait_for_good_health(api, cluster_name):
    """
    Validates the health of the cluster.  Will retry for several minutes waiting for the health
    to become GOOD.

    @type  api:          ApiClient
    @param api:          An ApiClient used to query the current health state of the cluster
    @type  cluster_name: str
    @param cluster_name: The name of the cluster.
    """
    return check_health(api, cluster_name)

def check_health(api, cluster_name):
    """
    Validates the health of the cluster.

    @type  api:          ApiClient
    @param api:          An ApiClient used to query the current health state of the cluster
    @type  cluster_name: str
    @param cluster_name: The name of the cluster.
    """
    services = api.get_cluster(cluster_name).get_all_services()

    for service in services:
        if service.serviceState != 'STARTED':
            write_to_stdout(service.name + " state is " + service.serviceState +". Expected STARTED\n")
            return False
        if service.healthSummary != 'GOOD':
            write_to_stdout(service.name + " health is " + service.healthSummary +". Expected GOOD\n")
            return False

    return True

def validate_cluster(api, cluster_name):
    """
    Validates that cluster satisfies preconditions for enabling HDFS HA

    @type  api:          ApiClient
    @param api:          An ApiClient used to query the current health state of the cluster
    @type  cluster_name: str
    @param cluster_name: The name of the cluster.
    """
    cluster = api.get_cluster(cluster_name)
    services = cluster.get_all_services()

    hdfs = None
    for service in services:
        if service.type == 'HDFS':
            hdfs = service
            break
    else:
        write_to_stdout("No HDFS Service found")
        return False

    valid = True
    nn = 0
    snn = 0
    jn = 0
    for role in hdfs.get_all_roles():
        if role.type == 'NAMENODE':
            nn += 1
        elif role.type == 'SECONDARYNAMENODE':
            snn += 1
        elif role.type == 'JOURNALNODE':
            jn += 1

    if nn != 1:
        write_to_stdout("Expected 1 NAMENODE. Found "+str(nn))
        valid = False
    if snn != 1:
        write_to_stdout("Expected 1 SECONDARYNAMENODE. Found "+str(snn))
        valid = False
    if jn < 3:
        write_to_stdout("Expected 3 or more JOURNALNODE. Found "+str(jn))
        valid = False

    hue = find_service_by_type(cluster, 'HUE')
    if hue != None:
        httpfs = find_role_by_type(hdfs, 'HTTPFS')
        if httpfs == None:
            write_to_stdout("Expected an HTTPFS role if HUE service is present")
            valid = False

    return valid

def find_service_by_type(cluster, service_type):
    """
    Finds and returns service of the given type

    @type   cluster: ApiCluster
    @param  cluster: The cluster whose services are checked
    @type   service_type: str
    @param  service_type: the service type to look for
    @return ApiService or None if not found
    """
    for service in cluster.get_all_services():
        if service.type == service_type:
            return service
    return None

def find_role_by_type(service, role_type):
    """
    Finds and returns role of the given type

    @type   service: ApiService
    @param  service: The service whose roles are checked
    @type   role_type: str
    @param  role_type: the role type to look for
    @return ApiRole or None if not found
    """
    for role in service.get_all_roles():
        if role.type == role_type:
            return role
    return None

def invoke_hdfs_enable_nn_ha(cluster, nameservice):
    """
    Invokes the hdfsEnableNnHa command on the given cluster

    @type   cluster: ApiCluster
    @param  cluster: The cluster on which to enable HDFS HA
    @type   nameservice: str
    @param  nameservice: the nameservice for the HDFS NameNodes
    """
    hdfs = find_service_by_type(cluster, 'HDFS')
    if hdfs == None:
        write_to_stdout("No HDFS Service found")
        return

    nn = find_role_by_type(hdfs, 'NAMENODE')
    if nn == None:
        write_to_stdout("No NAMENODE Role found")
        return
    active_nn_name = nn.name

    snn = find_role_by_type(hdfs, 'SECONDARYNAMENODE')
    if snn == None:
        write_to_stdout("No SECONDARYNAMENODE Role found")
        return
    standby_nn_host_id = snn.hostRef.hostId

    wait_for_command('Enabling HDFS HA', hdfs.enable_nn_ha(active_nn_name, standby_nn_host_id, nameservice, []))

def update_hive_for_ha_hdfs(cluster):
    """
    Updates the Hive Metastore Namenodes

    @type   cluster: ApiCluster
    @param  cluster: The cluster on which to update HIVE
    """
    hive = find_service_by_type(cluster, 'HIVE')
    if hive == None:
        # nothing to do here
        return
    wait_for_command('Stopping HIVE', hive.stop())
    wait_for_command('Updating Hive Metastore Namenodes', hive.update_metastore_namenodes())
    wait_for_command('Starting HIVE', hive.start())

    # restart impala to invalidate any queries
    restart_impala(cluster)

def restart_impala(cluster):
    """
    Restarts the Impala service

    @type   cluster: ApiCluster
    @param  cluster: The cluster on which to restart Impala
    """
    impala = find_service_by_type(cluster, 'IMPALA')
    if impala == None:
        # nothing to do here
        return
    wait_for_command('Restarting Impala', impala.restart())

def main():
    """
    Enables HDFS HA on a cluster.

    @rtype:   number
    @returns: A number representing the status of success.
    """
    settings = retrieve_args()

    api = ApiResource(settings.host, settings.port, settings.username, settings.password,
                      version=6)

    if not validate_cluster(api, settings.cluster):
        write_to_stdout("Cluster does not satisfy preconditions for enabling HDFS HA. Exiting!")
        return 1

    if settings.wait_for_good_health:
        write_to_stdout("Waiting for GOOD health... ")
        if not wait_for_good_health(api, settings.cluster):
            write_to_stdout("Cluster health is not GOOD.  Exiting!\n")
            return 1
    else:
        write_to_stdout("Checking cluster health... ")
        if not check_health(api, settings.cluster):
            write_to_stdout("Cluster health is not GOOD.  Exiting!\n")

    write_to_stdout("Cluster health is GOOD!\n")

    cluster = api.get_cluster(settings.cluster)

    invoke_hdfs_enable_nn_ha(cluster, settings.nameservice)
    update_hive_for_ha_hdfs(cluster)

    # Restarting the MGMT services to make sure the HDFS file browser functions
    # as expected.
    cloudera_manager = api.get_cloudera_manager()
    mgmt_service = cloudera_manager.get_service()
    wait_for_command('Restarting MGMT services', mgmt_service.restart())

    return 0

if __name__ == '__main__':
    sys.exit(main())
