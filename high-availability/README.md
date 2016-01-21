# Enabling High Availability for HDFS
These scripts are intended for enabling high availability (HA) for the HDFS service on clusters
newly created by Cloudera Director 1.5.x. HA clusters can be created directly by
Cloudera Director 2.0.

These scripts call Cloudera Manager's hdfsEnableNnHa API command to enable HA for the HDFS service.
These scripts require the cluster be preconfigured with the appropriate role assignments
(see Cluster Preconditions) since these scripts are not able to determine to which hosts to assign
each role.

After calling hdfsEnableNnHa, these scripts will call hiveUpdateMetastoreNamenodes and restart Impala
to finish updating the cluster for using HA HDFS.

## Cluster Preconditions
The target cluster must satisfy the following criteria:
- Includes 1 NAMENODE
- Includes 1 SECONDARYNAMENODE
- Includes 3+ JOURNALNODES

This script cannot automatically select hosts for JOURNALNODES and thus requires the JOURNALNODES
to be pre-configured. These can be defined in the cluster template that Cloudera Director uses.

Enabling HA will replace the SECONDARYNAMENODE with a NAMENODE role and will colocate
FAILOVERCONTROLLER roles with the NAMENODEs.

If the cluster contains a HUE service, then HDFS must also have an HTTPFS role assigned.

## Script Usage
These directories include scripts to enable HA in python and groovy.

### Groovy
You specify the cluster name and nameservice when you run the script. Additionally, you can specify the
`--host`, `--port`, `--username`, and `--password` arguments for connecting to your
Cloudera Manager.

```
    $ ./enableHdfsHa --host myhost.example.com CLUSTERNAME NAMESERVICE
```

### Python
Running the python script requires `cm_api` to be installed. This is included in the requirements.txt file.
```
    $ pip install -r requirements.txt
```
You specify the cluster name and nameservice when you run the script. Additionally, you can specify the
`--host`, `--port`, `--username`, and `--password` arguments for connecting to your
Cloudera Manager.

```
    $ ./enable-hdfs-ha.py --host myhost.example.com CLUSTERNAME NAMESERVICE
```
