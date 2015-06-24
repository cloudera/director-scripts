# Cloudera Director preload creation script

## Overview

This is a script that allows for the creation of AMIs preloaded with CDH parcels for use by
Cloudera Director. Preloading parcels cuts down significantly on the bootstrapping time
for new cluster creation, as the downloading and distribution of parcel files can be skipped
by the underlying Cloudera Manager installation. At the moment, this script only supports
CentOS 6.4 through 6.6 and Red Hat Enterprise Linux 6.4 through 6.6.

# Prerequisites

Before running the script, [packer](https://packer.io/) must be installed.

# About the script

The script has 3 required arguments and 1 optional argument:

* The region. This is the region that packer will run on. The resulting AMI will only be
  available on this region.
* The base AMI. Packer will use this AMI as a base to create a preloaded AMI.
* The AMI name. This is the name of the resulting AMI. The AMI name will have a timestamp
  concatenated onto the end of it as well.
* Optionally, the parcel URL. This script will download parcels from this URL to preload
  onto the new AMI. This defaults to http://archive.cloudera.com/cdh5/parcels/5.4/.

Before you run the script, your environment must contain the AWS_SECRET_KEY and
AWS_ACCESS_KEY variables. Please refer to Packer's documentation
[here](https://www.packer.io/docs/builders/amazon-ebs.html) for more details.

Packer, by default, will use the appropriate defaults and set up temporary security groups
to use while provisioning a new instance. This script allows the use of a `PACKER_VARS`
environment variable in order to provide more detailed customization.

# Available packer variables

|Packer variable name|Description|
|--------------------|-----------|
|vpc_id|The ID of the VPC to use during AMI creation.|
|subnet_id|The ID of the subnet within the VPC to use during AMI creation.|
|security_group_id|The ID of the security group to use during AMI creaiton.|
|ami_virtualization_type|The type of virtualization the supplied base AMI uses. Valid values are `paravirtual` and `hvm`.|
|root_device_name|The name of the root device on the base AMI. Defaults to /dev/sda.|
|ssh_username|The username used to SSH into the base AMI. Defaults to ec2-user.|

# Running the script

Running the script in the trivial case is simple:

    sh build-ami.sh us-east-1 ami-26cc934e "AMI name"

Running the script with a non-default parcel URL is also straightforward:

    sh build-ami.sh us-east-1 ami-26cc934e "AMI name" http://archive.cloudera.com/cdh5/parcels/5.4/

However, if you have a more customzied AWS setup, you will need to supply packer variables through the `PACKER_VARS`
environment variable:

    PACKER_VARS="-var vpc_id=vpc-12345678 -var subnet_id=subnet-12345678 -var security_group_id=sg-12345678" sh build-ami.sh us-east-1 ami-26cc934e "test ami"

Alternatively, you can create a json file with the appropriate variables filled out:

    {
        'vpc_id': 'vpc-12345678',
        'subnet_id': 'subnet-12345678',
        'security_group_id': 'sg-1235678'
    }

and refer to that instead:

    PACKER_VARS="-var-file=config.json" sh build-ami.sh us-east-1 ami-26cc934e "test ami"

# The process of the script

This script can take several minutes, and goes through the following steps:

1. Packer creates new security groups, keys, etc. as necessary.
2. Packer instantiates a new base AMI image.
3. The filesystem is resized to 30 GB.
4. The system is rebooted.
5. Parcels are downloaded from the supplied parcel URL.
6. The system pauses for 5 minutes to allow the AMI's filesystem to sync properly. This prevents issues like
   truncated parcel files in the resulting AMI.
7. Packer stops the modified AMI.
8. Packer creates a new AMI based on the stopped AMI.
9. Finally, Packer cleans up the existing instance and any created security groups, keys, etc.

# Notes

For HVM AMIs, the file resize that occurs as part of this script expects the root device on
the base AMI to be /dev/xvda, /dev/sda, or /dev/sda1. These root devices should be accurate for
most HVM AMIs, but it's possible there are unusually crafted AMIs that use a different root device.