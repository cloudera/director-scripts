# DNS scripts

This directory contains some sample scripts for various DNS operations.

## DNS record update scripts

These scripts assume there is a DNS server already setup with proper zone files and that the VM hosts have permission to update DNS records.

* `bootstrap_dns.sh`: This is the sample instance bootstrap script to setup automatic DNS record update for VMs provisioned by Director. To use this script, copy it into the "bootstrap script section of the Director instance template.
* `dhclient-exit-hooks`: This is the DHCP client exit hook script that will automatically update DNS record (via `nsupdate`) when the VM network service is restarted. This script assumes the host VM is running `dhclient`.

## BIND setup scripts

These scripts set up a BIND server and walks you through updating Azure DNS settings.

There is a section at the top of the scripts called `Microsoft Azure Assumptions` where we assign variables based on our current understanding of Azure (e.g. the IP address of Azure's nameserver)

* `bind-dns-setup.sh`: This is the BIND setup script that will turn a fresh host into a BIND server and walk you through changing Azure DNS settings. This script assumes it's running on a fresh host, or that the `bind-dns-reset.sh` script will be executed between runs of `bind-dns-setup.sh`.
* `bind-dns-reset.sh`: This is the reset script that will walk you through resetting a host's DNS settings back to default so that you can run `bind-dns-setup.sh` agian.

## DNS verification scripts

* `dns-test.sh`: This is the script that runs basic DNS sanity checks (e.g. forward and reverse resolution).