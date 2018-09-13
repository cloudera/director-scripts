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
  1.8)
    # Package name for RPM available from Cloudera Altus Director repo
    director_ver=$(basename "${JDK_REPOSITORY_URL}") # works for RHEL
    if [[ $(echo "$director_ver >= 2.4" | bc) -eq 1 ]]; then
      JAVA_PACKAGE=oracle-j2sdk1.8
    else
      JAVA_PACKAGE=jdk1.8.0_60
    fi
    JAVA_PREFIX="/usr/java/jdk1.8"
    POLICY_ZIP="jce_policy-8.zip"
    ;;
  1.7)
    # Package name for RPM available from Cloudera Manager or Cloudera Altus Director repo
    JAVA_PACKAGE=oracle-j2sdk1.7
    JAVA_PREFIX="/usr/java/jdk1.7"
    POLICY_ZIP="UnlimitedJCEPolicyJDK7.zip"
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
  if [[ -z $LOC ]]; then
    echo "Failed to locate JDK! Looked for Java package ${JAVA_PACKAGE}, is it available?"
    exit 1
  fi
  echo "Determined JDK location: $LOC"
  # ZIP files from Oracle have directory within; ignore with -j
  sudo unzip -j -o "$POLICY_ZIP_PATH" -d "$LOC/jre/lib/security/"
fi
