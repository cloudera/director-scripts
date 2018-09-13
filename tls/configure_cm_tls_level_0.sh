#!/usr/bin/env bash

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

DEFAULT_VERBOSE=0
DEFAULT_PKI_HOME=/opt/cloudera/security/pki
DEFAULT_BASE_DN="OU=MyOrgUnit,O=MyOrg,L=MyLocation,ST=ZZ,C=US"
DEFAULT_KEY_SIZE=4096
DEFAULT_KEY_PASSWORD=cloudera

usage() {
  cat << EOF
usage: $0 options

This script configures a Cloudera Manager installation for TLS level 0, with
the following changes:

* a self-signed server certificate is put into place (it can be replaced later
  with a signed one)
* the IP address of this host is included as a subject alternative name (SAN)
  on the certificate
* the hostname of this host is included as a subject alternative name on the
  certificate

Run this script on the host where Cloudera Manager is installed, under a user
account that has passwordless sudo access.

OPTIONS:
  -b base-DN    base DN for server certificate
                (default $DEFAULT_BASE_DN)
  -d directory  PKI home directory where keys and certificates are stored
                (default $DEFAULT_PKI_HOME)
  -k size       Private key size in bits
                (default $DEFAULT_KEY_SIZE)
  -p password   Password for generated key pair
                (default $DEFAULT_KEY_PASSWORD)
  -v            Be verbose, emitting status and instructions
                (default is to be mostly quiet)
  -h            Shows this help message
EOF
}

PKI_HOME="$DEFAULT_PKI_HOME"
BASE_DN="$DEFAULT_BASE_DN"
KEY_SIZE="$DEFAULT_KEY_SIZE"
KEY_PASSWORD="$DEFAULT_KEY_PASSWORD"
VERBOSE="$DEFAULT_VERBOSE"

while getopts "b:d:k:p:vh" opt
do
  case $opt in
    h)
      usage
      exit 0
      ;;
    b)
      BASE_DN="$OPTARG"
      ;;
    d)
      PKI_HOME="$OPTARG"
      ;;
    k)
      KEY_SIZE="$OPTARG"
      ;;
    p)
      KEY_PASSWORD="$OPTARG"
      ;;
    v)
      VERBOSE=1
      ;;
    ?)
      usage
      exit
      ;;
  esac
done
shift $((OPTIND - 1))

echo_v() {
  [[ $VERBOSE == "1" ]] && echo "$*"
}

echo_v "Configuring TLS level 0 ..."

if [[ -z $JAVA_HOME ]]; then
  JAVA_HOME=/usr/java/jdk1.7.0_67-cloudera # usually works for CM 5
fi
if [[ ! -d $JAVA_HOME ]]; then
  echo "JAVA_HOME not found at $JAVA_HOME"
  exit 1
fi
HOSTNAME="$(hostname -f)"
IP_ADDRESS="$(hostname -I)"
# hostname -I has a trailing space ...
IP_ADDRESS="${IP_ADDRESS// /}"

if [[ -d $PKI_HOME ]]; then
  echo "Refusing to work with existing directory $PKI_HOME"
  exit 1
fi

# Create the PKI home directory
sudo mkdir -p "${PKI_HOME}"
sudo chown -R cloudera-scm:cloudera-scm "${PKI_HOME}"
sudo chmod 700 "${PKI_HOME}"

# Create the jssecacerts file
sudo cp "${JAVA_HOME}/jre/lib/security/cacerts" "${JAVA_HOME}/jre/lib/security/jssecacerts"

# Generate a key pair into a new keystore
# Includes -ext for IP address as SAN
sudo "${JAVA_HOME}/bin/keytool" -genkeypair -alias "${HOSTNAME}-server" -keyalg RSA \
  -keystore "${PKI_HOME}/${HOSTNAME}-server.jks" \
  -keysize "${KEY_SIZE}" -dname "CN=${HOSTNAME},${BASE_DN}" \
  -ext "san=ip:${IP_ADDRESS},dns:${HOSTNAME}"\
  -storepass "${KEY_PASSWORD}" -keypass "${KEY_PASSWORD}"
echo_v "✔ Created keystore ${PKI_HOME}/${HOSTNAME}-server.jks"
echo_v "Go to http://${IP_ADDRESS}:7180/cmf/settings#filterdisplayGroup=Security:"
echo_v "  check \"Use TLS Encryption for Admin Console\""
echo_v "  set \"Cloudera Manager TLS/SSL Server JKS Keystore File Location\" to:"
echo_v "    ${PKI_HOME}/${HOSTNAME}-server.jks"
echo_v "  set \"Cloudera Manager TLS/SSL Server JKS Keystore File Password\" to:"
echo_v "    ${KEY_PASSWORD}"
echo_v "and then Save Changes"
echo_v

# Export an X.509 cerfificate for the new public key
sudo "${JAVA_HOME}/bin/keytool" -exportcert -rfc \
  -keystore "${PKI_HOME}/${HOSTNAME}-server.jks" -alias "${HOSTNAME}-server" \
  -file "${PKI_HOME}/${HOSTNAME}-server.crt" -storepass "${KEY_PASSWORD}" -keypass "${KEY_PASSWORD}"
echo_v "✔ Exported server certificate to ${PKI_HOME}/${HOSTNAME}-server.crt"

# Add the certificate to jssecacerts
sudo "${JAVA_HOME}/bin/keytool" -importcert -alias mycmcert \
  -keystore "${JAVA_HOME}/jre/lib/security/jssecacerts" \
  -file "${PKI_HOME}/${HOSTNAME}-server.crt" -storepass changeit -noprompt
echo_v "✔ Imported server certificate to ${JAVA_HOME}/jre/lib/security/jssecacerts"
echo_v "Go to http://${IP_ADDRESS}:7180/cmf/services/1/config#filtercategory=MGMT+(Service-Wide)&filterdisplayGroup=Security:"
echo_v "  set \"TLS/SSL Client Truststore File Location\" to:"
echo_v "    ${JAVA_HOME}/jre/lib/security/jssecacerts"
echo_v "  set \"Cloudera Manager Server TLS/SSL Certificate Trust Store Password\" to:"
echo_v "    changeit"
echo_v "and then Save Changes"
echo_v

echo_v "After changing CM configs:"
echo_v "  run: sudo service cloudera-scm-server restart"
echo_v "  go to https://${IP_ADDRESS}:7183/cmf/services/1/status and "
echo_v "    accept the self-signed server certificate"
echo_v "    restart the management services"
echo_v

echo_v "Certificate contents for updating Cloudera Altus Director:"
echo_v
[[ $VERBOSE == "1" ]] && sudo cat "${PKI_HOME}/${HOSTNAME}-server.crt"
