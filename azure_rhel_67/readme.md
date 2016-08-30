# Using Cloudera Director to Deploy Clusters with RHEL 6.7 on Azure
This directory contains required configurations and examples for deploying a cluster using the RHEL 6.7 image in Azure Marketplace.

## Content:
* `bootstrap.sh`: This bootstrap script prepares the RHEL 6.7 image from Azure Marketplace for cluster deployment. It **must** be used to successfully deploy a cluster running RHEL 6.7.
* `azure.reference.rhel67.conf`: Example Cloudera Director configuration file that deploys a Highly-Available cluster using the RHEL 6.7 image in Azure Marketplace.

## Steps to deploy cluster using RHEL 6.7:
1. Modify `azure.reference.rhel67.conf` to with your credentials and deploy cluster.
1. (Optional) If deploying using Cloudera Director UI, select `redhat-rhel-67-latest` for "Image Alias" in the instance template. You must also use the `bootstrap.sh` script found in this directory for the instance bootstrap script to successfully deploy a cluster.
