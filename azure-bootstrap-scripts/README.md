# Example Bootstrap Scripts for Azure

This directory contains example bootstrap scripts for VMs hosted in Microsoft Azure. To use a script:

* Copy it to the "bootstrap scripts" section for instance templates in the Cloudera Altus Director UI. *OR*
* Update the `bootstrapScripts` section for instance templates in your Cloudera Altus Director configuration file.

## Contents

### `os-generic-bootstrap.sh`

This is an OS-generic (for RHEL/CentOS 6.x and 7.x) bootstrap script. You **_must_** use this bootstrap script
directly, or modify it for your specific environment by adjusting the DNS record update portion or by adding new
scripts, to successfully deploy clusters on Azure.
