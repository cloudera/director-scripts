#!/usr/bin/python
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
from cm_api.api_client import API_CURRENT_VERSION
from cm_api.endpoints.types import ApiCommand
from threading import Thread
from urlparse import urlparse
import argparse
import os
import sys
import time


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
        args = namedtuple("args", ["host", "port", "username", "password", "cluster", "use_tls"])

        parsed_url = os.environ["DEPLOYMENT_HOST_PORT"].split(":")
        args.host = parsed_url[0]
        args.port = int(parsed_url[1])
        args.username = os.environ["CM_USERNAME"]
        args.password = os.environ["CM_PASSWORD"]
        args.cluster = os.environ["CLUSTER_NAME"]
        args.use_tls = False

        return args
    else:
        return parse_args()


def parse_args():
    """
    Parses host and cluster information from the given command line arguments.

    @rtype:  namespace
    @return: The parsed arguments.
    """
    parser = argparse.ArgumentParser(description="Kerberizes an existing KDC aware Cluster",
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('host', metavar='HOST', type=str, help="The Cloudera Manager host")
    parser.add_argument('cluster', metavar='CLUSTER', type=str,
                        help="The name of the cluster to kerberize")
    parser.add_argument('--port', metavar='port', type=int, default=7180,
                        help="Cloudera Manager's port.")
    parser.add_argument('--username', metavar='USERNAME', type=str, default='admin',
                        help="The username to log into Cloudera Manager with.")
    parser.add_argument('--password', metavar='PASSWORD', type=str, default='admin',
                        help="The password to log into Cloudera Manager with.")
    parser.add_argument('--use-tls', action='store_true',
                        help="Whether to use TLS to connect to Cloudera Manager.")
    return parser.parse_args()


def verify_cloudera_manager_has_kerberos_principal(cloudera_manager):
    """
    Configures the various CM services to utilize Kerberos.

    @type  cloudera_manager: ClouderaManager
    @param cloudera_manager: The ClouderaManager instance.
    """
    cm_configs = cloudera_manager.get_config()

    # If the KDC host and security realm are set, this is a good indicator that the Kerberos
    # adminstrative principal has been imported.
    if 'KDC_HOST' in cm_configs and 'SECURITY_REALM' in cm_configs:
        return True

    return False


def configure_services(cluster):
    """
    Configures the various CM services to utilize Kerberos.

    @type  cluster: ApiCluster
    @param cluster: The cluster to configure.
    """
    services = cluster.get_all_services()

    for service in services:
        service_type = service.type
        if service_type == 'HDFS':
            print "Configuring HDFS for Kerberos."
            service.update_config(
                {'hadoop_security_authentication': 'kerberos',
                 'hadoop_security_authorization': 'true'}
            )

            role_cfgs = service.get_all_role_config_groups()

            for role_cfg in role_cfgs:
                if role_cfg.roleType == 'DATANODE':
                    role_cfg.update_config(
                        {'dfs_datanode_port': '1004',
                         'dfs_datanode_http_port': '1006',
                         'dfs_datanode_data_dir_perm': '700'}
                    )
        elif service_type == 'HBASE':
            print "Configuring HBase for Kerberos."
            service.update_config(
                {'hbase_security_authentication': 'kerberos',
                 'hbase_security_authorization': 'true'}
            )
        elif service_type == 'ZOOKEEPER':
            print "Configuring ZooKeeper for Kerberos."
            service.update_config(
                {'enableSecurity': 'true'}
            )
        elif service_type == 'SOLR':
            print "Configuring Solr for Kerberos."
            service.update_config(
                {'solr_security_authentication': 'kerberos'}
            )
        elif service_type == 'KS_INDEXER':
            # API version 10 came out with CM 5.4, which is necessary to make this configuration
            # change.
            if API_CURRENT_VERSION >= 10:
                print "Configuring KeyStoreIndexer for Kerberos."
                service.update_config(
                    {'hbase_indexer_security_authentication': 'kerberos'}
                )
        elif service_type == 'HUE':
            kt_renewer_role = service.get_roles_by_type('KT_RENEWER')
            hue_server_role = service.get_roles_by_type('HUE_SERVER')

            if hue_server_role and not kt_renewer_role:
                print "Configuring Hue for Kerberos."
                service.create_role('KT_RENEWER-1', 'KT_RENEWER',
                                    hue_server_role[0].hostRef.hostId)

def wait_for_generate_credentials(cloudera_manager):
    """
    Finds the GenerateCredentials command and waits for it to complete

    @type  cloudera_manager: ClouderaManager
    @param cloudera_manager: The ClouderaManager instance.
    """
    generate_commands = None
    num_tries = 3

    for i in range(0, num_tries):
        generate_commands = find_command_by_name(cloudera_manager, 'GenerateCredentials')

        # If the list is full
        if generate_commands:
            break

        # Couldn't find the command, so sleep 5 seconds and try again
        time.sleep(5)

    # It's possible that multiple GenerateCredentials commands are generated during
    # service configuration. We should wait for all of them.
    if generate_commands:
        for generate_command in generate_commands:
            wait_for_command('Waiting for Generate Credentials', generate_command)


def find_command_by_name(cloudera_manager, name):
    """
    Finds a running command by name

    @type  cloudera_manager: ClouderaManager
    @param cloudera_manager: The ClouderaManager instance.
    @type  name: str
    @param name: The name of the command to find
    @rtype:  ApiCommand
    @return: The command to return
    """
    commands = cloudera_manager.get_commands('full')
    found_commands = [command for command in commands if command.name == name]

    return found_commands


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
        cmd_wait.join(5.0)
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


def main():
    """
    Kerberizes a cluster.

    @rtype:   number
    @returns: A number representing the status of success.
    """
    settings = retrieve_args()

    api = ApiResource(settings.host, settings.port, settings.username,
                      settings.password, settings.use_tls, 8)

    cloudera_manager = api.get_cloudera_manager()
    cluster = api.get_cluster(settings.cluster)
    mgmt_service = cloudera_manager.get_service()

    if verify_cloudera_manager_has_kerberos_principal(cloudera_manager):
        wait_for_command('Stopping the cluster', cluster.stop())
        wait_for_command('Stopping MGMT services', mgmt_service.stop())
        configure_services(cluster)
        wait_for_generate_credentials(cloudera_manager)
        wait_for_command('Deploying client configs.', cluster.deploy_client_config())
        wait_for_command('Deploying cluster client configs', cluster.deploy_cluster_client_config())
        wait_for_command('Starting MGMT services', mgmt_service.start())
        wait_for_command('Starting the cluster', cluster.start())
    else:
        print "Cluster does not have Kerberos admin credentials.  Exiting!"

    return 0

if __name__ == '__main__':
    sys.exit(main())
