#!/bin/sh

#
# This script will reset all DNS settings allowing you to run the setup script.
#

#
# WARNING
#
# - It is assumed that the Azure nameserver IP address will always be `168.63.129.16`. See more
#   info: https://blogs.msdn.microsoft.com/mast/2015/05/18/what-is-the-ip-address-168-63-129-16/.
#


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
nameserver_ip="168.63.129.16"

#
# Change settings in Azure Portal
#
echo ""
echo "-- STOP -- STOP -- STOP --"
echo "Go to -- portal.azure.com -- and change Azure DNS servers to point to Azure DNS."
printf "Press [Enter] once you have gone to portal.azure.com and this is completed."
read -r


#
# Remove BIND
#
service named stop
chkconfig named off
yum -y remove bind

rm -f /etc/named.conf
rm -rf /etc/named/*

#
# Delete the exit hook
#
rm -f /etc/dhcp/dhclient-exit-hooks


#
# Loop until Azure DNS changes have propagated
#
until grep "nameserver ${nameserver_ip}" /etc/resolv.conf
do
    echo "Waiting for Azure DNS nameserver updates to propagate, this usually takes less than 2 minutes..."
    service network restart
    sleep 10
done

until grep "search.*internal.cloudapp.net" /etc/resolv.conf
do
    echo "Waiting for Azure DNS search server updates to propagate, this usually takes less than 2 minutes..."
    service network restart
    sleep 10
done


#
# Check that everything is working
#
echo "Running sanity checks:"

hostname -f
if [ $? != 0 ]
then
    echo "Unable to run the command 'hostname -f' (check 1 of 3)"
    exit 1
fi

hostname -i
if [ $? != 0 ]
then
    echo "Unable to run the command 'hostname -i' (check 2 of 3)"
    exit 1
fi

host "$(hostname -f)"
if [ $? != 0 ]
then
    echo "Unable to run the command 'host \`hostname -f\`' (check 3 of 3)"
    exit 1
fi

echo "Everything has been reset!"
exit 0