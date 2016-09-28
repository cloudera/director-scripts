#
# Copyright (c) 2016 Cloudera, Inc. All rights reserved.
#

./dispatch.sh -f=cluster_preloaded_amis.conf -t hive_job.sh query.sql | tee output.file
