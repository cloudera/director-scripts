#!/bin/sh

#
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
# Functions
#

# writing dhclient-exit-hooks is the same for CentOS 6.7 and RHEL 6.7
# function not indented so EOF works
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
# when we have a new IP, perform nsupdate
if [ "$reason" = BOUND ] || [ "$reason" = RENEW ] ||
[ "$reason" = REBIND ] || [ "$reason" = REBOOT ]
then
    printf "\tnew_ip_address:%s\n" "${new_ip_address:?}"
    host=$(hostname -s)
    domain=$(hostname | cut -d'.' -f2- -s)
    domain=${domain:='cdh-cluster.internal'} # REPLACE-ME If no hostname is provided, use cdh-cluster.internal
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
}


centos_67()
{
    echo "CentOS 6.7"

    # execute the CentOS 6.7 / RHEL 6.7 dhclient-exit-hooks setup
    dhclient_67
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

    # execute the CentOS 6.7 / RHEL 6.7 dhclient-exit-hooks setup
    dhclient_67
}


# writing network manager hooks is the same for CentOS 7.2 and RHEL 7.2
# function not indented so EOF works
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

host=$(hostname -s)
domain=$(hostname | cut -d'.' -f2- -s)
domain=${domain:='cdh-cluster.internal'} # REPLACE-ME If no hostname is provided, use cdh-cluster.internal
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
}


centos_72()
{
    echo "CentOS 7.2"

    # execute the CentOS 7.2 / RHEL 7.2 network manager setup
    networkmanager_72
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

    # execute the CentOS 7.2 / RHEL 7.2 network manager setup
    networkmanager_72
}



#
# Main workflow
#

# ensure user is root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# find the OS and release
os=""
release=""

# if it's there, use lsb_release
rpm -q redhat-lsb
if [ $? -eq 0 ]; then
    os=$(lsb_release -si)
    release=$(lsb_release -sr)

# if lsb_release isn't installed, use /etc/redhat-release
else
    grep  "CentOS.* 6\.7" /etc/redhat-release
    if [ $? -eq 0 ]; then
        os="CentOS"
        release="6.7"
    fi

    grep "CentOS.* 7\.2" /etc/redhat-release
    if [ $? -eq 0 ]; then
        os="CentOS"
        release="7.2"
    fi

    grep "Red Hat Enterprise Linux Server release 6.7" /etc/redhat-release
    if [ $? -eq 0 ]; then
        os="RedHatEnterpriseServer"
        release="6.7"
    fi

    grep "Red Hat Enterprise Linux Server release 7.2" /etc/redhat-release
    if [ $? -eq 0 ]; then
        os="RedHatEnterpriseServer"
        release="7.2"
    fi
fi

# debug
echo $os
echo $release


# shellcheck disable=SC2034
not_supported_msg="OS $os $release is not supported."

# select the OS and run the appropriate setup script
if [ "$os" = "CentOS" ]; then
    if [ "$release" = "6.7" ]; then
        centos_67
    elif [ "$release" = "7.2" ]; then
        centos_72
    else
        echo not_supported_msg
        exit 1
    fi

elif [ "$os" = "RedHatEnterpriseServer" ]; then
    if [ "$release" = "6.7" ]; then
        rhel_67
    elif [ "$release" = "7.2" ]; then
        rhel_72
    else
        echo not_supported_msg
        exit 1
    fi
else
    echo not_supported_msg
    exit 1
fi
