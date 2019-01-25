# Deploying a Java 8 cluster

## JavaInstallationStrategy configuration

In order to use this bootstrap script, you'll need to configure your deployment to use a
`javaInstallationStrategy` of `NONE`. This can be done using a configuration file or using the
Cloudera Altus Director API, as this property is not currently configurable in the UI.
An example of how this would look in a configuration file:

```
...
cloudera-manager {

    instance: ${instances.m3x} {
        tags {
            application: "Cloudera Manager 5"
        }
    }

    javaInstallationStrategy: NONE
    ...
}
```

After the deployment has been created, adding additional Java 8 clusters will be possible from
the UI using the bootstrap script.

## Bootstrap script

Simply use `java8-bootstrap-script.sh` as the bootstrap script for the instance templates
in your cluster.  This will install Java 8, which will be used to run Cloudera Manager and all
of the various cluster services. An example of how this could look in a configuration file:

```
instances {
    m3x {
        type: m3.xlarge
        image: ami-6283a827
        bootstrapScriptsPaths: ["/script-path/java8-bootstrap-script.sh"]
    }
}
```

Alternatively, you can copy the contents of the bootstrap script itself and use the `bootstrapScripts`
property instead.

**NOTE**: The URL in this script refers to CentOS/RHEL 7 and Director 6.1.0. You may need to update the URL
for CentOS/RHEL 6 depending on what OS your deployment/cluster instances are running.
