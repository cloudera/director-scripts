#!/usr/bin/env bash
#
# (c) Copyright 2016 Cloudera, Inc.
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

case $JAVA_VERSION in
  1.7)
    # Package name for RPM available from Cloudera Manager repo
    JAVA_PACKAGE=oracle-j2sdk1.7
    JAVA_PREFIX="/usr/java/jdk1.7"
    POLICY_ZIP="UnlimitedJCEPolicyJDK7.zip"
    ;;
  1.8)
    # Package name for RPM available from Cloudera Director repo
    JAVA_PACKAGE=oracle-j2sdk1.8
    JAVA_PREFIX="/usr/java/jdk1.8"
    POLICY_ZIP="jce_policy-8.zip"
    ;;
  *)
    JAVA_PACKAGE=unknown
    echo "Java package for version $JAVA_VERSION unknown"
    echo "Skipping installation of JCE unlimited strength policy files"
    ;;
esac
POLICY_ZIP_PATH="/tmp/$POLICY_ZIP"

if [[ $JAVA_PACKAGE != "unknown" && -f $POLICY_ZIP_PATH ]]; then
  echo "Installing unzip"
  sudo yum -y install unzip
  echo "Installing JCE unlimited strength policy files from $POLICY_ZIP_PATH"
  LOC=$(sudo rpm -ql $JAVA_PACKAGE | grep "$JAVA_PREFIX" | sort | head -n 1)
  echo "Determined JDK location: $LOC"
  # ZIP files from Oracle have directory within; ignore with -j
  sudo unzip -j -o "$POLICY_ZIP_PATH" -d "$LOC/jre/lib/security/"
fi
