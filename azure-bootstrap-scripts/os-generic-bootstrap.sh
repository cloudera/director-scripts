#!/bin/sh

#
# Copyright (c) 2017 Cloudera, Inc.
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
#

#
# This script will bootstrap these OSes:
#   - CentOS 6
#   - CentOS 7
#   - RHEL 6
#   - RHEL 7
#
# Notes and notable differences between OSes:
#   - CentOS and RHEL 6 use dhclient
#   - CentOS and RHEL 7 use NetworkManager
#


#
# Functions
#

#
# CentOS and RHEL 6 use dhclient. Add a script to be automatically invoked when interface comes up.
# Function not indented so EOF works.
#
dhclient_6()
{
# dhclient-exit-hooks explained in dhclient-script man page: http://linux.die.net/man/8/dhclient-script
# cat a here-doc representation of the hooks to the appropriate file
cat > /etc/dhcp/dhclient-exit-hooks <<"EOF"
#!/bin/bash
printf "\ndhclient-exit-hooks running...\n\treason:%s\n\tinterface:%s\n" "${reason:?}" "${interface:?}"
# only execute on the primary nic
if [ "$interface" != "eth0" ]
then
    exit 0;
fi
# when we have a new IP, perform nsupdate
if [ "$reason" = BOUND ] || [ "$reason" = RENEW ] || [ "$reason" = REBIND ] || [ "$reason" = REBOOT ]
then
    printf "\tnew_ip_address:%s\n" "${new_ip_address:?}"
    host=$(hostname -s)
    domain=$(nslookup $(grep -i nameserver /etc/resolv.conf | cut -d ' ' -f 2) | grep -i name | cut -d ' ' -f 3 | cut -d '.' -f 2- | rev | cut -c 2- | rev)
    IFS='.' read -ra ipparts <<< "$new_ip_address"
    ptrrec="$(printf %s "$new_ip_address." | tac -s.)in-addr.arpa"
    nsupdatecmds=$(mktemp -t nsupdate.XXXXXXXXXX)
    resolvconfupdate=$(mktemp -t resolvconfupdate.XXXXXXXXXX)
    echo updating resolv.conf
    grep -iv "search" /etc/resolv.conf > "$resolvconfupdate"
    echo "search $domain" >> "$resolvconfupdate"
    cat "$resolvconfupdate" > /etc/resolv.conf
    echo "Attempting to register $host.$domain and $ptrrec"
    {
        echo "update delete $host.$domain a"
        echo "update add $host.$domain 600 a $new_ip_address"
        echo "send"
        echo "update delete $ptrrec ptr"
        echo "update add $ptrrec 600 ptr $host.$domain"
        echo "send"
    } > "$nsupdatecmds"
    nsupdate "$nsupdatecmds"
fi
#done
exit 0;
EOF
chmod 755 /etc/dhcp/dhclient-exit-hooks
service network restart

# Confirm DNS record has been updated, retry if update did not work
i=0
until [ $i -ge 5 ]
do
    sleep 5
    i=$((i+1))
    hostname | nslookup && break
    service network restart
done

if [ $i -ge 5 ]; then
    echo "DNS update failed"
    exit 1
fi
}


centos_6()
{
    echo "CentOS 6"

    # execute the CentOS / RHEL 6 dhclient-exit-hooks setup
    dhclient_6
}


rhel_6()
{
    echo "RHEL 6"

    # rewrite SELINUX config to disabled and turn off enforcement
    sed -i.bak "s/^SELINUX=.*$/SELINUX=disabled/" /etc/selinux/config
    setenforce 0
    # stop firewall and disable
    service iptables stop
    chkconfig iptables off
    # update config to disable IPv6 and disable
    echo "# Disable IPv6" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1

    # execute the CentOS / RHEL 6 dhclient-exit-hooks setup
    dhclient_6
}


