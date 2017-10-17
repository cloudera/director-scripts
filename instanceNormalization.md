# Cloudera Director instance normalization

Instance normalization is a procedure run by Cloudera Director after completing custom bootstrap script(s). The procedure involves the following steps:

 * prewarm parcel directory
 * install required packages
 * start/stop miscellaneous services
 * minimize swapping
 * adjust user limit of open file descriptors
 * resize root partition
 * mount all unmounted block devices

The steps can be disabled individually by setting the flag for each step to false in server/etc/application.properties:
```sh
# lp.normalization.prewarmDirectoryRequired: true
# lp.normalization.installPackagesRequired: true
# lp.normalization.miscellaneousServiceAdjustmentRequired: true
# lp.normalization.minimizeSwappinessRequired: true
# lp.normalization.increaseMaxNumberOfOpenFilesRequired: true
# lp.normalization.resizeRootPartitionRequired: true
# lp.normalization.mountAllUnmountedDisksRequired: true
```
or completely disabled in the same file:
```sh
# lp.normalization.required: true
```
The procedure can also be disabled completely per virtual instance group by setting the normalizeInstance flag for the instance template to false when using a Cloudera Director client library.

The following is a detailed description of what each steps is doing.

### prewarm parcel directory

If the flag is enabled (by default), Cloudera Director will run dd on the parcel directory, which will force the retrieval of the blocks from S3 if the volume is backed by EBS in AWS, and warm up the file cache.

### install required packages

If this step is enabled, Cloudera Director will install ntp, curl, and nscd on the instance. If python is not installed, Cloudera Director will install python as well. Also depending upon the virtualization type, Cloudera Director will install gdisk if the instance uses hardware assisted virtualization.

### start/stop miscellaneous services

If the distro is Redhat compatible, Cloudera Director will start/enable and stop/disable some of the services on the instance. First it will set SELinux to permissive mode and configure it to be fully disabled on the next reboot. Then it will stop/disable:
 - cups
 - postfix
 - iptables
 - ip6tables
 - transparent hugepages
 - IPv6
 - tuned
 - firewalld

 and start/enable
 - chronyd for RHEL 7 and ntpd for other versions
 - nscd

### minimize swapping
Cloudera Director will minimize the amount of swapping without disabling it totally by setting vm.swappiness to 1.

### adjust user limit of open file descriptors
Cloudera Director will adjust the user limit (hard and soft) of open file descriptor to 32768 if this step is enabled.

### resize root partition
If this step is enabled, Cloudera Director will resize the root partition to use up as much available disk space as possible. The user can override the default script used by each plugin by providing a customized script under the plugin etc directory with the name "rewrite_root_disk_partition_table".

### mount all unmounted block devices
If this step is enabled, Cloudera Director will try to format each block device as ext4 if possible (falling back to ext3 on failure), and mount them under /data[0-9]+ starting from /data0. So if there are two block devices, they will be mounted under /data0 and /data1. The user can override the default script used by each plugin by providing a customized script under the plugin etc directory with the name "prepare_unmounted_volumes".
