# Cloudera Altus Director Azure Plugin Config Files

**IMPORTANT:** The [Cloudera Enterprise Reference Architecture for Azure Deployments](http://www.cloudera.com/documentation/other/reference-architecture/PDF/cloudera_ref_arch_azure.pdf) (RA) is the authoritative document for supported deployment configurations in Azure. Please refer to the RA for latest supported instance types, and images on Azure.

There are two files that the Cloudera Altus Director Azure Plugin uses to update supported images, instance types, and regions as the RA is updated:
* `images.conf`
* `azure-plugin.conf`

The files, their uses, and how to update them are explained below.

Note that the specific versions and paths referenced in this document may be stale (e.g. `azure-provider-2.0.0`). Use the latest version on your host.


## `images.conf`

**What does `images.conf` do?**

The `images.conf` file defines the VM images Cloudera Altus Director can use to provision VMs. The `images.conf` file in in this repository is continuously updated with the latest supported VM images. The latest supported images can be found in the [RA](http://www.cloudera.com/documentation/other/reference-architecture/PDF/cloudera_ref_arch_azure.pdf).


**How do I update Cloudera Altus Director with the latest certified images?**

1. Take the `images.conf` file found in this directory and copy it to `/var/lib/cloudera-director-plugins/azure-provider-2.0.0/etc/images.conf`.
1. Restart Cloudera Altus Director with `sudo service cloudera-director-server restart`.
1. Now you can use the latest certified images when deploying clusters. Note that in the Cloudera Altus Director UI you won't see the image-name in the dropdown list - just type it manually in and it will work.


## `azure-plugin.conf`

**What does `azure-plugin.conf` do?**

The `azure-plugin.conf` file defines settings that Cloudera Altus Director uses to validate VMs before provisioning. There are a bunch of fields, I'll go over the important ones:

* `provider` > `supported-regions`: this is the list of regions that a cluster can be deployed into. Only regions that support premium storage should be added to the list - that list can be found [here](https://azure.microsoft.com/en-us/regions/services/).
* `provider` > `azure-backend-operation-polling-timeout-second`: this is the amount of time the Cloudera Altus Director Azure Plugin will wait for Azure to complete a task before killing it. Don't set it less than 600 seconds (10 minutes). If you're running into timeout problems increase this, but chances are you won't need to.
* `instance` > `supported-instances`: this is the list of supported instance sizes that can be used. Only certain sizes have been certified. The latest supported instances can be found in the [RA](http://www.cloudera.com/documentation/other/reference-architecture/PDF/cloudera_ref_arch_azure.pdf).
* `instance` > `supported-premium-data-disk-sizes`: this is the list of supported premium data disk sizes. Only certain sizes have been certified. The latest supported instances can be found in the [RA](http://www.cloudera.com/documentation/other/reference-architecture/PDF/cloudera_ref_arch_azure.pdf).


**How do I update Cloudera Altus Director with the latest regions that have premium storage?**

1. Check with [Azure's products available by region page](https://azure.microsoft.com/en-us/regions/services/) that the region you want to add supports *both* premium storage and the instance type you're going to use.
1. Take the `azure-plugin.conf` file found in this repository and **add** the new region to the `provider` > `supported-regions` list. The plugin will replace it's internal list with this list so make sure you keep all of the supported regions that are already defined in `azure-plugin.conf`
1. On Cloudera Altus Director server, copy your modified `azure-plugin.conf` to `/var/lib/cloudera-director-plugins/azure-provider-2.0.0/etc/azure-plugin.conf`.
1. Restart Cloudera Altus Director with `sudo service cloudera-director-server restart`
1. Now you can use that region when deploying clusters. Note that in the Cloudera Altus Director UI you won't see the region in the dropdown list - just type it manually in and it will work.


**How do I update the Cloudera Altus Director Azure Plugin timeout value?**

1. Take the `azure-plugin.conf` file found in this directory copy it to `/var/lib/cloudera-director-plugins/azure-provider-2.0.0/etc/azure-plugin.conf`.
1. Increase the value (in seconds) of `provider` > `azure-backend-operation-polling-timeout-second` by 300 (5 minutes) or 600 (10 minutes). This value must be between 600 (10 minutes) and 3600 (1 hour) inclusive.
1. Restart Cloudera Altus Director with `sudo service cloudera-director-server restart`.
1. Now the Cloudera Altus Director Azure Plugin will have an increased timeout.


**How do I update Cloudera Altus Director with the latest certified instances?**

1. Take the `azure-plugin.conf` file found in this directory copy it to `/var/lib/cloudera-director-plugins/azure-provider-2.0.0/etc/azure-plugin.conf`.
1. Restart Cloudera Altus Director with `sudo service cloudera-director-server restart`.
1. Now you can use the latest certified regions and instances when deploying clusters.


**How do I update Cloudera Altus Director with the latest certified Premium data disk sizes?**

1. Take the `azure-plugin.conf` file found in this directory copy it to `/var/lib/cloudera-director-plugins/azure-provider-2.0.0/etc/azure-plugin.conf`.
1. Restart Cloudera Altus Director with `sudo service cloudera-director-server restart`.
1. Now you can use the latest certified Premium data disk sizes when deploying clusters.
