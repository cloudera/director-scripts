# Scripts for TLS Management

Scripts in this directory help with working with TLS under Cloudera Director.

## Manually Enabling or Disabling TLS Communications with Cloudera Manager

When using the [manual TLS](https://www.cloudera.com/documentation/director/latest/topics/director_tls_enable.html#concept_rts_nbv_gbb) path for configuring Cloudera Manager for TLS, it is necessary to update the corresponding deployment information in Cloudera Director to enable TLS communication. The [documented process](https://www.cloudera.com/documentation/director/latest/topics/director_tls_enable.html#concept_z4v_ybv_gbb) involves retrieving deployment template data from Cloudera Director's API as JSON, editing the JSON, and submitting the modified template back to Cloudera Director.

The script [update_tls.py](update_tls.py) performs the updating work automatically, by taking advantage of the [Cloudera Director Python SDK](https://github.com/cloudera/director-sdk/tree/master/python-client). The Python SDK must be installed for the script to work.

Pass the `-h` option to the script to see help information. Common uses for the script are described below.

### Enabling TLS

Use the script after Level 0 TLS configuration has been completed for Cloudera Manager. You must know the new port that the Cloudera Manager server listens on (usually 7183). You also should have the trusted certificate for Cloudera Manager as a local file. As described in Cloudera Director documentation, the trusted certificate may be the server certificate for Cloudera Manager itself, or the certificate for any certificate authority (CA) in the chain of signing CAs for the server certificate.

*Note: If Cloudera Director's Java runtime is already configured to trust the required server certificate or CA, then the trusted certificate does not need to be passed to the script.*

Run `update_tls.py` with the name of the environment where Cloudera Manager resides, the name of the deployment corresponding to the Cloudera Manager instance, and the new port number. Pass the path to the trusted certificate file using the `--trusted-cert-file` option. If Cloudera Director is not running local to the script, then pass its URL with the `--server` option.

```
$ python2 update-tls.py --trusted-cert-file server.crt --server http://director-host:7189 env dep 7183
Enabling TLS communications for deployment dep ...
TLS communications for deployment dep is enabled.
```

After successful deployment update, Cloudera Director will communicate with Cloudera Manager exclusively over TLS. Be sure to return to the documented process of configuring TLS for other components of Cloudera Manager, such as its agents, to complete the work of securing Cloudera Manager and CDH clusters.

### Disabling TLS

If it becomes necessary to disable TLS for Cloudera Manager, it is possible to update Cloudera Director so that it communicates over unencrypted HTTP to Cloudera Manager. Run `update_tls.py` once again, this time passing the `--disable` option. Do not include the trusted certificate file, but do specify the new port that the Cloudera Manager server listens on (usually 7180).

```
$ python2 update-tls.py --disable --server http://director-host:7189 env dep 7180
Disabling TLS communications for deployment dep ...
TLS communications for deployment dep is disabled.
```

After successful deployment update, Cloudera Director will communicate with Cloudera Manager without TLS. If or when TLS is enabled once again for Cloudera Manager, run the script again to re-enable TLS communication.

### Troubleshooting Use of the Script

* The script must be able to log in to a Cloudera Director server. Be sure to supply the correct server URL and, if necessary, administrative username and password.
* The script accepts two certificate files: one for Cloudera Director itself (`--cafile`), and one for Cloudera Manager when enabling TLS (`--trusted-cert-file`). They are almost always different. Use `--cafile` to refer to the trusted certificate for the Cloudera Director server, and `--trusted-cert-file` to refer to the trusted certificate for the Cloudera Manager server. The trusted certificate for the Cloudera Director server is only necessary when Cloudera Director itself is configured for TLS.
* The script fails with an error if you try to enable TLS for a deployment where it is already enabled, or disable TLS for a deployment where it is already disabled.
* As usual, Cloudera Director attempts to communicate with Cloudera Manager to validate any update. So, run the script to enable TLS communication _after_ Cloudera Manager is configured for TLS, and to disable TLS communication _after_ Cloudera Manager is configured for unencrypted communication.
* The trusted certificate file should be in the standard PEM format, comprised of multiple lines starting with one containing "BEGIN CERTIFICATE". It is not necessary to manually reformat the file contents as a single string, as described in Cloudera Director documentation for using the Cloudera Director API directly. The script handles that for you.
