bam
====
Because the AWS console is a clunky piece of crap, the aws cli has way too much documentation
and I'm lazy.

Prerequisites
-------------

1. Install [AWS Unified CLI](https://github.com/aws/aws-cli)
2. Your `~/.aws/credentials` are set appropriately.
3. Your ssh keys are valid and in the correct directory `~/.ssh/`.

Installation
------------

**Ubuntu/Linux/Mac**

    git clone git@github.com:lucas044/bam
    cd bam
    make install

Usage
-----

**SSH**

You have the ability to SSH to the machines on AWS, by providing a search term by instance name
you can have a table of results that you can then SSH to:

    > bam --ssh instance-name

    -------------------------------------------
    |                  SSH                    |
    +------+-----------------+----------------+
    | No.  | Servers         | IP Address     |
    +------+-----------------+----------------+
    | 1    | instance-name   | 172.10.10.100  |
    | 2    | instance-name   | 172.10.10.101  |
    +------+-----------------+----------------+

    Enter the No. of the instance you would like to SSH or type 0 or <CTRL+C> to quit: 1

    Connecting to...
    Host: instance-name
    IP: 172.10.10.100

    Warning: Permanently added '172.10.10.100' (ECDSA) to the list of known hosts.
    Welcome to Ubuntu 16.04 LTS (GNU/Linux 4.4.0-24-generic x86_64)

     * Documentation:  https://help.ubuntu.com/

      Get cloud support with Ubuntu Advantage Cloud Guest:
        http://www.ubuntu.com/business/services/cloud

    113 packages can be updated.
    0 updates are security updates.


    *** System restart required ***
    Last login: Fri Feb 17 08:48:35 2017 from 172.1.1.1
    lucas044@instance-name:~$

A list of instances that matched the search parameter will appear in a list, please
select the number row that matches the instance you would like to SSH to.

**SCP**

As with SSH, you can SCP in the same fashion, a table of instances will appear after the below
command is run, please be sure to include your source file that you would like to SCP:

    > bam --scp instance-name --scp local_file.txt
    + scp local_file.txt lucas044@172.10.10.100:/home/lucas044

    > bam --scp instance-name --scp file.txt --scp /tmp/dir
    + scp local_file.txt lucas044@172.10.10.100:/tmp/dir

You can also use this function to download files remotely by appending the -m flag.

    > bam --scp instance-name --scp remote_file.txt -m
    + scp lucas044@172.10.10.100:remote_file.txt .

**INSTANCE INFO**

You can get important instance information information in whatever format you specify.
By default the format is in `table` if the --output flag is not specified and by default
will only search for currently running instances. See below for examples:

    > bam --instance-info "instance-name"

    ---------------------------------------------------------------------------------------------------------------
    |                                             DescribeInstances                                               |
    +-----------------+----------------------+---------------+-----------------+----------------+-----------------+
    |       AZ        |      InstanceId      | InstanceType  |      Name       |   PrivateIP    |    PublicIp     |
    +-----------------+----------------------+---------------+-----------------+----------------+-----------------+
    |  ap-southeast-2a|  i-083216b304e95c4b1 |  r3.xlarge    |  instance-name  |  172.10.10.100 |   200.0.0.201   |
    |  ap-southeast-2a|  i-083216b304e95c4b1 |  r3.xlarge    |  instance-name  |  172.10.10.101 |   200.0.0.202   |
    +-----------------+----------------------+---------------+-----------------+----------------+-----------------+

If you would like to find instances that are shutdown please append the -l flag.

The below command will print the output in `json` format, you can also provide `text` format.

    > bam --instance-info "instance-name" --output json

    [
        [
            {
                "Name": "instance-name",
                "InstanceId": "i-083216b304e95c4b1",
                "PrivateIP": "172.10.10.100",
                "PublicIp": "200.0.0.200",
                "AZ": "ap-southeast-2a",
                "InstanceType": "r3.xlarge"
            }
        ]
    ]

**S3 BUCKET**

We can easily retrieve a bucket size and count by interrogating the cloudwatch metrics.
Using the below command will provide an output of any S3 bucket you specify:

    > bam --s3-size bucket-name

    -----------------------------------------------------
    |                GetMetricStatistics                |
    +---------------+-----------------------------------+
    |  Label        |  BucketSizeBytes                  |
    +---------------+-----------------------------------+
    ||                   Datapoints                    ||
    |+---------------+------------------------+--------+|
    ||      Sum      |       Timestamp        | Unit   ||
    |+---------------+------------------------+--------+|
    ||  6228552066.0 |  2017-02-15T14:50:00Z  |  Bytes ||
    |+---------------+------------------------+--------+|

**ASG INFO**

AutoScalingGroup information can be retireved in the similar fashion as the instance
info function

    > bam --asg-info my-auto-scaling-group

    -----------------------------------------------------------------------------------------------
    |                                  DescribeAutoScalingGroups                                  |
    +--------------------------+------------------------------------------------------------------+
    |  AutoScalingGroupName    |  my-auto-scaling-group                                           |
    |  DesiredCapacity         |  2                                                               |
    |  LaunchConfigurationName |  launch-configuration                                            |
    |  MaxSize                 |  16                                                              |
    |  MinSize                 |  2                                                               |
    +--------------------------+------------------------------------------------------------------+
    ||                                         Instances                                         ||
    |+---------------------+-------------------+---------------------------+---------------------+|
    ||         AZ          |   HealthStatus    |            ID             |   LifeCycleState    ||
    |+---------------------+-------------------+---------------------------+---------------------+|
    ||  ap-southeast-2a    |  Healthy          |  i-007b0d6775d4ba86e      |  InService          ||
    ||  ap-southeast-2b    |  Healthy          |  i-05e60270bef39dce1      |  InService          ||
    |+---------------------+-------------------+---------------------------+---------------------+|

**ASG COUNT**

There is an ability to quickly retrieve the count of instances within an autoscaling group.
This can be achieved by running the below command:

    > bam --asg-count my-auto-scaling-group

    2

**HELP**

For more detailed information on each option, please use the following command:

    > bam --help
