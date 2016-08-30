#!/bin/sh

#
# Setup
#
if ! [ "$(id -u)" = 0 ]
  then echo "Please run as root."
  exit 1
fi


#
# Microsoft Azure Assumptions
#
nameserver_ip="168.63.129.16" # used for all regions


echo "-- STOP --"
echo "This script will turn a fresh host into a BIND server and walk you through changing Azure DNS "
echo "settings. If you have previously run this script on this host, or another host within the same "
echo "virtual network: stop running this script and run the reset script before continuing."
printf "Press [Enter] to continue."
read -r

#
# Quick sanity checks
#
hostname -f
if [ $? != 0 ]
then
    echo "Unable to run the command 'hostname -f'; run the reset script and try again."
    exit 1
fi

hostname -i
if [ $? != 0 ]
then
    echo "Unable to run the command 'hostname -i'; run the reset script and try again."
    exit 1
fi

#
# Install and setup the prerequisites
#
sudo yum -y install bind bind-utils
yum list installed bind
if [ $? != 0 ]
then
    echo "Unable to install package 'bind', manual troubleshoot required."
    exit 1
fi
yum list installed bind-utils
if [ $? != 0 ]
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
named-checkconf /etc/named.conf
if [ $? != 0 ] # if named-checkconf fails
then
    exit 1
fi
named-checkzone "${internal_fqdn_suffix}" /etc/named/zones/db.internal
if [ $? != 0 ] # if named-checkzone fails
then
    exit 1
fi
named-checkzone "${ptr_record_prefix}.in-addr.arpa" /etc/named/zones/db.reverse
if [ $? != 0 ] # if named-checkzone fails
then
    exit 1
fi

service named start
chkconfig named on
#
# This host is now running BIND
#


#
# Add dhclient-exit-hooks to update the DNS search server
#

# Taken from https://github.com/cloudera/director-scripts/blob/master/azure-dns-scripts/bootstrap_dns.sh
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

hostname -f
if [ $? != 0 ]
then
    echo "Unable to run the command 'hostname -f' (check 1 of 4)"
    echo "Run the reset script and then try this script again."
    exit 1
fi

hostname -i
if [ $? != 0 ]
then
    echo "Unable to run the command 'hostname -i' (check 2 of 4)"
    echo "Run the reset script and then try this script again."
    exit 1
fi

host "$(hostname -f)"
if [ $? != 0 ]
then
    echo "Unable to run the command 'host \`hostname -f\`' (check 3 of 4)"
    echo "Run the reset script and then try this script again."
    exit 1
fi

host "$(hostname -i)"
if [ $? != 0 ]
then
    echo "Unable to run the command 'host \`hostname -i\`' (check 4 of 4)"
    echo "Run the reset script and then try this script again."
    exit 1
fi

echo "Everything is working!"
exit 0