#
# CentOS and RHEL 7 use NetworkManager. Add a script to be automatically invoked when interface comes up.
# Function not indented so EOF works.
#
networkmanager_7()
{
cat > /etc/NetworkManager/dispatcher.d/12-register-dns <<"EOF"
#!/bin/bash
# NetworkManager Dispatch script
# Deployed by Cloudera Altus Director Bootstrap
#
# Expected arguments:
#    $1 - interface
#    $2 - action
#
# See for info: http://linux.die.net/man/8/networkmanager

# Register A and PTR records when interface comes up
# only execute on the primary nic
if [ "$1" != "eth0" ] || [ "$2" != "up" ]
then
    exit 0;
fi

# when we have a new IP, perform nsupdate
new_ip_address="$DHCP4_IP_ADDRESS"

host=$(hostname -s)
domain=$(nslookup $(grep -i nameserver /etc/resolv.conf | cut -d ' ' -f 2) | grep -i name | cut -d ' ' -f 3 | cut -d '.' -f 2- | rev | cut -c 2- | rev)
IFS='.' read -ra ipparts <<< "$new_ip_address"
ptrrec="$(printf %s "$new_ip_address." | tac -s.)in-addr.arpa"
nsupdatecmds=$(mktemp -t nsupdate.XXXXXXXXXX)
resolvconfupdate=$(mktemp -t resolvconfupdate.XXXXXXXXXX)
echo updating resolv.conf
grep -iv "search" /etc/resolv.conf > "$resolvconfupdate"
echo "search $domain" >> "$resolvconfupdate"
cat "$resolvconfupdate" > /etc/resolv.conf
echo "Attempting to register $host.$domain and $ptrrec"
{
    echo "update delete $host.$domain a"
    echo "update add $host.$domain 600 a $new_ip_address"
    echo "send"
    echo "update delete $ptrrec ptr"
    echo "update add $ptrrec 600 ptr $host.$domain"
    echo "send"
} > "$nsupdatecmds"
nsupdate "$nsupdatecmds"
exit 0;
EOF
chmod 755 /etc/NetworkManager/dispatcher.d/12-register-dns
service network restart

# Confirm DNS record has been updated, retry if update did not work
i=0
until [ $i -ge 5 ]
do
    sleep 5
    i=$((i+1))
    hostname | nslookup && break
    service network restart
done

if [ $i -ge 5 ]; then
    echo "DNS update failed"
    exit 1
fi
}


centos_7()
{
    echo "CentOS 7"

    # execute the CentOS / RHEL 7 network manager setup
    networkmanager_7
}


rhel_7()
{
    echo "RHEL 7"

    # rewrite SELINUX config to disable and turn off enforcement
    sed -i.bak "s/^SELINUX=.*$/SELINUX=disabled/" /etc/selinux/config
    setenforce 0
    # stop firewall and disable
    systemctl stop iptables
    systemctl iptables off
    # RHEL 7 uses firewalld
    systemctl stop firewalld
    systemctl disable firewalld
    # Disable tuned so it does not overwrite sysctl.conf
    service tuned stop
    systemctl disable tuned
    # Disable chrony so it does not conflict with ntpd installed by Director
    systemctl stop chronyd
    systemctl disable chronyd
    # update config to disable IPv6 and disable
    echo "# Disable IPv6" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
    # swappiness is set by Director in /etc/sysctl.conf
    # Poke sysctl to have it pickup the config change.
    sysctl -p

    # execute the CentOS / RHEL 7 network manager setup
    networkmanager_7
}


#
# Main workflow
#

# ensure user is root
if [ "$(id -u)" -ne 0 ]
then
    echo "Please run as root."
    exit 1
fi

# find the OS and release
os=""
major_release=""

# if it's there, use lsb_release
if rpm -q redhat-lsb
then
    os=$(lsb_release -si)
    major_release=$(lsb_release -sr | cut -d '.' -f 1)

# if lsb_release isn't installed, use /etc/redhat-release
else
    if grep "CentOS.* 6\\." /etc/redhat-release
    then
        os="CentOS"
        major_release="6"
    fi

    if grep "CentOS.* 7\\." /etc/redhat-release
    then
        os="CentOS"
        major_release="7"
    fi

    if grep "Red Hat Enterprise Linux Server release 6\\." /etc/redhat-release
    then
        os="RedHatEnterpriseServer"
        major_release="6"
    fi

    if grep "Red Hat Enterprise Linux Server release 7\\." /etc/redhat-release
    then
        os="RedHatEnterpriseServer"
        major_release="7"
    fi
fi

echo "OS: $os $major_release"

# select the OS and run the appropriate setup script
not_supported_msg="OS $os $major_release is not supported."
if [ "$os" = "CentOS" ]; then
    if [ "$major_release" = "6" ]; then
        centos_6
    elif [ "$major_release" = "7" ]; then
        centos_7
    else
        echo "$not_supported_msg"
        exit 1
    fi

elif [ "$os" = "RedHatEnterpriseServer" ]; then
    if [ "$major_release" = "6" ]; then
        rhel_6
    elif [ "$major_release" = "7" ]; then
        rhel_7
    else
        echo "$not_supported_msg"
        exit 1
    fi
else
    echo "$not_supported_msg"
    exit 1
fi
