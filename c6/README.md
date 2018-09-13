# Scripts for C6

This directory contains scripts helpful or necessary for working with Cloudera
Manager and CDH version 6.x.

## Hue, Python, and psycopg2

The Hue service included in CDH 6.x requires Python and the
[psycopg2](https://github.com/psycopg/psycopg2) PostgreSQL database adapter
library. The versions of Python and psycopg2 required under CDH 6.x are
sometimes newer than those that are automatically made available through either
standard operating system package repositories or through Cloudera Manager
mechanisms. If new enough versions are not available for Hue, then it will
fail to start, leading Cloudera Altus Director into a failure state for the
cluster.

The script [hue-c6.sh](hue-c6.sh) is an example of a bootstrap script that
performs the necessary work to ensure that compatible versions of Python and
psycopg2 are available for use by Hue. This script supports Red Hat Enterprise
Linux (RHEL) / CentOS 6.x and 7.x distributions, keying off a single `OS`
variable that you can modify or replace with OS detection logic.

It is expected that future versions of Cloudera Manager 6.x will better support
Hue, and some or all of the work done by hue-c6.sh will no longer be
necessary.

### Handling Python

Hue under CDH 6.x requires Python 2.7. The standard operating system package
repositories for RHEL / CentOS 7.x use Python 2.7 for the "python" package, so
the script simply installs it. For RHEL / CentOS 6.x, the script installs the
Python 2.7 distribution available from
[Software Collections](https://www.softwarecollections.org/). Hue is able to
support the SCL distribution of Python 2.7 without further work.

### Handling psycopg2

Hue requires the following versions of psycopg2, as of CDH 6.0:

<table>
    <tr><th>OS version</th><th>psycopg2 version</th></tr>
    <tr><td>RHEL / CentOS 6.x</td><td>2.6.2</td></tr>
    <tr><td>RHEL / CentOS 7.x</td><td>2.7.1</td></tr>
</table>

The script installs the necessary version of psycopg2 using
[pip](https://pypi.org/project/pip/). The SCL distribution of Python 2.7
includes pip, but the Python packages installed under RHEL / CentOS 7.x do
not; therefore, for the latter, the script installs pip through the
[EPEL](https://fedoraproject.org/wiki/EPEL) repository.

### Coping with the Cloudera Manager psycopg2 dependency

The Cloudera Manager 6.0 agent package includes version 2.5.1 of psycopg2 as a
package dependency. Due to the timing of package installation in Altus Director,
this dependency is installed after work performed by a bootstrap script like
hue-c6.sh. The older version of psycopg2 can then supplant the correct, newer
version, leading to Hue startup failure under CDH 6.x.

To combat this, the script constructs an ad hoc, empty RPM for psycopg2 version
2.5.1, installing it in a local repository. This package supersedes the package
in standard operating system package repositories and effectively cancels
installation of the older, incompatible version of psycopg2.

The Cloudera Manager agent itself does not require psycopg2 to be installed to
work. Therefore, measures taken by hue-c6.sh or a similar bootstrap script to
avoid installation of the psycopg2 dependency should not interfere with agent
functioning.

### How to use the bootstrap script

Include the bootstrap script in instance templates for instances that are to
host the `HUE_SERVER` role for the `HUE` service. An example of how this could
look in a configuration file:

```
instances {
    m5x {
        type: m4.xlarge
        image: ami-12345678
        bootstrapScriptsPaths: ["/script-path/hue-c6.sh"]
    }
}
```

Alternatively, you can copy the contents of the bootstrap script itself and use
the `bootstrapScripts` property instead.
