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
# This script will walk you through setting up BIND on the host and making the changes needed in
# Azure portal.
# This script will bootstrap these OSes:
#   - CentOS 6.7
#   - CentOS 7.2
#   - RHEL 6.7
#   - RHEL 7.2
#
# Notes and notible differences between OSes:
#   - CentOS 6.7 and RHEL 6.7 use dhclient
#   - CentOS 7.2 and RHEL 7.2 use NetworkManager
#

#
# WARNING
#
# - This script only creates one zone file which supports <= 255 hosts. It has not been tested
#   with > 255 hosts trying to use the same zone file. It "might just work", or it may require
#   manually configuring additional zone files in `/etc/named/named.conf.local` and
#   `/etc/named/zones/`.
# - It is assumed that the Azure nameserver IP address will always be `168.63.129.16`. See more
#   info: https://blogs.msdn.microsoft.com/mast/2015/05/18/what-is-the-ip-address-168-63-129-16/.
#


#
# Microsoft Azure Assumptions
#
nameserver_ip="168.63.129.16" # used for all regions


#
# Functions
#

#
# This function does the install and setup for BIND
#
base_beginning() {
    echo "-- STOP --"
    echo "This script will turn a fresh host into a BIND server and walk you through changing Azure DNS "
    echo "settings. If you have previously run this script on this host, or another host within the same "
    echo "virtual network: stop running this script and run the reset script before continuing."
    printf "Press [Enter] to continue."
    read -r

    #
    # Quick sanity checks
    #
    if ! hostname -f
    then
        echo "Unable to run the command 'hostname -f'; run the reset script and try again."
        exit 1
    fi

    hostname -i
    if ! hostname -i
    then
        echo "Unable to run the command 'hostname -i'; run the reset script and try again."
        exit 1
    fi

    #
    # Install and setup the prerequisites
    #
    sudo yum -y install bind bind-utils
    if ! yum list installed bind
    then
        echo "Unable to install package 'bind', manual troubleshoot required."
        exit 1
    fi
    if ! yum list installed bind-utils
    then
        echo "Unable to install package 'bind-utils', manual troubleshoot required."
        exit 1
    fi

    # make the directories that bind will use
    mkdir /etc/named/zones
    # make the files that bind will use
    touch /etc/named/named.conf.local
    touch /etc/named/zones/db.internal
    touch /etc/named/zones/db.reverse

    #
    # Set all of the variables
    #
    echo ""
    printf "Enter the internal host FQDN suffix you wish to use for your cluster network (e.g. cdh-cluster.internal): "
    read -r internal_fqdn_suffix

    while [ -z "$internal_fqdn_suffix" ]; do
        printf "You must enter the internal host FQDN suffix you wish to use for your cluster network (e.g. cdh-cluster.internal): "
        read -r internal_fqdn_suffix
    done

    hostname=$(hostname -s)

    internal_ip=$(hostname -i)

    subnet=$(ipcalc -np "$(ip -o -f inet addr show | awk '/scope global/ {print $4}')" | awk '{getline x;print x;}1' | awk -F= '{print $2}' | awk 'NR%2{printf "%s/",$0;next;}1')

    ptr_record_prefix=$(hostname -i | awk -F. '{print $3"." $2"."$1}')

    hostnumber=$(hostname -i | cut -d . -f 4)

    hostmaster="hostmaster"


    echo "[DEBUG: Variables used]"
    echo "subnet: $subnet"
    echo "internal_ip: $internal_ip"
    echo "internal_fqdn_suffix: $internal_fqdn_suffix"
    echo "ptr_record_prefix: $ptr_record_prefix"
    echo "hostname: $hostname"
    echo "hostmaster: $hostmaster"
    echo "hostnumber: $hostnumber"
    echo "[END DEBUG: Variables used]"

#
# Create the BIND files
# Section not indented so EOF works
#

cat > /etc/named.conf <<EOF
acl trusted {
    ${subnet};
};

options {
    listen-on port 53 { 127.0.0.1; ${internal_ip}; };
    listen-on-v6 port 53 { ::1; };
    directory "/var/named";
    dump-file "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    allow-query { localhost; trusted; };
    recursion yes;
    forwarders { ${nameserver_ip}; };
    dnssec-enable yes;
    dnssec-validation yes;
    dnssec-lookaside auto;

    /* Path to ISC DLV key */
    bindkeys-file "/etc/named.iscdlv.key";

    managed-keys-directory "/var/named/dynamic";
};


logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};


