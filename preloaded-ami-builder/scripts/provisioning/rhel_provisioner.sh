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

CM_GPG_KEY=${CM_GPG_KEY:-https://archive.cloudera.com/cm5/redhat/6/x86_64/cm/RPM-GPG-KEY-cloudera}

# Install ntp, curl, nscd, screen, and python
sudo yum -y install ntp curl nscd screen python

# Configure the Cloudera Manager repository
echo "Configuring CM repository at $CM_REPOSITORY_URL"
sudo tee /etc/yum.repos.d/cloudera-manager.repo > /dev/null <<REPO
[cloudera-manager]
name=Cloudera Manager
baseurl=${CM_REPOSITORY_URL}
gpgKey=${CM_GPG_KEY}
gpgcheck=1
REPO
sudo rpm --import "${CM_GPG_KEY}"
echo "Installing Oracle JDK and CM"
sudo yum -y install "oracle-j2sdk${JAVA_VERSION}" cloudera-manager-agent cloudera-manager-daemons cloudera-manager-server cloudera-manager-server-db-2

# Define service_control
. /tmp/service_control.sh

# Cloudera Manager needs ntp (either via ntpd or chronyd) to work properly
echo "Enabling ntpd / chronyd and nscd"
if hash chronyc 2>/dev/null; then
  service_control chronyd enable
else
  service_control ntpd enable
fi
service_control nscd enable

if [ -f /etc/selinux/config ]; then
  # Disable SELinux, as it doesn't play nicely with Cloudera Manager
  echo "Disabling SELinux"
  sudo sed -e 's/^SELINUX=enforcing/SELINUX=disabled/' -i /etc/selinux/config
  sudo sed -e 's/^SELINUX=permissive/SELINUX=disabled/' -i /etc/selinux/config
  sudo setenforce 0
fi

# Make sure iptables / firewalld is disabled so that we can properly access Cloudera Manager
echo "Disabling iptables / firewalld"
service_control iptables disable
if hash firewall-cmd 2>/dev/null; then
  service_control firewalld stop
fi

# Disable the automatic starting of Cloudera Manager. Director will handle this.
echo "Disabling Cloudera Manager"
service_control cloudera-scm-agent disable
service_control cloudera-scm-server disable
service_control cloudera-scm-server-db disable

exit 0
