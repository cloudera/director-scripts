# ETL Transient Jobs on AWS with Cloudera

These scripts can be used as an example end-to-end transient demo for a Hive query with Cloudera Hadoop (v5.8) running on AWS.  

## Instructions

- Configure AWS settings: http://www.cloudera.com/documentation/director/latest/topics/director_aws_setup_client.html
- Launch an EC2 Instance to install Director later (recommend using RHEL 7 or Centos 7): http://www.cloudera.com/documentation/director/latest/topics/director_deployment_start_launcher.html
- Copy your AWS SSH private key to the instance's  ~/.ssh/id_rsa (we will use this in the last step)
```sh
scp -i ~/.ssh/my_aws_key.pem ~/.ssh/my_aws_key.pem ec2-user@[public-ip-address]:/home/ec2-user/.ssh/id_rsa
```
- SSH into Director instance 
```sh
ssh -i ~/.ssh/my_aws_key.pem ec2-user@[public-ip-address]
```
- Clone the https://github.com/cloudera/director-scripts/ repository in the Director instance
```sh
sudo yum install git -y
git clone https://github.com/cloudera/director-scripts/
```

#### All following steps are to be executed in the Director instance
- Install Director and other packages: 
```sh
cd transient-aws
./install_director.sh
```

### Prepare AMIs
- Configure your environment with your AWS keys
```sh
	export AWS_ACCESS_KEY_ID=xxxx
	export AWS_SECRET_ACCESS_KEY=xxxxx
```
- Go to /director-scripts/preloaded-ami-builder/ (parent directory) 
- If your keys do not give you access to create new VPCs or Security Groups, open packer-json/rhel.json in a text editor and replace "vpc_id", "subnet_id", and "security_group_id" with existing ones you have access to.
- Run the AMI builder with the following command.  Replace all the items in brackets.
```sh
./build-ami.sh -p -P -a "{{ami-id}} {{virtualization_type}} {{ssh_username}} {{root_device_name}}" {{region}} {{base_OS}} {{CDH_PARCEL_REPO}} {{CLOUDERA_MANAGER_REPOSITORY}}
```
Here is an example build command that works in us-west-1
```sh
./build-ami.sh -p -P -a "ami-af4333cf hvm centos /dev/sda1" us-west-1 centos72 cdh58-ami http://archive.cloudera.com/cdh5/parcels/5.8/ http://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.8/
```
You can complete the next few sections (everything except the last step) in a new shell window while packer builds the AMI. 

### Update Cluster Configuration File
- Open hive-example/cluster_preloaded_amis.conf 
- Replace all REPLACE_ME's with the correct values for your AWS setup.
  Note:  make sure to use your newly created AMI ID for all the AMI IDs
- Replace the SSH_USERNAME in hive-example/dispatch.sh to match the AMI SSH username
- Replace the 'centos' username in hive-example/hive_job.sh to match the AMI SSH username
- If not using preloaded AMIs, use hive-example/cluster_bare_amis.conf instead and update hive/run_all.sh to point to cluster.conf.

### Prepare the Hive Query
- Open hive-example/query.sql and update the query or use the sample one.
- Note the sample query points to a public S3 read-only bucket.  However, the INSERT statement at the end will need write permissions to an S3 bucket you own.  Make sure to replace that last S3 location.

### Set S3 output log file
- If interested in copying job log files to s3, configure AWS with your credentials
```
aws configure
```
- Open hive-example/dispatch.sh and update the REPLACE_ME section with the S3 location to store the log files
- Otherwise remove that line

### Run transient job
```sh
cd hive-example/
./run_all.sh
```
