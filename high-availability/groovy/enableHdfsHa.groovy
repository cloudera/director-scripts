#!/usr/bin/env groovy
//
// (c) Copyright 2015 Cloudera, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@Grab(group = 'com.cloudera.api', module = 'cloudera-manager-api', version = '5.3.1')

import com.cloudera.api.ApiRootResource
import com.cloudera.api.ClouderaManagerClientBuilder
import com.cloudera.api.DataView
import com.cloudera.api.model.*
import com.cloudera.api.v6.ClustersResourceV6
import com.cloudera.api.v6.RolesResourceV6
import com.cloudera.api.v6.RootResourceV6
import com.cloudera.api.v6.ServicesResourceV6

/**
 * Get the output stream. Defaults to System.out if not defined.
 * This mirrors the way groovy's println and print methods work.
 */
def getOutputStream() {
    try {
        return getProperty("out")
    } catch (MissingPropertyException e) {
    }
    return System.out
}

/**
 * Wait for Api Command to finish method
 */
def waitForApiCommand(RootResourceV6 rootResource, long commandId) {
    println "Waiting for command ${commandId} to finish"

    // Grab the output stream so we can ensure it flushes.
    def out = getOutputStream()

    def command = rootResource.getCommandsResource().readCommand(commandId)
    while (command.isActive()) {
        out.print '.'
        out.flush()
        sleep(15000)
        command = rootResource.getCommandsResource().readCommand(commandId)
    }
    println 'Command finished'
}

/**
 * Create hdfsEnableNnHa arguments method
 */
ApiEnableNnHaArguments createHdfsEnableNnHaArguments(ServicesResourceV6 servicesResource, String serviceName, String nameservice) {
    def apiRoles = servicesResource.getRolesResource(serviceName).readRoles().getRoles()
    def activeNnName = apiRoles.find({it.getType() == 'NAMENODE'})?.getName()
    def secondaryNnHost = apiRoles.find({it.getType() == 'SECONDARYNAMENODE'})?.getHostRef()?.getHostId()
    assert activeNnName : "Unable to determine Active NameNode name"
    assert secondaryNnHost : "Unable to determine host to run Standby NameNode"

    ApiEnableNnHaArguments arguments = new ApiEnableNnHaArguments()
    arguments.setActiveNnName(activeNnName)
    arguments.setNameservice(nameservice)
    arguments.setStandbyNnHostId(secondaryNnHost)
    arguments.setForceInitZNode(true)
    arguments.setClearExistingStandbyNameDirs(true)
    arguments.setClearExistingJnEditsDir(true)

    return arguments
}

/**
 * Invoke hdfsEnableNnHa method
 */
def invokeHdfsEnableNnHa(RootResourceV6 rootResource, String cluster, String namespace) {
    ServicesResourceV6 servicesResource = rootResource.getClustersResource().getServicesResource(cluster)

    ApiService hdfsService = servicesResource.readServices(DataView.SUMMARY).find {it.getType() == 'HDFS'}
    assert hdfsService : "No HDFS service found"

    ApiEnableNnHaArguments haArguments = createHdfsEnableNnHaArguments(servicesResource, hdfsService.getName(), namespace)

    println "Calling hdfsEnableNnHa command"
    ApiCommand enableHaCmd = servicesResource.hdfsEnableNnHaCommand(hdfsService.getName(), haArguments)

    waitForApiCommand(rootResource, enableHaCmd.getId())
    println "HA has been enabled for HDFS service on cluster $cluster"
}

/**
 * Validate cluster
 */
def validateCluster = { RootResourceV6 rootResource, String clusterName ->
    println "Validating cluster"

    ClustersResourceV6 clustersResource = rootResource.getClustersResource()
    ServicesResourceV6 servicesResource = clustersResource.getServicesResource(clusterName)

    // ensure cluster exists
    try {
        clustersResource.readCluster(clusterName)
    } catch (Exception e) {
        throw new Exception("Unable to get information on cluster named $clusterName", e)
    }

    // ensure all services are started and healthy
    List<ApiService> services = servicesResource.readServices(DataView.FULL).getServices()
    services.each {
        assert it.serviceState == ApiServiceState.STARTED : "Service ${it.getName()} not started"
        assert it.healthSummary == ApiHealthSummary.GOOD : "Service ${it.getName()} not healthy"
    }

    // ensure that cluster has an HDFS service
    ApiService hdfsService = services.find({it.getType() == 'HDFS'})
    assert hdfsService : 'No HDFS service detected'

    RolesResourceV6 rolesResource = servicesResource.getRolesResource(hdfsService.getName())
    List<ApiRole> roles = rolesResource.readRoles().getRoles()

    // ensure NameNode, SecondaryNameNode, and 3 JournalNodes exist
    assert roles.find {it.getType() == 'NAMENODE'} : 'No NAMENODE found'
    assert roles.find {it.getType() == 'SECONDARYNAMENODE'} : 'No SECONDARYNAMENODE found'
    assert roles.findAll {it.getType() == 'JOURNALNODE'}.size() >= 3 : '3 JOURNALNODES not found'

    ApiService hueService = services.find({it.getType() == 'HUE'})
    if (hueService) {
        assert roles.find {it.getType() == 'HTTPFS'} : 'Expected an HTTPFS role if HUE service is present'
    }

    println "Cluster passed validation"
}

