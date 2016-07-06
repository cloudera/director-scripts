# Job dispatch with on-demand clusters

This folder contains a script that shows how starting from a configuration file you
could automate the entire process of creating a cluster, running a job and
terminating the cluster using simple tools like wget and jq.

## Preconditions

Before running the dispatch script you need to install the Cloudera Director server
and create a valid cluster configuration file that can be used to create a cluster
via bootstrap-remote.

You also need to have a job script that will do the desired data processing work. This
script will be executed on the remote cluster.

## Script usage

```
$ ./dispatch.sh -h
Usage: ./dispatch.sh <optional arguments> -f=cluster.conf job-script.sh [file1.jar file2.zip ...]"

Optional arguments:

 -s, --server            server url (default http://localhost:7189)
 -u, --user              server API admin user (default admin)
 -p, --password          server API admin password
 -e, --environment       environment name (default Test Environment)
 -d, --deployment        deployment name (default Test Cloudera Manager)
 -c, --cluster           cluster name (random by default with prefix job_)
 -g, --gateway-group     gateway group name (default masters)
 -n, --ssh-username      ssh username to use to connect to the gateway (default ec2-user)
 -i, --ssh-private-key   ssh private key to use to  connect to the gateway (default ~/.ssh/id_rsa)
 -f, --provision-config  Provision a new cluster with the given config file
 -t, --terminate         Terminate the cluster (default false)

Example usage:

  ./dispatch.sh -u=admin -i=test.pem -f=cluster.conf -t job1.sh data.zip
```
