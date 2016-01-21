# Script to simplify Cloudera Director usage by creating an initial environment
and instance templates.

## Overview

The setup-default python script consumes the same configuration file that would
normally be used by Cloudera Director's boostrap-remote command, but instead of
creating a cluster, it creates an environment and instance templates to simplify
cluster creation in the Cloudera Director UI. Note that AWS Quick Start creates
a reference configuration file when it installs Cloudera Director.

## Requirements

The script requires the Cloudera Director python API, as well as the pyhocon library
(https://github.com/chimpler/pyhocon) for parsing HOCON configuration files.

These libraries can be installed in a virtual environment as follows:

```
virtualenv --distribute --no-site-packages myenv
. myenv/bin/activate
pip install -r requirements.txt
```

## Execution

```
python setup-default.py --admin-username admin --admin-password admin aws.reference.conf
```
