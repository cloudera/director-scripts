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

# Install ntp, curl, nscd, screen, and python
sudo yum -y install ntp curl nscd screen python

# Configure the Cloudera Manager repository
echo "Configuring CM repository at $CM_REPOSITORY_URL"
sudo sh -c "curl ${CM_REPOSITORY_URL}/cloudera-manager.repo > /etc/yum.repos.d/cloudera-manager.repo"
sudo rpm --import "${CM_REPOSITORY_URL}/RPM-GPG-KEY-cloudera"
echo "Installing Oracle JDK and CM"
sudo yum -y install jdk oracle-j2sdk1.7 cloudera-manager-agent cloudera-manager-daemons cloudera-manager-server cloudera-manager-server-db-2

# Cloudera Manager needs ntp to work properly
sudo chkconfig ntpd on
sudo chkconfig nscd on

# Disable the automatic starting of Cloudera Manager. Director will handle this.
sudo chkconfig cloudera-scm-agent off
sudo chkconfig cloudera-scm-server off
sudo chkconfig cloudera-scm-server-db off

if [ -f /etc/selinux/config ]; then
    # Disable SELinux, as it doesn't play nicely with Cloudera Manager
    sudo sed -e 's/^SELINUX=enforcing/SELINUX=disabled/' -i /etc/selinux/config
    sudo sed -e 's/^SELINUX=permissive/SELINUX=disabled/' -i /etc/selinux/config
    sudo setenforce 0
fi

# Make sure iptables is disabled so that we can properly access Cloudera Manager
sudo chkconfig iptables off

exit 0
