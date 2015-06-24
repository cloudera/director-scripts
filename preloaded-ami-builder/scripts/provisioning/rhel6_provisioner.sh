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

# Install ntp, curl, and nscd
sudo yum -y install ntp curl nscd

# Cloudera Manager needs ntp to work properly
sudo chkconfig ntpd on
sudo chkconfig nscd on

if [ -f /etc/selinux/config ]; then
    # Disable SELinux, as it doesn't play nicely with Cloudera Manager
    sudo sed -e 's/^SELINUX=enforcing/SELINUX=disabled/' -i /etc/selinux/config
    sudo sed -e 's/^SELINUX=permissive/SELINUX=disabled/' -i /etc/selinux/config
    sudo setenforce 0
fi

# Make sure iptables is disabled so that we can properly access Cloudera Manager
sudo chkconfig iptables off

exit 0
