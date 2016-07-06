# DNS record update scripts
This directory contains some sample scripts for updating DNS records for Azure VMs. The scripts assume there is a DNS server already setup with proper zone files and that the VM hosts have permission to update DNS records.

* `bootstrap_dns.sh` : This is the sample instance bootstrap script to setup automatic DNS record update for VMs provisioned by Director. To use this script, copy it into the "bootstrap script
 section of the Director instance template.
* `dhclient-exit-hooks` : This is the DHCP client exit hook script that will automatically update DNS record (via `nsupdate`) when the VM network service is restarted. This script assumes the host VM is running `dhclient`.
