# Example bootstrap scripts
This directory contains example VM bootstrap scripts. To use these scripts
* Copy them to the "bootstrap script" section under instance templates in Cloudera Director UI. OR
* Update the instance template `bootstrapScripts` section in your Cloudera Director config file.

## Contents
* `os-generic-bootstrap.sh`: This is an OS generic (for RHEL/CentOS 6.7 & 7.2) bootstrap script. You **_must_** use this bootstrap script directly or modify it (by adjusting the DNS record update portion or adding new scripts) to your specific deployment environment to successfuly deploy clusters on Azure.
