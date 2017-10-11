# Faster Bootstrap with Cloudera Director

There are steps you can take to make the bootstrap of new deployments and clusters faster.

## Preloaded AMI Creation

### Overview

The build-ami.sh script creates AMIs with Cloudera Manager and a CDH parcel installed (preloaded) for use by Cloudera Director. Using such an AMI can cut down significantly on the time for new cluster creation, as software installation and the downloading and distribution* of the parcel can be skipped.

This script, and the support files beneath it, only support CentOS 6, CentOS 7, Red Hat Enterprise Linux 6, and Red Hat Enterprise Linux 7.

To learn how to use a preloaded AMI, consult the [usage document](ami-usage.md).

*Please refer to the [Preloaded AMI Notes](#notes) section for more information about what "parcel distribution" entails.

### Prerequisites

Before running the script, [Packer](https://packer.io/) must be installed. Use version 0.8 or newer. Follow the [installation instructions](https://www.packer.io/intro/getting-started/install.html). Be careful about the other "packer" tool often installed on Red Hat systems.

This script and other scripts it sources require bash 4 or higher. Mac OS X and macOS remain on bash 3, so be sure to install and use bash 4, using [Homebrew](http://brew.sh/) for example.

### Script arguments

The build-ami.sh script has two required arguments and three optional arguments.

* The region. This is the region that Packer will run on. The resulting AMI will only be available
  on this region.
* The operating system. This guides the selection of AMIs and parcels. If you use the optional `-a`
  option described below to point to a specific AMI, that AMI is expected to have this operating
  system installed.
* (Optional) The AMI name. This is the name of the resulting AMI. The default AMI name includes the
  operating system. The final AMI name has a timestamp concatenated onto the end of it
  automatically.
* (Optional) The CDH parcel URL. This script will download a parcel from this URL to preload and
  possibly pre-extract onto the new AMI. This argument defaults to
  http://archive.cloudera.com/cdh5/parcels/5.13/.
* (Optional) The Cloudera Manager yum repository URL. This script will download and install
  Cloudera Manager from packages at this URL onto the new AMI. This argument defaults to
  http://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.13/.

The URLs together determine the version of Cloudera Manager and CDH available on the AMI. Be sure that the version indicated in the parcel URL is not later than the version indicated in the Cloudera Manager URL; that is, Cloudera Manager cannot work with CDH versions newer than itself.

The script also accepts several options. Some of them are described below. Run the script with the
`-h` option for help.

### Running the script

Before you run the script, your environment must be configured with your AWS access key ID and secret access key. Please refer to Packer's documentation [here](https://www.packer.io/docs/builders/amazon.html#specifying-amazon-credentials) for more details, as there are many methods for doing so. For example, you can use environment variables.

    $ export AWS_ACCESS_KEY_ID=...
    $ export AWS_SECRET_ACCESS_KEY=...

Running the script in the trivial case is simple: supply the region and OS. The script selects a base AMI automatically and installs Cloudera Manager and a CDH parcel using the default URLs.

    $ bash build-ami.sh us-east-1 centos72

To use a non-default version of Cloudera Manager and CDH, specify their URLs.

    $ bash build-ami.sh us-east-1 centos72 "AMI name" \
    > http://archive.cloudera.com/cdh5/parcels/5.8/ \
    > http://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.8/

#### Specifying VPC, subnet, and security group

Packer will use the appropriate networking defaults and set up a temporary security group to use while provisioning its build instance. The build-ami.sh script allows the use of a `PACKER_VARS` environment variable in order to provide more control.

|Packer variable name|Description|
|--------------------|-----------|
|vpc_id|The ID of the VPC to use during AMI creation.|
|subnet_id|The ID of the subnet within the VPC to use during AMI creation.|
|security_group_id|The ID of the security group to use during AMI creaiton.|

Either export the `PACKER_VARS` environment variable before running, or set it along with the command to run the script.

    $ PACKER_VARS="-var vpc_id=vpc-12345678 -var subnet_id=subnet-12345678 -var security_group_id=sg-12345678" \
    > bash build-ami.sh us-east-1 centos72

Instead of putting the variables into the environment variable directly, you can create a JSON file containing them:

    {
        "vpc_id": "vpc-12345678",
        "subnet_id": "subnet-12345678",
        "security_group_id": "sg-1235678"
    }

Then, refer to that file instead.

    $ PACKER_VARS="-var-file=config.json" bash build-ami.sh us-east-1 ami-26cc934e "test ami"

#### Specifying a base AMI

The build-ami.sh script consults lookup tables of base AMIs to use for several operating systems and regions. If you specify a region and/or operating system that is not in a lookup table, or if you want to use a different base AMI, then use the `-a` option to provide the AMI ID and associated information. The operating system must still match the AMI, or else the wrong parcels may be installed.

    $ bash build-ami.sh -a "ami-12345678 hvm root /dev/sda1" us-east-1 centos72

The argument for the `-a` option describes the AMI. Each of the following four items must be provided, separated by spaces.

* AMI ID
* virtualization type, either "pv" for paravirtual or "hvm" for HVM
* the username for the default account
* the name of the root device

Remember that you do not need to include this argument unless the base AMI lists do not cover your desired region and operating system, or unless you use a different base AMI.

#### Internal scripts

To perform more work beyond what the included provisioning scripts do, you can place your own scripts and supporting files under scripts/provisioning/internal. Each file in that directory is copied up to /tmp on the Packer build instance, and then the scripts whose names match the pattern "internal*.sh" are executed, in arbitrary order. Internal scripts are run before any other scripts in the AMI generation process.

Use an internal script as a hook for necessary custom work. For example, say you need to add lines to /etc/hosts to allow resolution of particular DNS names. An internal script can take care of that.

    #!/usr/bin/env bash
    getent ahosts customhost.mydomain.example || \
      sudo tee -a /etc/hosts > /dev/null <<HOSTS
    203.0.113.101    customhost.mydomain.example
    HOSTS

Each installation script is run under a non-root account, but which should have passwordless sudo enabled. Therefore, remember to use `sudo` for operations that require root privilege.

#### Installation of JCE unlimited strength policy files

Unlimited strength policy files for JCE are not included here, for legal reasons. However, they are usually needed for Kerberos-enabled clusters. To have the files installed into the JDK during AMI generation, place the ZIP file containing them, for the Java version being used, into the files/jce directory. The file must be named exactly as follows:

* Java 7: UnlimitedJCEPolicyJDK7.zip
* Java 8: jce_policy-8.zip

Any paths in the ZIP file are ignored; the files are extracted directly into jre/lib/security.

**IMPORTANT:** Before installing the files, check with your security policies and local laws to ensure that you are permitted to use them. They may be downloaded from Oracle.

#### Pre-extracting Parcels

By default, the build-ami.sh script downloads a CDH parcel to the build instance but does not extract it. Cloudera Manager must then perform the extraction work when a cluster is bootstrapped by Director. To instead perform parcel extraction during AMI generation, pass the `-p` option to the script.

Parcel pre-extraction is only supported for Cloudera Manager version 5.8.0 and higher. Earlier versions will not detect that a parcel is already extracted, and will perform the work again, negating any speed improvement.

### The process of the script

This script takes a while to execute. You can observe Packer's output as it runs. The basic procedure is as follows:

1. Packer creates new security groups, keys, etc. in EC2 as necessary.
2. Packer launches a new build instance, based on the base AMI.
3. Any internal scripts are run on the instance.
4. The file system is resized to at least 30 GB, if necessary.
5. The system is rebooted.
6. Initial software packages are installed.
7. An Oracle JDK and Cloudera Manager are installed from the supplied or default Cloudera Manager repository URL. The Oracle JDK package is made available by Cloudera along with the Cloudera Manager package.
8. Several server processes are enabled or disabled, including disabling SELinux.
9. JCE unlimited strength policy files are installed, if available.
10. A CDH parcel is downloaded from the supplied or default parcel URL, and its checksum is validated. The parcel is placed in and linked to locations expected by Cloudera Manager.
11. If requested, the parcel is pre-extracted (unarchived) into the location expected by Cloudera Manager.
12. The system synchronizes the build instance's file system, which leads to a pause. This prevents issues like truncated parcel files in the resulting AMI.
13. Packer stops the build instance.
14. Packer creates a new AMI based on the stopped build instance.
15. Packer cleans up the instance and any created security groups, keys, etc.

### <a name="notes"></a>Preloaded AMI Notes

#### Root device locations

For HVM AMIs, the file resize that may occur during the AMI generation process expects that the root device on the base AMI is one of /dev/xvda, /dev/sda, or /dev/sda1. These root devices should be accurate for most HVM AMIs, but it's possible there are unusually crafted AMIs that use a different root device.

#### Parcels and the DISTRIBUTION phase

When observing the bootstrapping process with preloaded AMIs, the DOWNLOADING phase of parcel activation should be skipped, but the DISTRIBUTION phase will still appear when parcels are not pre-extracted. This is because the DISTRIBUTION phase does two things: sends the parcel out to each node, and extracts the parcel. The parcel sending will be skipped because the parcels will already be preloaded onto each node, but the parcel extraction still needs to occur.

If parcels are pre-extracted by using the `-p` option, then the DISTRIBUTION phase should complete very quickly, on the order of 20 to 40 seconds.

#### Preloading parcels and EBS prewarming

When a block on an Amazon EBS volume is accessed for the first time, significant latency occurs due to the way EBS volumes are implemented. This has an impact on parcel extraction, even with parcel preloading. Director will [prewarm](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-prewarm.html) the parcel in order to speed up file system access to the parcel file. However, the extraction will still take some time as a result.

## Faster Bootstrap for Cloudera Manager (experimental)

Versions of Cloudera Manager starting with 5.9.0 include an *experimental* "Faster Bootstrap" capability. Enabling it can help Cloudera Manager to bootstrap clusters a few minutes faster.

Faster Bootstrap only works for Cloudera Manager starting with version 5.9.0. If the properties described below are included in the configuration for an older version of Cloudera Manager, then deployment bootstrap will fail.

### Automatic Configuration

Starting with version 2.3, Cloudera Director automatically enables Faster Bootstrap for Cloudera Manager versions 5.10.0 and higher. However, you can explicitly configure it as described below to be either enabled or disabled, and Cloudera Director will heed your override.

Cloudera Director does not automatically enable Faster Bootstrap for 5.9.x versions of Cloudera Manager. For those versions, explicitly configure Faster Bootstrap.

### Cloudera Manager 5.9.1 or Later

To configure Faster Bootstrap for **Cloudera Manager version 5.9.1 or later**, set the Cloudera Manager configuration property "enable_faster_bootstrap" to "true" to enable it, or "false" to disable it. A Cloudera Director configuration file includes the property in the top-level "cloudera-manager" section, like this:

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

In the Cloudera Director web UI, the property is specified for a new deployment by pressing the "Cloudera Manager Configurations" button, selecting "Cloudera Manager" for the Scope, and entering the property names and values in the provided table.

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

In the Cloudera Director web UI, the properties are specified for a new deployment by pressing the "Cloudera Manager Configurations" button, selecting "Cloudera Manager" for the Scope, and entering the property names and values in the provided table.

*Be sure to set both configuration properties to true to enable Faster Bootstrap.* Do not set one without setting the other, or else Cloudera Manager 5.9.0 may fail to bootstrap the cluster. Either set both to true or set both to false. Their default values are both false.

The additional property "enable_fast_dir_create" required by Cloudera Manager 5.9.0 is ignored in later releases, so you do not need to specify it in configurations for them.

### Limitations

If a cluster satisfies any of the following conditions, Faster Bootstrap is either not in full effect, or is not in effect at all.

* the cluster is highly available (HA)
* (Cloudera Manager 5.9.x only) Impala is included as a cluster service
* Kafka is included as a cluster service

### Subject to Change

The Faster Bootstrap capability in Cloudera Manager is experimental. The means of activating it, and its limitations, are subject to change in future releases of Cloudera Director and Cloudera Manager.