zone "." IN {
    type hint;
    file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
include "/etc/named/named.conf.local";
EOF

cat > /etc/named/named.conf.local <<EOF
zone "${internal_fqdn_suffix}" IN {
    type master;
    file "/etc/named/zones/db.internal";
    allow-update { ${subnet}; };
};

zone "${ptr_record_prefix}.in-addr.arpa" IN {
    type master;
    file "/etc/named/zones/db.reverse";
    allow-update { ${subnet}; };
 };
EOF

cat > /etc/named/zones/db.internal <<EOF
\$ORIGIN .
\$TTL 600  ; 10 minutes
${internal_fqdn_suffix}  IN SOA  ${hostname}.${internal_fqdn_suffix}. ${hostmaster}.${internal_fqdn_suffix}. (
        10         ; serial
        600        ; refresh (10 minutes)
        60         ; retry (1 minute)
        604800     ; expire (1 week)
        600        ; minimum (10 minutes)
        )
        NS  ${hostname}.${internal_fqdn_suffix}.

\$ORIGIN ${internal_fqdn_suffix}.
${hostname}    A  ${internal_ip}
EOF

cat > /etc/named/zones/db.reverse <<EOF
\$ORIGIN .
\$TTL 600  ; 10 minutes
${ptr_record_prefix}.in-addr.arpa  IN SOA  ${hostname}.${internal_fqdn_suffix}. ${hostmaster}.${internal_fqdn_suffix}. (
        10         ; serial
        600        ; refresh (10 minutes)
        60         ; retry (1 minute)
        604800     ; expire (1 week)
        600        ; minimum (10 minutes)
        )
        NS  ${hostname}.${internal_fqdn_suffix}.

\$ORIGIN ${ptr_record_prefix}.in-addr.arpa.
${hostnumber}      PTR  ${hostname}.${internal_fqdn_suffix}.
EOF


    #
    # Final touches on BIND related items
    #
    chown -R named:named /etc/named*
    if ! named-checkconf /etc/named.conf # if named-checkconf fails
    then
        exit 1
    fi
    if ! named-checkzone "${internal_fqdn_suffix}" /etc/named/zones/db.internal # if named-checkzone fails
    then
        exit 1
    fi
    if ! named-checkzone "${ptr_record_prefix}.in-addr.arpa" /etc/named/zones/db.reverse # if named-checkzone fails
    then
        exit 1
    fi

    service named start
    chkconfig named on

    #
    # This host is now running BIND
    #
}


#
# This function prompts the person running the script to go to portal.azure.com to change Azure
# DNS settings then makes sure everything works as expected
#
base_end() {
    #
    # Now it's time to update Azure DNS settings in portal
    #
    echo ""
    echo "-- STOP -- STOP -- STOP --"
    echo "Go to -- portal.azure.com -- and change Azure DNS to point to the private IP of this host: ${internal_ip}"
    printf "Press [Enter] once you have gone to portal.azure.com and this is completed."
    read -r

    #
    # Loop until DNS nameserver updates have propagated to /etc/resolv.conf
    # NB: search server updates don't take place until dhclient-exit-hooks have executed
    #
    until grep "nameserver ${internal_ip}" /etc/resolv.conf
    do
        service network restart
        echo "Waiting for Azure DNS nameserver updates to propagate, this usually takes less than 2 minutes..."
        sleep 10
    done


    #
    # Check that everything is working
    #
    echo "Running sanity checks:"

    if ! hostname -f
    then
        echo "Unable to run the command 'hostname -f' (check 1 of 4)"
        echo "Run the reset script and then try this script again."
        exit 1
    fi

    if ! hostname -i
    then
        echo "Unable to run the command 'hostname -i' (check 2 of 4)"
        echo "Run the reset script and then try this script again."
        exit 1
    fi

    if ! host "$(hostname -f)"
    then
        echo "Unable to run the command 'host \`hostname -f\`' (check 3 of 4)"
        echo "Run the reset script and then try this script again."
        exit 1
    fi

    if ! host "$(hostname -i)"
    then
        echo "Unable to run the command 'host \`hostname -i\`' (check 4 of 4)"
        echo "Run the reset script and then try this script again."
        exit 1
    fi

    echo ""
    echo "Everything is working!"
    exit 0
}


#
# This function creates the dhclient hooks
# writing dhclient-exit-hooks is the same for CentOS 6.7 and RHEL 6.7
# function not indented so EOF works
#
dhclient_67()
{

# dhclient-exit-hooks explained in dhclient-script man page: http://linux.die.net/man/8/dhclient-script
# cat a here-doc represenation of the hooks to the appropriate file
cat > /etc/dhcp/dhclient-exit-hooks <<"EOF"
#!/bin/bash
printf "\ndhclient-exit-hooks running...\n\treason:%s\n\tinterface:%s\n" "${reason:?}" "${interface:?}"
# only execute on the primary nic
if [ "$interface" != "eth0" ]
then
    exit 0;
fi
# when we have a new IP, update the search domain
if [ "$reason" = BOUND ] || [ "$reason" = RENEW ] ||
   [ "$reason" = REBIND ] || [ "$reason" = REBOOT ]
then
EOF
# this is a separate here-doc because there's two sets of variable substitution going on, this set
# needs to be evaluated when written to the file, the two others (with "EOF" surrounded by quotes)
# should not have variable substitution occur when creating the file.
cat >> /etc/dhcp/dhclient-exit-hooks <<EOF
    domain=${internal_fqdn_suffix}
EOF
cat >> /etc/dhcp/dhclient-exit-hooks <<"EOF"
    resolvconfupdate=$(mktemp -t resolvconfupdate.XXXXXXXXXX)
    echo updating resolv.conf
    grep -iv "search" /etc/resolv.conf > "$resolvconfupdate"
    echo "search $domain" >> "$resolvconfupdate"
    cat "$resolvconfupdate" > /etc/resolv.conf
fi
#done
exit 0;
EOF
chmod 755 /etc/dhcp/dhclient-exit-hooks

}


