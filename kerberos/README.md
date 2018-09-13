# Enabling Kerberos

_NOTE: Cloudera Altus Director 2.0 and higher can enable Kerberos in clusters without the use
of scripts. The resources here apply only to Altus Director 1.5._

The `kerberize-cluster.py` script configures a cluster to use Kerberos for authentication. An
existing KDC must be supplied; this is demonstrated in [aws.reference.conf](../configs/aws.reference.conf).

The script depends on the argparse, cm-api, and retrying libraries, which can be installed by
[cm-script-dependency-installer.sh](../cm-script-dependency-installer/cm-script-dependency-installer.sh).

