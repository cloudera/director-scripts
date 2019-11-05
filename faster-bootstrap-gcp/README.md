# Faster Bootstrap with Cloudera Altus Director

There are steps you can take to make the bootstrap of new deployments and clusters faster.

## Custom Image Creation

### Overview

The build-image.sh script creates custom images with Cloudera Manager and a CDH parcel installed (preloaded) for use by Cloudera Altus Director. Using such a custom image can cut down significantly on the time for new cluster creation, as software installation and the downloading and distribution* of the parcel can be skipped.

This script, and the support files beneath it, only support CentOS 6, CentOS 7, Red Hat Enterprise Linux 6, and Red Hat Enterprise Linux 7.

To learn how to use a custom instance, consult the [usage document](instance-usage.md).

\* Please refer to the [Custom Instance Notes](#notes) section for more information about what "parcel distribution" entails.

### Prerequisites

Before running the script, [Packer](https://packer.io/) must be installed. Use version 1.2.0 or newer. Follow the [installation instructions](https://www.packer.io/intro/getting-started/install.html). Be careful about the other "packer" tool often installed on Mac and Red Hat systems.

This script and other scripts it sources require bash 4 or higher. Mac OS X and macOS remain on bash 3, so be sure to install and use bash 4, using [Homebrew](http://brew.sh/) for example.

### Script arguments

The build-image.sh script has three required arguments and four optional arguments.

* The zone. This is the zone that Packer will run on. The resulting custom image will only be available in the region corresponding to that zone.  
* The operating system family. Only `centos-6, centos-7, rhel-6 & rhel-7` are supported. The underlying system will select the latest member of that family to build the custom image from.
* The gcp-project-id. The id of the project in which this instance will be built, and in which this instance will be subsequently available.
* (Optional) The custom image name. This is the name of the resulting custom image. This name must be lower case alphanumeric, including hyphens, no spaces, not longer than 64 characters. The default custom image name includes the
  operating system. The final custom image name has a timestamp concatenated onto the end of it
  automatically.
* (Optional) The CDH parcel URL. This script will download a parcel from this URL to preload and
  possibly pre-extract onto the new CUSTOM IMAGE. This argument defaults to
  https://archive.cloudera.com/cdh6/6.0/parcels/.
* (Optional) The Cloudera Manager yum repository URL. This script will download and install
  Cloudera Manager from packages at this URL onto the new CUSTOM IMAGE. This argument defaults to
  https://archive.cloudera.com/cm6/6.0/redhat7/yum/.
* (Optional) The URL for the GPG key associated with the Cloudera Manager yum repository.  For
  Cloudera Manager yum repositories hosted on archive.cloudera.com (including the default
  repository), the correct URL can be determined on the fly, and so this argument does not need
  to be supplied. For custom / self-hosted repositories, the argument is required.

The CDH parcel URL and Cloudera Manager yum repository URLs together determine the versions of Cloudera Manager and CDH available on the custom image. Be sure that the version indicated in the parcel URL is not later than the version indicated in the Cloudera Manager URL; that is, Cloudera Manager cannot work with CDH versions newer than itself.

The script also accepts several options. Some of them are described below. Run the script with the
`-h` option for help.

### Running the script

Before you run the script, your environment must be configured to permit `packer` to obtain valid GCP privileges for the gcp-project in which this custom image will be built and subsequently available. Exactly how `packer` makes this determination is explain in the packer docs under the heading [Precedence of Authentication Methods](https://www.packer.io/docs/builders/googlecompute.html#precedence-of-authentication-methods). This system was tested by creating default application credentials as per [Authentication](https://gcloud-python.readthedocs.io/en/latest/core/auth.html#overview):

```
gcloud auth application-default login
Your browser has been opened to visit:

    https://accounts.google.com/o/oauth2/auth?redirect_uri=http%3A%2F%2Flocalhost%3A8085%2F&prompt=select_account&response_type=code&client_id=764086051850-6qr4p6gpi6hn506pt8ejuq83di341hur.apps.googleusercontent.com&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fuserinfo.email+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcloud-platform&access_type=offline



Credentials saved to file: [/Users/toby/.config/gcloud/application_default_credentials.json]

These credentials will be used by any library that requests
Application Default Credentials.

To generate an access token for other uses, run:
  gcloud auth application-default print-access-token
```
Packer will automatically pick up that file `/Users/toby/.config/gcloud/application_default_credentials.json` (using your own home directory) and should then work.

If you see things like this:
```
==> googlecompute: * Get https://www.googleapis.com/compute/v1/projects/gcp-se/global/images/family/centos-7?alt=json: oauth2: cannot fetch token: 400 Bad Request
==> googlecompute: Response: {
==> googlecompute:   "error": "invalid_grant",
==> googlecompute:   "error_description": "Bad Request"
==> googlecompute: }
```
then you've not got your authentication working properly.


Running the script in the trivial case is simple: supply the zone,OS family and gcp project id. The script selects a base custom image automatically and installs Cloudera Manager and a CDH parcel using the default URLs.

    $ bash build-image.sh us-east1-a centos-7 gcp-se

To use a non-default version of Cloudera Manager and CDH, specify their URLs.

    $ bash build-image.sh us-east1-a centos-7 gcp-se instance-name \
    > https://archive.cloudera.com/cdh5/parcels/5.8/ \
    > https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.8/

#### Internal scripts

To perform more work beyond what the included provisioning scripts do, you can place your own scripts and supporting files under scripts/provisioning/internal. Each file in that directory is copied up to /tmp on the Packer build instance, and then the scripts whose names match the pattern `internal*.sh` are executed, in arbitrary order. Internal scripts are run before any other scripts in the custom-instance generation process.

Use an internal script as a hook for necessary custom work. For example, say you need to add lines to /etc/hosts to allow resolution of particular DNS names. An internal script can take care of that.

    #!/usr/bin/env bash
    getent ahosts customhost.mydomain.example || \
      sudo tee -a /etc/hosts > /dev/null <<HOSTS
    203.0.113.101    customhost.mydomain.example
    HOSTS

Each installation script is run under a non-root account, but which should have passwordless sudo enabled. Therefore, remember to use `sudo` for operations that require root privilege.

#### Installation of JCE unlimited strength policy files

Unlimited strength policy files for JCE are not included here, for legal reasons. However, they are usually needed for Kerberos-enabled clusters. To have the files installed into the JDK during custom image generation, place the ZIP file containing them, for the Java version being used, into the files/jce directory. The file must be named exactly as follows:

* Java 7: UnlimitedJCEPolicyJDK7.zip
* Java 8: jce_policy-8.zip

Any paths in the ZIP file are ignored; the files are extracted directly into jre/lib/security.

**IMPORTANT:** Before installing the files, check with your security policies and local laws to ensure that you are permitted to use them. They may be downloaded from Oracle.

#### Working with CDH 6

The Hue service included in CDH 6.x has specific requirements beyond what is normally available from Cloudera Manager 6.x and the underlying operating system. See [this bootstrap script README](../c6/README.md) for more information. A [bootstrap script](../c6/hue-c6.sh) is available for use on cluster instances, but an alternative is to bake the work that the script does into a custom ami. To do so, pass the `-6` option to the build-image.sh script.

    $ bash build-image.sh -6 us-east1-a centos-7 gcp-se instance-name \
    > https://mirror.example.com/cdh6/6.0.0/parcels/ \
    > https://mirror.example.com/cm6/6.0.0/redhat7/yum/

A custom image built with the `-6` option has the necessary work baked in for Hue in CDH 6.x to work properly, so it's not necessary to also specify the bootstrap script in instance templates that use the custom image. When the option is not used, then the bootstrap script must be used on the custom image.

Note: The build-image.sh script defaults to CDH 6.x parcels. If you don't specify a CDH parcel URL, or if you specify the default CDH parcel URL, then the build-image.sh script assumes that CDH 6.x is being installed, and you don't need to explicitly use the `-6` option. Otherwise, even if the custom CDH parcel URL points to a CDH 6.x parcel repository, you must use the `-6` option for the build-image.sh script to do the work for Hue.

#### Pre-extracting Parcels

By default, the build-image.sh script downloads a CDH parcel to the build instance but does not extract it. Cloudera Manager must then perform the extraction work when a cluster is bootstrapped by Director. To instead perform parcel extraction during custom image generation, pass the `-p` option to the script. We recommend always performing parcel pre-extraction.

Parcel pre-extraction is only supported for Cloudera Manager version 5.8.0 and higher. Earlier versions will not detect that a parcel is already extracted, and will perform the work again, negating any speed improvement.

### The process of the script

This script takes a while to execute (just under 12 minutes). You can observe Packer's output as it runs. The basic procedure is as follows:

1. Packer creates the necessary infrastructure in GCP.
2. Packer launches a new build instance, based on the OS family
3. Any internal scripts are run on the instance.
4. The file system is resized to at least 30 GB, if necessary.
5. The system is rebooted.
6. Initial software packages are installed.
7. An Oracle JDK and Cloudera Manager are installed from the supplied or default Cloudera Manager repository URL. The Oracle JDK package is made available by Cloudera along with the Cloudera Manager package.
8. Several server processes are enabled or disabled, including disabling SELinux.
9. JCE unlimited strength policy files are installed, if available.
10. A CDH parcel is downloaded from the supplied or default parcel URL, and its checksum is validated. The parcel is placed in and linked to locations expected by Cloudera Manager.
11. If requested, the parcel is pre-extracted (unarchived) into the location expected by Cloudera Manager.
12. The system synchronizes the build instance's file system, which leads to a pause. This prevents issues like truncated parcel files in the resulting custom image.
13. Packer stops the build instance.
14. Packer creates a new customer instance based on the stopped build instance.
15. Packer cleans up the instance and any other temporary infrastructure.

### <a name="notes"></a>Custom Instance Notes

#### Parcels and the DISTRIBUTION phase

When observing the bootstrapping process with custom images, the DOWNLOADING phase of parcel activation should be skipped, but the DISTRIBUTION phase will still appear when parcels are not pre-extracted. This is because the DISTRIBUTION phase does two things: sends the parcel out to each node, and extracts the parcel. The parcel sending will be skipped because the parcels will already be preloaded onto each node, but the parcel extraction still needs to occur.

If parcels are pre-extracted by using the `-p` option, then the DISTRIBUTION phase should complete very quickly, on the order of 20 to 40 seconds.

#### Machine Type of the Build Instance

The machine type `n1-standard-` used for the build instance is hardcoded in [rhel.json](packer-json/rhel.json) as the value of "machine_type". This machine type was selected for improved build performance considering the network use made of the machine, as guided by the [5 steps to better GCP network performance](https://cloud.google.com/blog/products/gcp/5-steps-to-better-gcp-network-performance?hl=de) blog.

The machine type of the running instance built using the custom image can be anything you choose; its completely independent of the machine type used to build the customer image.

## Faster Bootstrap for Cloudera Manager 

Versions of Cloudera Manager starting with 5.9.0 include an *experimental* "Faster Bootstrap" capability which became fully released in 5.10. Enabling it can help Cloudera Manager to bootstrap clusters a few minutes faster.

Faster Bootstrap only works for Cloudera Manager starting with version 5.9.0. If the properties described below are included in the configuration for an older version of Cloudera Manager, then deployment bootstrap will fail.

### Automatic Configuration

Starting with version 2.3, Cloudera Altus Director automatically enables Faster Bootstrap for Cloudera Manager versions 5.10.0 and higher. However, you can explicitly configure it as described below to be either enabled or disabled, and Cloudera Altus Director will heed your override.

Cloudera Altus Director does not automatically enable Faster Bootstrap for 5.9.x versions of Cloudera Manager. For those versions, explicitly configure Faster Bootstrap.

### Cloudera Manager 5.9.x (x > 0)

To configure Faster Bootstrap for **Cloudera Manager version 5.9.x or later**, set the Cloudera Manager configuration property "enable_faster_bootstrap" to "true" to enable it, or "false" to disable it. A Cloudera Altus Director configuration file includes the property in the top-level "cloudera-manager" section, like this:

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

See the [sample configuration file for Faster Bootstrap](../configs/aws.faster-bootstrap.conf) for a complete example.

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
