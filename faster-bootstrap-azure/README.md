# Faster Bootstrap with Cloudera Altus Director on Azure

There are steps you can take to make the bootstrap of new deployments and clusters faster.

## Preloaded Managed Image Creation

### Overview

The build-image.sh script creates a Managed Image with Cloudera Manager and a CDH parcel installed (preloaded) for use by Cloudera Altus Director. Using such an Image can cut down significantly on the time for new cluster creation, as software installation and the downloading and distribution* of the parcel can be skipped.

This script, and the support files beneath it, only support CentOS 6, CentOS 7, Red Hat Enterprise Linux 6, and Red Hat Enterprise Linux 7.

To learn how to use a preloaded Managed Image, consult the [usage document](image-usage.md).

\* Please refer to the [Preloaded Image Notes](#notes) section for more information about what "parcel distribution" entails.

### Prerequisites

Before running the script, [Packer](https://packer.io/) must be installed. Use version 1.2.0 or newer. Follow the [installation instructions](https://www.packer.io/intro/getting-started/install.html). Be careful about the other "packer" tool often installed on Red Hat systems.

This script and other scripts it sources require bash 4 or higher. Mac OS X and macOS remain on bash 3, so be sure to install and use bash 4, using [Homebrew](http://brew.sh/) for example.

### Script arguments

The build-image.sh script has three required arguments and four optional arguments.

* The region. This is the region that Packer will run on. The resulting Image will only be available on this region.
* Resource Group. The Azure resource group where the new image should be created.
* The operating system. This guides the selection of Base Image and parcels.
* (Optional) The target Managed Image name. This is the name of the resulting Image. The default Image name includes the operating system.
* (Optional) The CDH parcel URL. This script will download a parcel from this URL to preload and possibly pre-extract onto the new Image. This argument defaults to https://archive.cloudera.com/cdh6/6.2/parcels/.
* (Optional) The Cloudera Manager yum repository URL. This script will download and install Cloudera Manager from packages at this URL onto the new Image. This argument defaults to https://archive.cloudera.com/cm6/6.2/redhat7/yum/ or https://archive.cloudera.com/cm6/6.2/redhat6/yum/ depending on the major version of the base OS selected.
* (Optional) The URL for the GPG key associated with the Cloudera Manager yum repository.  For Cloudera Manager yum repositories hosted on archive.cloudera.com (including the default repository), the correct URL can be determined on the fly, and so this argument does not need to be supplied. For custom / self-hosted repositories, the argument is required.

The CDH parcel URL and Cloudera Manager yum repository URLs together determine the versions of Cloudera Manager and CDH available on the Image. Be sure that the version indicated in the parcel URL is not later than the version indicated in the Cloudera Manager URL; that is, Cloudera Manager cannot work with CDH versions newer than itself.

The script also accepts several options. Some of them are described below. Run the script with the `-h` option for help.

### Running the script

You must ensure Azure credentials are placed into a file named credentials.json for the script to work properly. See the credentials.json.example file for the proper format.  In order to obtain the necessary credentials, see the [Azure Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-create-service-principal-portal).  You must also assign subscription level *Contributor* permissions to the service pricipal that you create.

Running the script in the trivial case is simple: supply the region, resource group, and OS. The script selects a base image and installs Cloudera Manager and a CDH parcel using the default URLs.

    $ bash build-image.sh WestUS Images_RG centos74

To use a non-default version of Cloudera Manager and CDH, specify their URLs.

    $ bash build-image.sh WestUS Images_RG centos74 MyPreloadedImage_CentOS74_CDH5.8 \
    > https://archive.cloudera.com/cdh5/parcels/5.8/ \
    > https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.8/

#### Specifying VNET, subnet, and Network Security Group

Packer will use the appropriate networking defaults and set up a temporary resource group to use while provisioning its build instance. The build-image.sh script allows the use of a `PACKER_VARS` environment variable in order to provide more control with any options specified in the [Packer documentation](https://www.packer.io/docs/builders/azure.html).


Either export the `PACKER_VARS` environment variable before running, or set it along with the command to run the script.

    $ PACKER_VARS="-var build_resource_group_name=Packer_build_RG -var virtual_network_name=My_VNET -var virtual_network_resource_group_name=Packer_build_RG -var virtual_network_subnet_name=Packer_build_subnet" \
    > bash build-image.sh WestUS2 Images_RG centos74

Instead of putting the variables into the environment variable directly, you can create a JSON file containing them:

    {
        "build_resource_group_name": "Packer_build_RG",
        "virtual_network_resource_group_name": "Packer_build_RG",
        "virtual_network_name": "My_VNET",
        "virtual_network_subnet_name": "Packer_build_subnet"
    }

Then, refer to that file instead.

    $ PACKER_VARS="-var-file=config.json" bash build-image.sh WestUS2 Images_RG centos74

#### Internal scripts

To perform more work beyond what the included provisioning scripts do, you can place your own scripts and supporting files under scripts/provisioning/internal. Each file in that directory is copied up to /tmp on the Packer build instance, and then the scripts whose names match the pattern `internal*.sh` are executed, in arbitrary order. Internal scripts are run before any other scripts in the Image generation process.

Use an internal script as a hook for necessary custom work. For example, say you need to add lines to /etc/hosts to allow resolution of particular DNS names. An internal script can take care of that.

    #!/usr/bin/env bash
    getent ahosts customhost.mydomain.example || \
      sudo tee -a /etc/hosts > /dev/null <<HOSTS
    203.0.113.101    customhost.mydomain.example
    HOSTS

Each installation script is run under a non-root account, but which should have passwordless sudo enabled. Therefore, remember to use `sudo` for operations that require root privilege.

#### Installation of JCE unlimited strength policy files

Unlimited strength policy files for JCE are not included here, for legal reasons. However, they are usually needed for Kerberos-enabled clusters. To have the files installed into the JDK during Image generation, place the ZIP file containing them, for the Java version being used, into the files/jce directory. The file must be named exactly as follows:

* Java 7: UnlimitedJCEPolicyJDK7.zip
* Java 8: jce_policy-8.zip

Any paths in the ZIP file are ignored; the files are extracted directly into jre/lib/security.

**IMPORTANT:** Before installing the files, check with your security policies and local laws to ensure that you are permitted to use them. They may be downloaded from Oracle.

#### Working with CDH 6

The Hue service included in CDH 6.x has specific requirements beyond what is normally available from Cloudera Manager 6.0 and the underlying operating system. See [this bootstrap script README](../c6/README.md) for more information. A [bootstrap script](../c6/hue-c6.sh) is available for use on cluster instances, but an alternative is to bake the work that the script does into a preloaded image. To do so, pass the `-6` option to the build-image.sh script.

    $ bash build-image.sh -6 WestUS Images_RG centos74 MyPreloadedImage_CentOS74_CDH5.8
    > https://mirror.example.com/cdh6/6.0.0/parcels/ \
    > https://mirror.example.com/cm6/6.0.0/redhat7/yum/

The additional work for Hue is necessary if *all* of the following are true:

* CDH 6.x is being used.
* Cloudera Manager 6.0.x is intended to be used.
* An operating system other than CentOS or Red Hat Enterprise Linux 7 is being used.

Starting with version 6.1, Cloudera Manager can configure Hue in CDH 6.x properly on its own, but only for CentOS and Red Hat Enterprise Linux 7. if you intend to use Cloudera Manager 6.0.x, or if you are building an image for CentOS or Red Hat Enterprise Linux 6, then the `-6` option is still useful.

If the option is not used to bake the work into the image, then you may still specify the bootstrap script in instance templates that use the preloaded image.

Note: A prior version of the build-image.sh script would default to activating this option under certain situations, but this behavior is no longer present. Instead, use the guidance above to explicitly pass the option if it is needed.

#### Pre-extracting Parcels

By default, the build-image.sh script downloads a CDH parcel to the build instance but does not extract it. Cloudera Manager must then perform the extraction work when a cluster is bootstrapped by Director. To instead perform parcel extraction during image generation, pass the `-p` option to the script.

Parcel pre-extraction is only supported for Cloudera Manager version 5.8.0 and higher. Earlier versions will not detect that a parcel is already extracted, and will perform the work again, negating any speed improvement.

### The process of the script

This script takes a while to execute. You can observe Packer's output as it runs. The basic procedure is as follows:

1. Packer creates new Resource Group and networking resources in Azure as necessary.
2. Packer launches a new build VM, based on the base Image.
3. Any internal scripts are run on the VM.
4. Initial software packages are installed.
5. An Oracle JDK and Cloudera Manager are installed from the supplied or default Cloudera Manager repository URL. The Oracle JDK package is made available by Cloudera along with the Cloudera Manager package.
8. Several server processes are enabled or disabled, including disabling SELinux.
9. JCE unlimited strength policy files are installed, if available.
10. A CDH parcel is downloaded from the supplied or default parcel URL, and its checksum is validated. The parcel is placed in and linked to locations expected by Cloudera Manager.
11. If requested, the parcel is pre-extracted (unarchived) into the location expected by Cloudera Manager.
13. Packer stops the build VM.
14. Packer creates a new Managed Image based on the stopped build VM.
15. Packer cleans up the VM and any created network resources.

### <a name="notes"></a>Preloaded Image Notes

#### Parcels and the DISTRIBUTION phase

When observing the bootstrapping process with preloaded images, the DOWNLOADING phase of parcel activation should be skipped, but the DISTRIBUTION phase will still appear when parcels are not pre-extracted. This is because the DISTRIBUTION phase does two things: sends the parcel out to each node, and extracts the parcel. The parcel sending will be skipped because the parcels will already be preloaded onto each node, but the parcel extraction still needs to occur.

If parcels are pre-extracted by using the `-p` option, then the DISTRIBUTION phase should complete very quickly, on the order of 20 to 40 seconds.

#### Instance Type of the Build Instance

The VM Size used for the build VM defaults to Standard_D8_v3 in order to provide adequete network and CPU performance.  The image provisioning process involves downloading packages and parcels, and extracting them, which can be network and CPU intensive.  If you want to use a different VM Size for the build VM then you can add a vm_size variable via PACKER_VARS like:

    $ PACKER_VARS="-var vm_size=Standard_D16_v3" \
    > bash build-image.sh WestUS2 Images_RG centos74

You may use a different instance type for running instances of the resulting preloaded image than the one used to build it.

## Faster Bootstrap for Cloudera Manager (experimental)

Versions of Cloudera Manager starting with 5.9.0 include an *experimental* "Faster Bootstrap" capability. Enabling it can help Cloudera Manager to bootstrap clusters a few minutes faster.

Faster Bootstrap only works for Cloudera Manager starting with version 5.9.0. If the properties described below are included in the configuration for an older version of Cloudera Manager, then deployment bootstrap will fail.

### Automatic Configuration

Starting with version 2.3, Cloudera Altus Director automatically enables Faster Bootstrap for Cloudera Manager versions 5.10.0 and higher. However, you can explicitly configure it as described below to be either enabled or disabled, and Cloudera Altus Director will heed your override.

Cloudera Altus Director does not automatically enable Faster Bootstrap for 5.9.x versions of Cloudera Manager. For those versions, explicitly configure Faster Bootstrap.

### Cloudera Manager 5.9.1 or Later

To configure Faster Bootstrap for **Cloudera Manager version 5.9.1 or later**, set the Cloudera Manager configuration property "enable_faster_bootstrap" to "true" to enable it, or "false" to disable it. A Cloudera Altus Director configuration file includes the property in the top-level "cloudera-manager" section, like this:

    ...
    cloudera-manager {
      ...
      configs {
          CLOUDERA_MANAGER {
            # Configure Faster Bootstrap for 5.9.1+
            enable_faster_bootstrap: true
          }
      }
      ...
    }
    ...

See the [sample configuration file for Faster Bootstrap](../configs/azure.faster-bootstrap.conf) for a complete example.

In the Cloudera Altus Director web UI, the property is specified for a new deployment by pressing the "Cloudera Manager Configurations" button, selecting "Cloudera Manager" for the Scope, and entering the property names and values in the provided table.

### Cloudera Manager 5.9.0

To configure Faster Bootstrap for **Cloudera Manager 5.9.0**, include both the "enable_faster_bootstrap" property and the "enable_fast_dir_create" property, setting both to "true" to enable Faster Bootstrap, or "false" to disable it.

    ...
    cloudera-manager {
      ...
      configs {
          CLOUDERA_MANAGER {
            # Configure Faster Bootstrap for 5.9.0
            enable_faster_bootstrap: true
            enable_fast_dir_create: true
          }
      }
      ...
    }
    ...

In the Cloudera Altus Director web UI, the properties are specified for a new deployment by pressing the "Cloudera Manager Configurations" button, selecting "Cloudera Manager" for the Scope, and entering the property names and values in the provided table.

*Be sure to set both configuration properties to true to enable Faster Bootstrap.* Do not set one without setting the other, or else Cloudera Manager 5.9.0 may fail to bootstrap the cluster. Either set both to true or set both to false. Their default values are both false.

The additional property "enable_fast_dir_create" required by Cloudera Manager 5.9.0 is ignored in later releases, so you do not need to specify it in configurations for them.

### Limitations

If a cluster satisfies any of the following conditions, Faster Bootstrap is either not in full effect, or is not in effect at all.

* the cluster is highly available (HA)
* (Cloudera Manager 5.9.x only) Impala is included as a cluster service
* Kafka is included as a cluster service

### Subject to Change

The Faster Bootstrap capability in Cloudera Manager is experimental. The means of activating it, and its limitations, are subject to change in future releases of Cloudera Altus Director and Cloudera Manager.
