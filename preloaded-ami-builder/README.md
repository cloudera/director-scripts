# Cloudera Director preload creation script

## Overview

The build-ami.sh script creates AMIs preloaded with CDH parcels for use by Cloudera Director.
Preloading parcels cuts down significantly on the bootstrapping time for new cluster creation, as
the downloading and distribution* of parcel files can be skipped by the underlying Cloudera Manager
installation. At the moment, this script only supports CentOS 6, CentOS 7, Red Hat Enterprise Linux
6, and Red Hat Enterprise 7.

*Please refer to the [Notes](#notes) section for more information about what "parcel distribution"
entails.

## Prerequisites

Before running the script, [Packer](https://packer.io/) must be installed. Use version 0.8 or
newer.

This script and other scripts it sources require bash 4 or higher.

## About the script

The build-ami.sh script has two required arguments and three optional arguments.

* The region. This is the region that Packer will run on. The resulting AMI will only be available
  on this region.
* The operating system. This guides the selection of AMIs and parcels. An AMI specified to the
  script using the `-a` option is expected to have this operating system installed.
* (Optional) The AMI name. This is the name of the resulting AMI. The AMI name will include the
  operating system and have a timestamp concatenated onto the end of it.
* (Optional) The CDH parcel URL. This script will download parcels from this URL to preload
  onto the new AMI. This defaults to http://archive.cloudera.com/cdh5/parcels/5.7/.
* (Optional) The Cloudera Manager yum repository URL. This script will download and install
  Cloudera manager from packages at this URL onto the new AMI. This defaults to
  http://archive.cloudera.com/cm5/redhat/6/x86_64/cm/.

Before you run the script, your environment must be configured with your AWS access key ID and
secret access key. Please refer to Packer's documentation
[here](https://www.packer.io/docs/builders/amazon-ebs.html) for more details.

## Running the script

Running the script in the trivial case is simple:

    bash build-ami.sh us-east-1 centos64 "AMI name"

Running the script with a non-default parcel URL is also straightforward:

    bash build-ami.sh us-east-1 centos64 "AMI name" http://archive.cloudera.com/cdh5/parcels/5.6/

### Specifying VPC, subnet, and security group

Packer will use the appropriate networking defaults and set up temporary security groups to use
while provisioning a new instance. This script allows the use of a `PACKER_VARS` environment
variable in order to provide more detailed customization.

|Packer variable name|Description|
|--------------------|-----------|
|vpc_id|The ID of the VPC to use during AMI creation.|
|subnet_id|The ID of the subnet within the VPC to use during AMI creation.|
|security_group_id|The ID of the security group to use during AMI creaiton.|

    PACKER_VARS="-var vpc_id=vpc-12345678 -var subnet_id=subnet-12345678 -var security_group_id=sg-12345678" bash build-ami.sh us-east-1 centos64 "test ami"

Alternatively, you can create a json file with the appropriate variables filled out:

    {
        'vpc_id': 'vpc-12345678',
        'subnet_id': 'subnet-12345678',
        'security_group_id': 'sg-1235678'
    }

and refer to that instead:

    PACKER_VARS="-var-file=config.json" bash build-ami.sh us-east-1 ami-26cc934e "test ami"

### Specifying a base AMI

This script consults lookup tables of base AMIs to use for several operating systems and regions.
If you specify a region and/or operating system that is not in a lookup table, or if you want to
use a different base AMI, then use the `-a` option to provide the AMI ID and associated information.
The operating system must still match the AMI, or else the wrong parcels may be installed.

    bash build-ami.sh -a "ami-35463e5c hvm root /dev/sda1" us-east-1 centos64

The argument for the `-a` option describes the AMI.

* AMI ID
* virtualization type, either "pv" for paravirtual or "hvm" for HVM
* the username for the default account
* the name of the root device

### Internal scripts

Beyond the provisioning scripts that are already included, you can place your own scripts under
scripts/provisioning/internal. The scripts there are copied up to /tmp on the working instance and
executed (in no specific order) immediately after the instance is instantiated. Use this as a hook
for custom work that needs to be done.

### Installation of JCE unlimited strength policy files

Unlimited strength policy files for JCE are not included, for legal reasons. However, they are
usually needed for Kerberos-enabled clusters. If the ZIP file containing the policy files for the
Java version being used is placed in files/jce, then it is installed into the JDK during AMI
generation. The file must be named as follows:

* Java 7: UnlimitedJCEPolicyJDK7.zip
* Java 8: jce_policy-8.zip

Any paths in the ZIP file are ignored; the files are extracted directly into jre/lib/security.

Before installing the files, check with your security policies and local laws to ensure that you
are permitted to use them. They may be downloaded from Oracle.

## The process of the script

This script can take several minutes, and goes through the following steps:

1. Packer creates new security groups, keys, etc. as necessary.
2. Packer instantiates a new instance based on the base AMI.
3. Any internal scripts are run on the instance.
4. The file system is resized to 30 GB.
5. The system is rebooted.
6. Cloudera Manager is installed from the supplied Cloudera Manager repository URL.
7. Parcels are downloaded from the supplied parcel URL and, if requested, extracted.
8. The system pauses for 5 minutes to allow the AMI's file system to sync properly. This prevents
   issues like truncated parcel files in the resulting AMI.
9. Packer stops the instance.
10. Packer creates a new AMI based on the stopped instance.
11. Finally, Packer cleans up the instance and any created security groups, keys, etc.

## <a name="notes"></a>Notes

### Root device locations

For HVM AMIs, the file resize that occurs as part of this script expects the root device on
the base AMI to be /dev/xvda, /dev/sda, or /dev/sda1. These root devices should be accurate for
most HVM AMIs, but it's possible there are unusually crafted AMIs that use a different root device.

### Parcels and the DISTRIBUTION phase

When observing the bootstrapping process with preloaded AMIs, the DOWNLOADING phase of parcel
activation should be skipped, but the DISTRIBUTION phase will still appear when parcels are not
pre-extracted. This is because the DISTRIBUTION phase does two things: sends the parcel out to each
node, and extracts the parcel. The parcel sending will be skipped because the parcels will already
be preloaded onto each node, but the parcel extraction still needs to occur.

If parcels are pre-extracted by using the `-p` option, then the DISTRIBUTION phase should be skipped
entirely.

### Preloading parcels and EBS prewarming

When a block on an Amazon EBS volume is accessed for the first time, significant latency occurs due
to the way EBS volumes are implemented. This has an impact on parcel extraction, even with parcel
preloading. Director will
[prewarm](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-prewarm.html) the parcel in order
o speed up file system access to the parcel file. However, the extraction will still take some time
as a result.
