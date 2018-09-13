# Scripts for TLS Management

Scripts in this directory help with working with TLS under Cloudera Altus Director.

## Configuring TLS Level 0 for Cloudera Manager

The [manual TLS](https://www.cloudera.com/documentation/director/latest/topics/director_tls_enable.html#concept_rts_nbv_gbb) path for configuring Cloudera Manager for TLS leaves it up to you to create and install keys and certificates for the Cloudera Manager installation and for Cloudera Manager agents. The manual process begins with ["Level 0" for Cloudera Manager](https://www.cloudera.com/documentation/enterprise/latest/topics/cm_sg_tls_browser.html#xd_583c10bfdbd326ba-7dae4aa6-147c30d0933--7a61), which establishes a server certificate and enables TLS for the Cloudera Manager server, including its administrative web console.

The script [configure_cm_tls_level_0.sh](configure_cm_tls_level_0.sh) performs Level 0 work automatically, with some variations to get started more quickly. At any time after Cloudera Altus Director has completed bootstrapping the Cloudera Manager instance and installing Cloudera Manager, copy the script to the instance and run it under an account with passwordless sudo access.

Pass the `-h` option to the script to see help information. Typical use should provide the base DN for the server certificate's subject DN and, for following along, the verbose flag.

```
$ ./configure_cm_tls_level_0.sh -v -b "OU=My Unit,O=My Organization,L=My City,ST=CA,C=US"
Configuring TLS level 0 ...
✔ Created keystore /opt/cloudera/security/pki/ip-203-0-113-101.ec2.internal-server.jks
Go to http://203.0.113.101:7180/cmf/settings#filterdisplayGroup=Security:
  check "Use TLS Encryption for Admin Console"
  set "Cloudera Manager TLS/SSL Server JKS Keystore File Location" to:
    /opt/cloudera/security/pki/ip-203-0-113-101.ec2.internal-server.jks
  set "Cloudera Manager TLS/SSL Server JKS Keystore File Password" to:
    cloudera
and then Save Changes

Certificate stored in file </opt/cloudera/security/pki/ip-203-0-113-101.ec2.internal-server.crt>
✔ Exported server certificate to /opt/cloudera/security/pki/ip-203-0-113-101.ec2.internal-server.crt
Certificate was added to keystore
✔ Imported server certificate to /usr/java/jdk1.7.0_67-cloudera/jre/lib/security/jssecacerts
Go to http://203.0.113.101:7180/cmf/services/1/config#filtercategory=MGMT+(Service-Wide)&filterdisplayGroup=Security:
  set "TLS/SSL Client Truststore File Location" to:
    /usr/java/jdk1.7.0_67-cloudera/jre/lib/security/jssecacerts
  set "Cloudera Manager Server TLS/SSL Certificate Trust Store Password" to:
    changeit
and then Save Changes

After changing CM configs:
  run: sudo service cloudera-scm-server restart
  go to https://203.0.113.101:7183/cmf/services/1/status and
    accept the self-signed server certificate
    restart the management services

Certificate contents for updating Cloudera Altus Director:

-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
```

### Variations from Level 0

The script does some things differently from the Cloudera Manager documentation.

* The original, self-signed server certificate is installed, instead of using one that is signed by a known certificate authority. After the script runs, a properly signed certificate may be swapped in.
* The private IP address of the Cloudera Manager instance is included as a subject alternative name (SAN) on the server certificate, for compatibility with Cloudera Altus Director.

### Java Home

The script uses a default location for Java that is usually established when Cloudera Altus Director installs Cloudera Manager 5.x. To use a different Java installation, set the `JAVA_HOME` environment variable before running.

The location of Java is necessary in order to use `keytool` and to find a truststore to copy and add the new server certificate to. It is recommended that the Java installation used be the same one used to run Cloudera Manager.

### Output

When run in verbose mode, the script provides instructions on how to configure Cloudera Manager the rest of the way for Level 0. The instructions are customized based on the environment, such as the private IP address for the Cloudera Manager instance and the chosen Java installation. Perform the steps in the instructions after the script completes.

The contents of the (public) server certificate are also reported. Use this data as the "trusted certificate" when manually updating Cloudera Altus Director to enable TLS communication with Cloudera Manager.

## Manually Enabling or Disabling TLS Communications with Cloudera Manager

When using the [manual TLS](https://www.cloudera.com/documentation/director/latest/topics/director_tls_enable.html#concept_rts_nbv_gbb) path for configuring Cloudera Manager for TLS, it is necessary to update the corresponding deployment information in Cloudera Altus Director to enable TLS communication. The [documented process](https://www.cloudera.com/documentation/director/latest/topics/director_tls_enable.html#concept_z4v_ybv_gbb) involves retrieving deployment template data from Cloudera Altus Director's API as JSON, editing the JSON, and submitting the modified template back to Cloudera Altus Director.

The script [update_tls.py](update_tls.py) performs the updating work automatically, by taking advantage of the [Cloudera Altus Director Python SDK](https://github.com/cloudera/director-sdk/tree/master/python-client). The Python SDK must be installed for the script to work.

Pass the `-h` option to the script to see help information. Common uses for the script are described below.

### Enabling TLS

Use the script after Level 0 TLS configuration has been completed for Cloudera Manager. You must know the new port that the Cloudera Manager server listens on (usually 7183). You also should have the trusted certificate for Cloudera Manager as a local file. As described in Cloudera Altus Director documentation, the trusted certificate may be the server certificate for Cloudera Manager itself, or the certificate for any certificate authority (CA) in the chain of signing CAs for the server certificate.

*Note: If Cloudera Altus Director's Java runtime is already configured to trust the required server certificate or CA, then the trusted certificate does not need to be passed to the script.*

Run `update_tls.py` with the name of the environment where Cloudera Manager resides, the name of the deployment corresponding to the Cloudera Manager instance, and the new port number. Pass the path to the trusted certificate file using the `--trusted-cert-file` option. If Cloudera Altus Director is not running local to the script, then pass its URL with the `--server` option.

```
$ python2 update-tls.py --trusted-cert-file server.crt --server http://director-host:7189 env dep 7183
Enabling TLS communications for deployment dep ...
TLS communications for deployment dep is enabled.
```

After successful deployment update, Cloudera Altus Director will communicate with Cloudera Manager exclusively over TLS. Be sure to return to the documented process of configuring TLS for other components of Cloudera Manager, such as its agents, to complete the work of securing Cloudera Manager and CDH clusters.

### Disabling TLS

If it becomes necessary to disable TLS for Cloudera Manager, it is possible to update Cloudera Altus Director so that it communicates over unencrypted HTTP to Cloudera Manager. Run `update_tls.py` once again, this time passing the `--disable` option. Do not include the trusted certificate file, but do specify the new port that the Cloudera Manager server listens on (usually 7180).

```
$ python2 update-tls.py --disable --server http://director-host:7189 env dep 7180
Disabling TLS communications for deployment dep ...
TLS communications for deployment dep is disabled.
```

After successful deployment update, Cloudera Altus Director will communicate with Cloudera Manager without TLS. If or when TLS is enabled once again for Cloudera Manager, run the script again to re-enable TLS communication.

### Troubleshooting Use of the Script

* The script must be able to log in to a Cloudera Altus Director server. Be sure to supply the correct server URL and, if necessary, administrative username and password.
* The script accepts two certificate files: one for Cloudera Altus Director itself (`--cafile`), and one for Cloudera Manager when enabling TLS (`--trusted-cert-file`). They are almost always different. Use `--cafile` to refer to the trusted certificate for the Cloudera Altus Director server, and `--trusted-cert-file` to refer to the trusted certificate for the Cloudera Manager server. The trusted certificate for the Cloudera Altus Director server is only necessary when Cloudera Altus Director itself is configured for TLS.
* The script fails with an error if you try to enable TLS for a deployment where it is already enabled, or disable TLS for a deployment where it is already disabled.
* As usual, Cloudera Altus Director attempts to communicate with Cloudera Manager to validate any update. So, run the script to enable TLS communication _after_ Cloudera Manager is configured for TLS, and to disable TLS communication _after_ Cloudera Manager is configured for unencrypted communication.
* The trusted certificate file should be in the standard PEM format, comprised of multiple lines starting with one containing "BEGIN CERTIFICATE". It is not necessary to manually reformat the file contents as a single string, as described in Cloudera Altus Director documentation for using the Cloudera Altus Director API directly. The script handles that for you.
