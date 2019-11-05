# How to Use a Custom Image with Cloudera Altus Director

Now that you have built a custom image, how do you use it to make Cloudera Altus Director's bootstrap process faster?

## The Gains

First, here is a summary of the speed gains that are possible through using a custom image. In general, a speed gain is possible because some work is performed on the custom image once, instead of requiring Director to perform the same work for every instance launched from the custom image.

### Internal Script Processing

Any custom configuration performed through your own internal scripts does not need to be done in Director bootstrap scripts. This can include operating system configuration, package installation, network configuration, or any other steps common to your needs.

### Resized Root Volume

The root partition of the device backing a custom image is resized to at least 95% of the available space on the device. Adjusting the size for the custom image allows Director to skip doing so itself during its instance normalization process.

### JCE Unlimited Policy File Installation

Policy files enabling unlimited strength cryptography through JCE are made available on the custom image so that they do not need to be found, copied, and extracted by Director.

### Basic Package Installation

Basic packages that Director or Cloudera Manager require, such as screen and python, are in place on the custom image so that they do not need to be found during bootstrap.

### Oracle JDK and Cloudera Manager Package Installation

A custom image already has an Oracle JDK installed, and already has all Cloudera Manager packages needed for either running Cloudera Manager or only its agent. Dependent packages are also included. Director will then detect that the packages are already present on instances launched from the custom image, so they are not downloaded from a package repository and installed again.

### Service Configuration

The custom image scripts enable and disable various operating system services to provide a smoother bootstrap process.

### CDH Parcel Installation and Pre-extraction

A CDH parcel is downloaded, linked correctly, and optionally unarchived into the proper location during custom image generation. This potentially allows Cloudera Manager to effectively skip its parcel download and distribution phases, saving time downloading the parcel from its repository, copying it to all cluster nodes, and extracting it on all cluster nodes.

Cloudera Manager 5.8 or higher is required to take advantage of parcel pre-extraction.

## Usage Details

When referencing your custom image you need to refer to the URL for the image. `build-images.sh` prints out your image URL and the command you can use to get that URL again. To get the URLs of all the images execute the following command - your image will be one of them:

```
gcloud compute images list  --uri
```

### Cloudera Manager

Normally, Director defines the package repository for Cloudera Manager, and the Oracle JDK, based on the Cloudera Manager repository URL and signing key provided in a deployment template, falling back on defaults if they are not specified. Then, Director instructs each instance to install those packages, which causes the package manager to take the time to download and install the packages.

A custom image already has the Oracle JDK and Cloudera Manager components installed. Therefore, Director will detect that the packages are present and not instruct the package manager to install them.

The packages already installed remain even if the deployment template specifies a different version of Cloudera Manager. While it is therefore not strictly necessary to override the default package repository for Cloudera Manager in the deployment template, it is nonetheless a good idea to make it clear which version is used.

### CDH Parcel

**Short version**: Specify a CDH parcel repository in the Director cluster template that exactly matches the version of the CDH parcel installed on the image.

Director looks for a CDH parcel with a version satisfying the one listed for it in a cluster template. For example, if a cluster template requests CDH version 5.8, Director will look for a parcel that is some version of 5.8, such as 5.8.0 or 5.8.2. If the template asks for CDH version 5, then Director may select any version starting with 5, such as 5.6 or 5.8.

Director looks for a CDH parcel in the CDH parcel repository specified in the cluster template, or falls back to a default repository. A CDH parcel repository URL includes a partial or complete CDH version number in its path, and the repository at the URL contains the latest version of CDH that matches that version number. For example:

* https://archive.cloudera.com/cdh5/parcels/5.7.0/ contains parcels for CDH version 5.7.0.
* https://archive.cloudera.com/cdh5/parcels/5.7/ contains parcels for the latest version of CDH 5.7, such as version 5.7.4.
* https://archive.cloudera.com/cdh5/parcels/5/ contains parcels for the latest version of CDH 5, such as version 5.9.0.

The choice of parcel repository influences the CDH versions that Director can satisfactorily match. A repository for CDH 5.7.0 can be used for matching versions 5.7.0, 5.7, and 5. A repository for CDH 5 can always match version 5; today it may also match CDH 5.9, but in the future may match 5.10 instead, when that new version is released.

Once Director locates a satisfactory parcel version, it requests that precise CDH version (x.y.z) for the cluster that it instructs Cloudera Manager to establish. Under normal circumstances, Cloudera Manager downloads the desired parcel, distributes it to the cluster nodes, and extracts it there.

A custom image already has a CDH parcel installed and possibly pre-extracted. Therefore, Cloudera Manager can avoid downloading the parcel by noticing its presence in the instances. Cloudera Manager 5.8 and higher are also able to skip the extraction step. The downloading and distribution of parcels become empty operations for Cloudera Manager, and this is the speed gain enabled by the custom image.

To ensure that Cloudera Manager detects the presence of the CDH parcel, it is essential that Director request the exact version of the CDH parcel that is present on the custom image. If, when Director runs, it locates a version of the parcel that is different from the one on the custom image, Cloudera Manager will download and distribute the version requested by Director, ignoring the parcel already present on the custom image.

Therefore, to ensure that Director finds the exact parcel version on the custom image, it is best to use the full version number in the URL for the CDH parcel repository in the cluster template. For example, if the custom image has the parcel for CDH 5.8.2 installed, specify the parcel repository for 5.8.2, and not 5.8 or 5, in the cluster template. This forces Director to locate the precise version.
