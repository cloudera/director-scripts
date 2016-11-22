# DNS scripts

This directory contains some sample scripts for various DNS operations.

**_Note: these scripts are not intended for production usage_**

## DNS record update scripts

These scripts assume there is a DNS server already setup with proper zone files and that the VM hosts have permission to update DNS records.

* `bootstrap_dns_dhclient.sh`: This is the sample instance bootstrap script to setup automatic DNS record update using `dhclient` for RHEL/CentOS 6 VMs provisioned by Director. To use this script, copy it into the "bootstrap script" section of the Cloudera Director instance template.
* `bootstrap_dns_nm.sh`: This is the sample instance bootstrap script to setup automatic DNS record update using `Network Manager` for RHEL/CentOS 7 VMs provisioned by Director. To use this script, copy it into the "bootstrap script" section of the Cloudera Director instance template.
* `dhclient-exit-hooks`: This is the DHCP client exit hook script that will automatically update DNS record (via `nsupdate`) when the VM network service is restarted. This script assumes the host VM is running `dhclient`.

## BIND setup scripts

_Note: These scripts will bootstrap CentOS 6.7, CentOS 7.2, RHEL 6.7, and RHEL 7.2_

* `bind-dns-setup.sh`: This is the BIND setup script that will turn a newly created VM into a BIND server and walk you through changing Azure DNS settings. This script assumes it's running on a newly provisioned VM, or that `bind-dns-reset.sh` has been executed.
* `bind-dns-reset.sh`: This is the reset script that will walk you through resetting a host's DNS settings back to default so that you can run `bind-dns-setup.sh` agian.

### Requirements

* The BIND VM must be in the same VNET as the future clusters.
* Port 53 on the BIND host must be accessible for DNS to work.

### Warnings and caveats

* `bind-dns-setup.sh` creates one zone file which supports at most 255 hosts. If required, additional zone files can be added and configured manually.
* The scripts assume:
    * the Azure nameserver IP address will always be `168.63.129.16` (see [here](https://blogs.msdn.microsoft.com/mast/2015/05/18/what-is-the-ip-address-168-63-129-16/)).

### Execution walkthrough

1. On the fresh host that you'll install BIND on run `bind-dns-setup.sh`. The script will prompt for the internal host FQDN suffix to use and then ask you to swap DNS from Azure to BIND. Steps to swap DNS can be found [here](http://www.cloudera.com/documentation/director/latest/topics/director_get_started_azure_ddns.html).

1. To revert these changes (e.g. to use a different host FQDN suffix, or if `bind-dns-setup.sh`'s execution was interrupted) run `bind-dns-reset.sh`. This will revert everything done in `bind-dns-setup.sh` and allow you to re-run `bind-dns-setup.sh`.

1. After `bind-dns-setup.sh` has completed run `dns-test.sh` to verify that DNS is correctly functioning on the host. Any errors indicate that there is a problem with the DNS configuration.

## DNS verification scripts

* `dns-test.sh`: This is the script that runs basic DNS sanity checks (e.g. forward and reverse resolution).
