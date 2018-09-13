# DNS Scripts for Azure

This directory contains some sample scripts for various DNS operations in Microsoft Azure.

**_Note: these scripts are not intended for production usage. Please use them only as a basis for
your own tailored scripts._**

To use a bootstrap script:

* Copy it to the "bootstrap scripts" section for instance templates in the Cloudera Altus Director UI. *OR*
* Update the `bootstrapScripts` section for instance templates in your Cloudera Altus Director configuration file.

## DNS record update scripts

These scripts assume there is a DNS server already set up with proper zone files, and that VM hosts
have permission to update DNS records.

### `bootstrap_dns_dhclient.sh`

This is a sample bootstrap script that sets up automatic DNS record updating, using `dhclient`, for
CentOS and RHEL 6 VMs provisioned by Altus Director.

### `bootstrap_dns_nm.sh`

This is a sample bootstrap script that sets up automatic DNS record updating, using `Network Manager`,
for CentOS and RHEL 7 VMs provisioned by Altus Director.

### `dhclient-exit-hooks`

This is a DHCP client exit hook script that automatically updates DNS records, via `nsupdate`, when a
VM network service is restarted. This script assumes the host VM is running `dhclient`.

## BIND setup scripts

_Note: These scripts will bootstrap CentOS and RHEL 6.x and 7.x._

### `bind-dns-setup.sh`

This is a BIND setup script that turns a newly created VM into a BIND server and walks you through
changing Azure DNS settings. This script assumes it's running on a newly provisioned VM, or that
`bind-dns-reset.sh` has been executed (see below).

### `bind-dns-reset.sh`

This is a reset script that walks you through resetting a host's DNS settings back to the default,
so that you can run `bind-dns-setup.sh` again.

### `dns-test.sh`

This script runs basic DNS sanity checks (e.g., forward and reverse resolution).

### Requirements

* The BIND VM must be in the same VNET as the future clusters.
* Port 53 on the BIND host must be accessible for DNS to work.

### Warnings and caveats

* `bind-dns-setup.sh` creates one zone file which supports at most 255 hosts. If required, additional
  zone files can be added and configured manually.
* The scripts assume that the Azure nameserver IP address will always be `168.63.129.16` (see
  [here](https://blogs.msdn.microsoft.com/mast/2015/05/18/what-is-the-ip-address-168-63-129-16/)).

### Execution walkthrough

1. On the fresh host that you'll install BIND on, run `bind-dns-setup.sh`. The script prompts you
for the internal host FQDN suffix to use, and then asks you to swap DNS from Azure to BIND. Steps to
swap DNS can be found
[here](http://www.cloudera.com/documentation/director/latest/topics/director_get_started_azure_ddns.html).

2. To revert these changes (e.g., to use a different host FQDN suffix, or if the execution of
`bind-dns-setup.sh` was interrupted), run `bind-dns-reset.sh`. This reverts everything done in
`bind-dns-setup.sh` and allows you to re-run `bind-dns-setup.sh`.

3. After `bind-dns-setup.sh` has completed, run `dns-test.sh` to verify that DNS is correctly
functioning on the host. Any errors indicate that there is a problem with the DNS configuration.

