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

# Since service_control.sh was sourced, USE_SYSTEMCTL is set
if [[ $USE_SYSTEMCTL == 1 ]]; then
  echo "CM optimization not yet supported under systemd"
  echo "Please do so in an instance template bootstrap script"
else

  # Start/Stop Cloudera Manager service
  echo "Starting Cloudera Manager services"
  service_control cloudera-scm-server-db start
  service_control cloudera-scm-server start

  echo "Waiting for 5 minutes for Cloudera Manager to start successfully"
  n=10
  while (( n > 0 ))
  do
    curl http://localhost:7180 &> /dev/null && break
    n=$((n-1))
    sleep 30
  done
  if (( n == 0 )); then
      echo "Timed out waiting for Cloudera Manager to start"
  else
      echo "Cloudera Manager started successfully"
  fi

  # Prepare init script to reset CM UUID on restart
  echo "Preparing init script to reset Cloudera Manager UUID"
  sudo mkdir -p /etc/cloudera-scm-server/

  cm_uuid_reset_file=/etc/init.d/cm-uuid-reset-$(uuidgen)
  sudo bash <<SEOF
cat > "$cm_uuid_reset_file" <<"EOF"
#!/usr/bin/env bash
# (c) Copyright 2016 Cloudera, Inc
#
# init script to reset Cloudera SCM Server UUID
#
# chkconfig: 2345 90 10
# description: Reset Cloudera SCM Server UUID

echo "Resetting Cloudera SCM Server UUID"
echo \$(uuidgen) > /etc/cloudera-scm-server/uuid
chkconfig --del $cm_uuid_reset_file
rm -- $cm_uuid_reset_file
exit 0
EOF
SEOF

  sudo chmod 755 "$cm_uuid_reset_file"
  sudo chkconfig --add "$cm_uuid_reset_file"
fi

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
