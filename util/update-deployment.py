#! /usr/bin/env python

# Copyright (c) 2015 Cloudera, Inc.
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

# Simple script for changing the Cloudera Manager password that Director
# is using to connect to the API and perform various actions

import argparse
import sys
import urllib2

from urllib2 import HTTPError

from cloudera.director.latest.models import Login

from cloudera.director.common.client import ApiClient
from cloudera.director.latest import AuthenticationApi, DeploymentsApi

def get_authenticated_client(args):
    """
    Create a new API client and authenticate against a server as admin

    @param args: dict of parsed command line arguments that
                 include server host and admin credentials

    @rtype:      ApiClient
    @return:     authenticated API client
    """

    # Start by creating a client pointing to the right server
    client = ApiClient(args.server)

    # Authenticate. This will start a session and store the cookie
    auth = AuthenticationApi(client)
    auth.login(Login(username=args.admin_username, password=args.admin_password))

    return client

def main():

    parser = argparse.ArgumentParser(prog='change-deployment-password.py')

    parser.add_argument('--admin-username', default='admin',
                        help='Name of a user with administrative access to Cloudera Director (defaults to %(default)s)')
    parser.add_argument('--admin-password', default='admin',
                        help='Password for the administrative user (defaults to %(default)s)')
    parser.add_argument('--server', default='http://localhost:7189',
                        help="Cloudera Director server URL (defaults to %(default)s)")

    parser.add_argument('--debug', default=False, action='store_true',
                        help="Whether to provide additional debugging output (defaults to %(default)s)")

    parser.add_argument('--environment', help='Environment name', required=True)
    parser.add_argument('--deployment', help='Deployment name (Cloudera Manager instance)', required=True)
    parser.add_argument('--deployment-username', help='Cloudera Manager new username', default=None)
    parser.add_argument('--deployment-password', help='Cloudera Manager new password', default=None)

    args = parser.parse_args()

    if args.debug:
        # Enable HTTP request logging to help with debugging
        h = urllib2.HTTPHandler(debuglevel=1)
        opener = urllib2.build_opener(h)
        urllib2.install_opener(opener)

    client = get_authenticated_client(args)

    api = DeploymentsApi(client)
    template = api.getTemplateRedacted(args.environment, args.deployment)

    if template.port == 0:
        template.port = None

    if args.deployment_username:
        print "Changing username from: '%s' to: '%s'" % (template.username, args.deployment_username)
        template.username = args.deployment_username
    else:
        print "The deployment username is not changing: '%s'" % template.username

    if args.deployment_password:
        print "Changing password to: '%s'" % (args.deployment_password)
        template.password = args.deployment_password
    else:
        print "Deployment password is not changing"

    if args.deployment_username or args.deployment_password:
        api.update(args.environment, args.deployment, template)
        print 'Done'

    else:
        print 'Nothing to do'

    return 0

if __name__ == '__main__':
    try:
        sys.exit(main())

    except HTTPError as e:
        print e.read()
        raise e
