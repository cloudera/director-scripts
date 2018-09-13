# Enabling High Availability for HDFS

_NOTE: Cloudera Altus Director 2.0 and higher can enable HA in clusters without the use
of scripts. The resources here apply only to Altus Director 1.5._

These scripts call Cloudera Manager's `hdfsEnableNnHa` API command to enable high availability (HA)
for the HDFS service. They require that the cluster be preconfigured with the appropriate role
assignments (see Cluster Preconditions) since they are not able to determine to which hosts to
assign each role.

After calling `hdfsEnableNnHa`, these scripts call `hiveUpdateMetastoreNamenodes` and restart Impala
to finish updating the cluster for using HA HDFS.

## Cluster Preconditions

The target cluster must satisfy the following criteria:

- Includes 1 NAMENODE
- Includes 1 SECONDARYNAMENODE
- Includes 3+ JOURNALNODES

The scripta cannot automatically select hosts for JOURNALNODES and thus require the JOURNALNODES
to be pre-configured. These can be defined in the cluster template that Cloudera Altus Director
uses.

Enabling HA will replace the SECONDARYNAMENODE with a NAMENODE role and will colocate
FAILOVERCONTROLLER roles with the NAMENODEs.

If the cluster contains a HUE service, then HDFS must also have an HTTPFS role assigned.

## Script Usage

These directories include scripts to enable HA in python and groovy.

### Groovy

Specify the cluster name and nameservice when you run the script. Additionally, you can specify
`--host`, `--port`, `--username`, and `--password` arguments for connecting to your
Cloudera Manager installation.

```
$ ./enableHdfsHa --host myhost.example.com CLUSTERNAME NAMESERVICE
```

### Python

Running the python script requires `cm_api` to be installed. This is included in the
requirements.txt file.

```
$ pip install -r requirements.txt
```

Specify the cluster name and nameservice when you run the script. Additionally, you can specify
`--host`, `--port`, `--username`, and `--password` arguments for connecting to your
Cloudera Manager installation.

```
$ ./enable-hdfs-ha.py --host myhost.example.com CLUSTERNAME NAMESERVICE
```
