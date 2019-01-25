#! /usr/bin/env python

# Copyright (c) 2018 Cloudera, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import sys
from urllib2 import HTTPError

from cloudera.director.common.client import ApiClient, Configuration
from cloudera.director.latest import DeploymentsApi

def get_authenticated_client(args):
    """
    Create a new API client and authenticate against a server as admin

    @param args: dict of parsed command line arguments that
                 include server host and admin credentials
    @rtype:      ApiClient
    @return:     authenticated API client
    """

    configuration = Configuration()
    configuration.host = args.server
    configuration.username = args.admin_username
    configuration.password = args.admin_password
    configuration.ssl_ca_cert = args.cafile

    return ApiClient(configuration=configuration)

def get_deployment_template(client, env_name, dep_name):
    """
    Get a deployment template.

    @param client: Director API client
    @param env_name: environment name
    @param dep_name: deployment name
    @rtype: DeploymentTemplate
    @return: deployment template
    """
    api = DeploymentsApi(client)
    try:
        return api.get_template_redacted(env_name, dep_name)
    except HTTPError as error:
        if error.code == 404:
            print 'Error: the deployment %s does not exist in the environment %s' % (env_name, dep_name)
        else:
            raise error

def enable_tls_for(template, port, trusted_cert_file):
    """
    Change a deployment template to enable TLS communications.

    @param template: deployment template
    @param port: listening port for Cloudera Manager with TLS enabled
    @param trusted_cert_file: file-like object for trusted certificate
    @rtype: DeploymentTemplate
    @return: updated deployment template
    """
    if template.tls_enabled:
        raise Exception('Error: the deployment %s already has TLS enabled' % template.name)
    template.tls_enabled = True
    template.port = port
    if trusted_cert_file:
        cert_contents = trusted_cert_file.read()
        template.trusted_certificate = cert_contents
    return template

def disable_tls_for(template, port):
    """
    Change a deployment template to disable TLS communications.

    @param template: deployment template
    @param port: listening port for Cloudera Manager with TLS disabled
    @rtype: DeploymentTemplate
    @return: updated deployment template
    """
    if not template.tls_enabled:
        raise Exception('Error: the deployment %s already has TLS disabled' % template.name)
    template.tls_enabled = False
    template.port = port
    template.trusted_certificate = None
    return template

def update_deployment_template(client, env_name, dep_name, template):
    """
    Update a deployment template.

    @param client: Director API client
    @param env_name: environment name
    @param dep_name: deployment name
    @param template: updated deployment template
    """
    api = DeploymentsApi(client)
    api.update(env_name, dep_name, template)

def main():
    """
    Main method.
    """
    parser = argparse.ArgumentParser(description='Update TLS communications to a Director ' +
                                     'deployment')

    parser.add_argument('--admin-username', default="admin",
                        help='Name of an user with administrative access (defaults to %(default)s)')
    parser.add_argument('--admin-password', default="admin",
                        help='Password for the administrative user (defaults to %(default)s)')
    parser.add_argument('--server', default="http://localhost:7189",
                        help="Cloudera Altus Director server URL (defaults to %(default)s)")
    parser.add_argument('--cafile', default=None,
                        help='Path to file containing trusted certificate(s) for Cloudera Altus Director ' +
                        '(defaults to %(default)s); required when Cloudera Altus Director is ' +
                        'configured for https')
    parser.add_argument('--disable', action='store_true',
                        help='Disable TLS communication instead of enabling it')
    parser.add_argument('--trusted-cert-file', type=file, default=None,
                        help='Path to file containing trusted certificate for Cloudera Manager ' +
                        '(defaults to %(default)s); optionally include when enabling TLS')

    parser.add_argument('env_name',
                        help="Name of environment containing deployment with TLS enabled")
    parser.add_argument('dep_name', help="Name of deployment with TLS enabled")
    parser.add_argument('port', type=int, help="Cloudera Manager port")

    args = parser.parse_args()

    if args.disable and args.trusted_cert_file:
        raise Exception('When disabling TLS communication, do not pass a trusted certificate ' +
                        'for Cloudera Manager')

    if args.disable:
        progress_action = 'Disabling'
        completed_state = 'disabled'
    else:
        progress_action = 'Enabling'
        completed_state = 'enabled'
    print '%s TLS communications for deployment %s ...' % (progress_action, args.dep_name)

    client = get_authenticated_client(args)
    template = get_deployment_template(client, args.env_name, args.dep_name)
    if args.disable:
        template = disable_tls_for(template, args.port)
    else:
        template = enable_tls_for(template, args.port, args.trusted_cert_file)
    update_deployment_template(client, args.env_name, args.dep_name, template)

    print 'TLS communications for deployment %s is %s.' % (args.dep_name, completed_state)

if __name__ == '__main__':
    try:
        sys.exit(main())

    except HTTPError as error:
        print error.read()
        raise error