/**
 * Update Hive to use HA HDFS
 */
def updateHiveForHaHdfs(RootResourceV6 rootResource, String cluster) {
    ServicesResourceV6 servicesResource = rootResource.getClustersResource().getServicesResource(cluster)

    ApiService hiveService = servicesResource.readServices(DataView.SUMMARY).find {it.getType() == 'HIVE'}
    if (!hiveService) {
        return
    }

    println "Stopping Hive"
    ApiCommand stopHiveCmd = servicesResource.stopCommand(hiveService.getName())
    waitForApiCommand(rootResource, stopHiveCmd.getId())
    println "Hive stopped"

    println "Updating Hive Metastore Namenodes"
    ApiCommand updateHiveCmd = servicesResource.hiveUpdateMetastoreNamenodesCommand(hiveService.getName())
    waitForApiCommand(rootResource, updateHiveCmd.getId())
    println "Hive Metastore Namenodes updated"

    println "Starting Hive"
    ApiCommand startHiveCmd = servicesResource.startCommand(hiveService.getName())
    waitForApiCommand(rootResource, startHiveCmd.getId())
    println "Hive started"

    restartImpala(rootResource, cluster)
}

/**
 * Restart Impala
 */
def restartImpala(RootResourceV6 rootResource, String cluster) {
    ServicesResourceV6 servicesResource = rootResource.getClustersResource().getServicesResource(cluster)

    ApiService impalaService = servicesResource.readServices(DataView.SUMMARY).find {it.getType() == 'IMPALA'}
    if (!impalaService) {
        return
    }

    println "Restarting Impala"
    ApiCommand restartImpalaCmd = servicesResource.restartCommand(impalaService.getName())
    waitForApiCommand(rootResource, restartImpalaCmd.getId())
    println "Finished restarting Impala"
}

/**
 * Restart MGMT services
 */
def restartMgmtServices(RootResourceV6 rootResource) {
    println "Restarting MGMT services"
    ApiCommand restartMgmtServiceCmd = rootResource.getClouderaManagerResource().getMgmtServiceResource().restartCommand();
    waitForApiCommand(rootResource, restartMgmtServiceCmd.getId())
    println "Finished restarting MGMT services"
}

/**
 * Main script
 */

// Parse arguments from command line
CliBuilder cli = new CliBuilder(usage: 'enableHdfsHa.groovy -hopuw [cluster] [namespace]')
cli.with {
    h longOpt: 'help', "Print help"
    o longOpt: 'host', args: 1, argName: 'host', 'Cloudera Manager hostname'
    p longOpt: 'port', args: 1, argName: 'port', 'Cloudera Manager port'
    u longOpt: 'username', args: 1, argName: 'username', 'Cloudera Manager username'
    w longOpt: 'password', args: 1, argName: 'password', 'Cloudera Manager password'
}
OptionAccessor options = cli.parse(args)
if (!options) {
    // Expect that parse will print usage if it failed. No need to print anything else
    return
}

// Check of help was requested. Print help and exit
if (options.h) {
    println """This script is used to enable HA for the HDFS service on a newly created cluster.

The target cluster must satisfy the following criteria:
    Includes 1 NAMENODE
    Includes 1 SECONDARYNAMENODE
    Includes 3+ JOURNALNODES

This script cannot automatically select hosts for JOURNALNODES and thus requires the JOURNALNODES
to be pre-configured. These can be defined in the cluster template that Cloudera Director uses.

Enabling HA will replace the SECONDARYNAMENODE with a NAMENODE role and will colocate
FAILOVERCONTROLLER roles with the NAMENODEs.

HIVE will be updated after HA is enabled for HDFS. This involves stopping HIVE, calling the Update
Metastore Namenodes command, and starting HIVE. Impala will be restarted to invalidate any queries.
Normally it is recommended that the Hive Metastore be backed up prior to Update Metastore Namenodes
but it is assumed that there is no data in the Hive Metastore when this script is run.

If the cluster contains a HUE service, then HDFS should be configured with a HTTPFS role prior to
running this script. Otherwise the user will need to manually add an HTTPFS role and restart HUE.
"""
    cli.usage()
    return
}

// Ensure that expected arguments are provided
if (options.arguments().size() != 2) {
    println 'Command expects exactly two arguments.'
    cli.usage()
    return
}

String cluster = options.arguments().get(0)
String namespace = options.arguments().get(1)

// Create CM Client, using default values if not specified
ApiRootResource api = new ClouderaManagerClientBuilder()
        .withHost(options.o ?: 'localhost')
        .withPort(options.p?.toInteger() ?: 7180)
        .withUsernamePassword(options.u ?: "admin", options.w ?: "admin")
        .build();
try {
    RootResourceV6 rootResource = api.getRootV6()

    validateCluster(rootResource, cluster)
    invokeHdfsEnableNnHa(rootResource, cluster, namespace)
    updateHiveForHaHdfs(rootResource, cluster)
    restartMgmtServices(rootResource)
} finally {
    ClouderaManagerClientBuilder.closeClient(api)
}
