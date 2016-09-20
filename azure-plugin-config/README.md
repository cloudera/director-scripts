# Cloudera Director Azure Plugin Config Files

**IMPORTANT:** The [Cloudera Enterprise Reference Architecture for Azure Deployments](http://www.cloudera.com/documentation/other/reference-architecture/PDF/cloudera_ref_arch_azure.pdf) (RA) is the authoritative document for supported deployment configurations in Azure. Please refer to the RA for latest supported instance types, and images on Azure.

There are two files that the Cloudera Director Azure Plugin uses to update supported images, instance types, and regions as the RA is updated:
* `images.conf`
* `azure-plugin.conf`

The files, their uses, and how to update them are explained below.


## `images.conf`

**What does `images.conf` do?**

The `images.conf` file defines the VM images Cloudera Director can use to provision VMs. The `images.conf` file in in this repository is continuously updated with the latest supported VM images. The latest supported images can be found in the [RA](http://www.cloudera.com/documentation/other/reference-architecture/PDF/cloudera_ref_arch_azure.pdf).


**How do I update Cloudera Director with the latest certified images?**

1. Take the `images.conf` file found in this directory and copy it to `/var/lib/cloudera-director-plugins/azure-provider-1.0.1/etc/images.conf`.
1. Restart Cloudera Director with `sudo service cloudera-director-server restart`.
1. Now you can use the latest certified images when deploying clusters. Note that in the Cloudera Director UI you won't see the image-name in the dropdown list - just type it manually in and it will work.


## `azure-plugin.conf`

**What does `azure-plugin.conf` do?**

The `azure-plugin.conf` file defines settings that Cloudera Director uses to validate VMs before provisioning. There are a bunch of fields, I'll go over the important ones:

* `provider` > `supported-regions`: this is the list of regions that a cluster can be deployed into. Only regions that support premium storage should be added to the list - that list can be found [here](https://azure.microsoft.com/en-us/regions/services/).
* `instance` > `supported-instances`: this is the list of supported instance sizes that can be used. Only certain sizes have been certified. The latest supported instances can be found in the [RA](http://www.cloudera.com/documentation/other/reference-architecture/PDF/cloudera_ref_arch_azure.pdf).


**How do I update Cloudera Director with the latest regions that have premium storage?**

1. Check with [Azure's products available by region page](https://azure.microsoft.com/en-us/regions/services/) that the region you want to add supports *both* premium storage and the instance type you're going to use.
1. Take the `azure-plugin.conf` file found in this repository and **add** the new region to the `provider` > `supported-regions` list. The plugin will replace it's internal list with this list so make sure you keep all of the supported regions that are already defined in `azure-plugin.conf`
1. On Cloudera Director server, copy your modified `azure-plugin.conf` to `/var/lib/cloudera-director-plugins/azure-provider-1.0.1/etc/azure-plugin.conf`.
1. Restart Cloudera Director with `sudo service cloudera-director-server restart`
1. Now you can use that region when deploying clusters. Note that in the Cloudera Director UI you won't see the region in the dropdown list - just type it manually in and it will work.


**How do I update Cloudera Director with the latest certified instances?**

1. Take the `azure-plugin.conf` file found in this directory copy it to `/var/lib/cloudera-director-plugins/azure-provider-1.0.1/etc/azure-plugin.conf`.
1. Restart Cloudera Director with `sudo service cloudera-director-server restart`.
1. Now you can use the latest certified regions and instances when deploying clusters.
