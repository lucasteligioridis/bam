bam
====
Because the AWS console is a clunky piece of crap, the aws cli has way too much documentation
and I'm lazy.

Prerequisites
-------------

1. Install [AWS Unified CLI](https://github.com/aws/aws-cli)
2. Your `~/.aws/credentials` are set appropriately.

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

    bam --ssh instance-name

    -------------------------------------------
    |                  SSH                    |
    +------+-----------------+----------------+
    | No.  | Servers         | IP Address     |
    +------+-----------------+----------------+
    | 1    | instance-name   | 172.10.10.100  |
    | 2    | instance-name   | 172.10.10.101  |
    +------+-----------------+----------------+

A list of instances that matched the search parameter will appear in a list, please
select the number row that matches the instance you would like to SSH to.

    Enter the No. of the instance you would like to SSH/SCP or type 0 or <CTRL+C> to quit: 1

**SCP**

As with SSH, you can SCP in the same fashion, a table of instances will appear after the below
command is run, please be sure to include your source file that you would like to SCP:

    bam --scp instance-name --scp /path/to/source/file.txt

You can also use this function to download files remotely by appending the -m flag.

    bam --scp instance-name --scp /path/to/target/file.txt --scp /local/dir/to/download/to -m

**INSTANCE INFO**

You can get important instance information information in whatever format you specify.
By default the format is in `json` if the --output flag is not specified. See below for examples:

    bam --instance-info "instance-name"

Will print the output in json format, as you can see you do not need the --output flag
as this is implicit if not supplied.

    bam --instance-info "instance-name" --output table

Will print the output in `table` format, you can also provide `text` format.

**S3 BUCKET**

We can easily retrieve a bucket size and count by interrogating the cloudwatch metrics.
Using the below command will provide an output of any S3 bucket you specify:

    bam --s3-size bucket-name --output table

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

For more detailed information, please use the below command:

    bam --help
