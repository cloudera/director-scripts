# Cloudera Director Public Scripts

## Contributing Code

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Overview

Cloudera Director has two points during the cluster creation process where custom made user scripts can be run.
Bootstrap scripts are run on an instance on startup, and post-creation scripts are run on the cluster level after a
cluster has been successfully created. This repository is a collection of freely available example scripts that
Cloudera Director users can use to augment their clusters with advanced functionality.

Please refer to the [Cloudera Director documentation](http://www.cloudera.com/content/cloudera/en/documentation/cloudera-director/latest/topics/director_intro.html)
for more details on where and how to add scripts.

## Bootstrap scripts

There are currently no example bootstrap scripts available.

## Post-creation scripts

### high-availability

This post-creation script will configure the HDFS service on a cluster for high availability. The included README.md
and example cluster configurations explain how to construct a cluster for use with this script.

There are Groovy and Python implementations of this script. We recommend using the Python script because Python is
preinstalled on most linux distributions. The Python script depends on the argparse, cm-api, and retrying libraries,
which can be installed by the cm-script-dependency-installer post-creation script.

### kerberos

This post-creation script will configure a cluster to use Kerberos for authentication. An existing KDC must be
supplied; this is demonstrated in the aws.reference.conf that comes with the Cloudera Director client.

The script depends on the argparse, cm-api, and retrying libraries, which can be installed by the
cm-script-dependency-installer post-creation script.

### cm-script-dependency-installer

This post-creation script is meant to be run before either high-availability or kerberos. It will install the
necessary Python dependencies required for both scripts.

## Additional utility scripts

The util directory contains additional utility scripts.
