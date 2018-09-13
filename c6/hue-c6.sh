#!/usr/bin/env bash
#
# (c) Copyright 2018 Cloudera, Inc.
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

# Change this to the expected operating system version:
# - rhel6.x
# - centos6.x
# - rhel7.x
# - centos7.x
OS=${OS:-centos7.x}

function install_python27 {

  # Install Python 2.7 for the Hue server
  case $OS in
    centos6.*)
      yum install -y centos-release-scl
      yum install -y scl-utils
      yum install -y python27
      if ! scl -l | grep -q python27; then
        echo Failed to install Python 2.7 via SCL
        exit 1
      fi
      ;;
    rhel6.*)
      yum install -y scl-utils
      # for EC2 instances
      yum-config-manager --enable rhui-REGION-rhel-server-rhscl
      # for Azure VMs
      yum-config-manager --enable rhui-rhel-server-rhscl-6-rhui-rpms
      yum install -y python27
      if ! scl -l | grep -q python27; then
        echo Failed to install Python 2.7 via SCL
        exit 1
      fi
      ;;
    *) # centos7.*|rhel7.*
      # Assume that the default Python package is 2.7
      yum install -y python
      ;;
  esac
}

function install_psycopg2 {

  # Install epel-release for RHEL/CentOS 7 in order to install pip
  if [[ $OS =~ rhel7.* ]]; then
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  elif [[ $OS =~ centos7.* ]]; then
    yum install -y epel-release
  fi

  # Install psycopg2 for the Hue server
  case $OS in
    centos6.*|rhel6.*)
      yum install -y postgresql-devel gcc*
      if ! scl enable python27 'pip install psycopg2==2.6.2'; then
        echo Failed to install psycopg2 2.6.2
        exit 1
      fi
      ;;
    *) # centos7.*|rhel7.*
      yum install -y python-pip
      if ! pip install psycopg2==2.7.5; then
        echo Failed to install psycopg 2.7.5
      fi
      ;;
  esac
}

function host_dummy_psycopg2_repo {

  # This creates a dummy python-psycopg2 RPM which will be hosted locally
  # through yum. This prevents Cloudera Manager agent package installation
  # (which depends on an older psycopg2 package) from overriding the pip
  # installation of psycopg2 accomplished here.

  WORKING_DIR=/etc/dummypsycopg2
  if ! mkdir -p "$WORKING_DIR"; then
    echo "Failed to create working directory $WORKING_DIR"
    exit 1
  fi

  case $OS in
    centos6.*|rhel6.*)
      RELEASE=el6
      ;;
    *) # centos7.*|rhel7.*
      RELEASE=el7
      ;;
  esac

  # First generate a dummy python-psycopg2 RPM

  RPM_SPEC_FILE=$WORKING_DIR/python-psycopg2.spec

  cat > $RPM_SPEC_FILE << EOF
Summary:    Dummy python-psycopg2 package
Name:       python-psycopg2
License:    n/a
Version:    2.5.1
Release:    3.${RELEASE}
BuildArch:  x86_64

%description
This is a dummy package for the python-psycopg2 package, created by Cloudera
Altus Director during cluster bootstrap. Starting with Cloudera Enterprise 6.0,
the Hue service requires a newer version of psycopg2 than the dependency
declared for the Cloudera Manager agent RPM package. The presence of this dummy
package ensures that the older version of psycopg2 is not installed during
Cloudera Manager agent installation, leaving the newer version available for
Hue and the agent.

%files
EOF

  yum install -y rpm-build
  RPM_BUILD_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t dummypsycopg2)"
  mkdir -p "${RPM_BUILD_DIR}/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}"

  rpmbuild -ba $RPM_SPEC_FILE
  GENERATED_RPM="$(find /root/rpmbuild/RPMS/ -name "python-psycopg2*.rpm" | head -n 1)"

  if [[ ! -f $GENERATED_RPM ]]; then
    echo "Failed to generate RPM file"
    exit 1
  fi

  # Next, create a local yum repo to host the dummy RPM

  LOCAL_REPO="$WORKING_DIR/repo"
  if ! mkdir -p $LOCAL_REPO; then
    echo "Failed to create local yum repo in $LOCAL_REPO for dummy psycopg2 package"
    exit 1
  fi
  cp "$GENERATED_RPM" "$LOCAL_REPO"

  yum install -y createrepo yum-plugin-priorities

  createrepo $LOCAL_REPO

  LOCAL_REPO_FILE=/etc/yum.repos.d/dummypsycopg2.repo
  cat > "$LOCAL_REPO_FILE" << EOF
[dummy-psycopg2-repo]
name=Repository for dummy psycopg2 package, installed by Cloudera Altus Director for C6 Hue
baseurl=file://${LOCAL_REPO}
enabled=1
gpgcheck=0
priority=1
EOF

  echo "Installed local yum repository with $LOCAL_REPO_FILE"
  echo "Future yum installations of python-psycopg2 will use a dummy package"
}

echo "Installing Python 2.7 and psycopg2 for os ${OS}"

install_python27
install_psycopg2
host_dummy_psycopg2_repo