centos_67()
{
    echo "CentOS 6.7"

    base_beginning

    # execute the CentOS 6.7 / RHEL 6.7 dhclient-exit-hooks setup
    dhclient_67

    base_end
}


rhel_67()
{
    echo "RHEL 6.7"

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

    base_beginning

    # execute the CentOS 6.7 / RHEL 6.7 dhclient-exit-hooks setup
    dhclient_67

    base_end
}


#
# This function creates the networkmanager hooks
# writing network manager hooks is the same for CentOS 7.2 and RHEL 7.2
# function not indented so EOF works
#
networkmanager_72()
{
# Centos 7.2 and RHEL 7.2 uses NetworkManager. Add a script to be automatically invoked when interface comes up.
cat > /etc/NetworkManager/dispatcher.d/12-register-dns <<"EOF"
#!/bin/bash
# NetworkManager Dispatch script
# Deployed by Cloudera Director Bootstrap
#
# Expected arguments:
#    $1 - interface
#    $2 - action
#
# See for info: http://linux.die.net/man/8/networkmanager

# Register A and PTR records when interface comes up
# only execute on the primary nic
if [ "$1" != "eth0" || "$2" != "up" ]
then
    exit 0;
fi

# when we have a new IP, perform nsupdate
new_ip_address="$DHCP4_IP_ADDRESS"

EOF
# this is a separate here-doc because there's two sets of variable substitution going on, this set
# needs to be evaluated when written to the file, the two others (with "EOF" surrounded by quotes)
# should not have variable substitution occur when creating the file.
cat >> /etc/NetworkManager/dispatcher.d/12-register-dns <<EOF
domain=${internal_fqdn_suffix}
EOF
cat >> /etc/NetworkManager/dispatcher.d/12-register-dns <<"EOF"
IFS='.' read -ra ipparts <<< "$new_ip_address"
ptrrec="$(printf %s "$new_ip_address." | tac -s.)in-addr.arpa"
nsupdatecmds=$(mktemp -t nsupdate.XXXXXXXXXX)
resolvconfupdate=$(mktemp -t resolvconfupdate.XXXXXXXXXX)
echo updating resolv.conf
grep -iv "search" /etc/resolv.conf > "$resolvconfupdate"
echo "search $domain" >> "$resolvconfupdate"
cat "$resolvconfupdate" > /etc/resolv.conf
exit 0;
EOF
chmod 755 /etc/NetworkManager/dispatcher.d/12-register-dns
}


centos_72()
{
    echo "CentOS 7.2"

    base_beginning

    # execute the CentOS 7.2 / RHEL 7.2 network manager setup
    networkmanager_72

    base_end
}


rhel_72()
{
    echo "RHEL 7.2"

    # rewrite SELINUX config to disable and turn off enforcement
    sed -i.bak "s/^SELINUX=.*$/SELINUX=disabled/" /etc/selinux/config
    setenforce 0
    # stop firewall and disable
    systemctl stop iptables
    systemctl iptables off
    # RHEL 7.x uses firewalld
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
    # swappniess is set by Director in /etc/sysctl.conf
    # Poke sysctl to have it pickup the config change.
    sysctl -p

    base_beginning

    # execute the CentOS 7.2 / RHEL 7.2 network manager setup
    networkmanager_72

    base_end
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
release=""

# if it's there, use lsb_release

if rpm -q redhat-lsb
then
    os=$(lsb_release -si)
    release=$(lsb_release -sr)

# if lsb_release isn't installed, use /etc/redhat-release
else

    if grep "CentOS.* 6\.7" /etc/redhat-release
    then
        os="CentOS"
        release="6.7"
    fi


    if grep "CentOS.* 7\.2" /etc/redhat-release
    then
        os="CentOS"
        release="7.2"
    fi

    if grep "Red Hat Enterprise Linux Server release 6.7" /etc/redhat-release
    then
        os="RedHatEnterpriseServer"
        release="6.7"
    fi

    if grep "Red Hat Enterprise Linux Server release 7.2" /etc/redhat-release
    then
        os="RedHatEnterpriseServer"
        release="7.2"
    fi
fi

echo "OS: $os $release"

# select the OS and run the appropriate setup script
not_supported_msg="OS $os $release is not supported."
if [ "$os" = "CentOS" ]
then
    if [ "$release" = "6.7" ]
    then
        centos_67
    elif [ "$release" = "7.2" ]
    then
        centos_72
    else
        echo not_supported_msg
        exit 1
    fi

elif [ "$os" = "RedHatEnterpriseServer" ]
then
    if [ "$release" = "6.7" ]
    then
        rhel_67
    elif [ "$release" = "7.2" ]
    then
        rhel_72
    else
        echo not_supported_msg
        exit 1
    fi
else
    echo not_supported_msg
    exit 1
fi
