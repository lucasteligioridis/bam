Archived
====
This repository is now officially archived. It hasn't been used in quite some time, originally
this was meant to make my life easier when SSH'ing to various instances on AWS, since then there
are plenty of better alternatives, also probably wouldn't use bash either :P

This was good fun at the time, but time to put it to rest.

bam
====
Primarily an SSH tool to gather a list of instances across all your selected regions.

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

General
-------

All searches with instance names can be completed with wildcards, see below for examples:

    > bam --ssh "*instance-name*"

    > bam --scp-upload "instan*name" local_file.txt

Depending on where you place the wildcard and what system you are running, you may
have to use quotes, I would recommend this approach regardless.

When first installing via `make install` you will be prompted to enter your default regions. These must be set for the tool to work without any extra arguments, otherwise please use the `--region` flag. This will overwrite your default configuration.

SSH
---

You have the ability to SSH to any instance on AWS. By providing a search on instance name
you can have a table of results that will output to the terminal which will then give
you the option to ssh to. See below for an example:

    > bam --ssh instance-name

    -------------------------------------------
    |                  SSH                    |
    +------+-----------------+----------------+
    | No.  | Servers         | IP Address     |
    +------+-----------------+----------------+
    | 1    | instance-name   | 172.10.10.100  |
    | 2    | instance-name   | 172.10.10.101  |
    +------+-----------------+----------------+

    Enter one of the following valid options:
    o No. - To SSH on a single instance
    o all - To send SSH command on all listed instances
    o 0 or 'quit' - To quit

    Enter one of the valid options: 1
    Are you sure you want to SSH <yes/no>? yes


    +------------------------------+
    | Connecting to 172.10.10.100  |
    +------------------------------+

    + ssh lucas044@172.10.10.100 ''
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

You can also send commands remotely in the same fashion as well as sending it to
the entire list of machines, see below for an example:

    > bam --ssh instance-name --ssh-command "date"

    -------------------------------------------
    |                  SSH                    |
    +------+-----------------+----------------+
    | No.  | Servers         | IP Address     |
    +------+-----------------+----------------+
    | 1    | instance-name   | 172.10.10.100  |
    | 2    | instance-name   | 172.10.10.101  |
    +------+-----------------+----------------+

    Enter one of the following valid options:
    o No. - To SSH to a single instance
    o all - To send SSH command on all listed instances
    o 0 or 'quit' - To quit

    Enter one of the valid options: all
    Are you sure you want to SSH <yes/no>? yes


    +------------------------------+
    | Connecting to 172.10.10.100  |
    +------------------------------+

    + ssh lucas044@172.10.10.100 date
    Warning: Permanently added '172.10.10.100' (ECDSA) to the list of known hosts.
    Mon Feb 20 05:22:54 UTC 2017

    +------------------------------+
    | Connecting to 172.10.10.101  |
    +------------------------------+

    + ssh lucas044@172.10.10.101 date
    Warning: Permanently added '172.10.10.101' (ECDSA) to the list of known hosts.
    Mon Feb 20 05:10:36 UTC 2017

The `all` command will not work unless the `--ssh-command` option has been specified
with a parameter.

If any special ssh parametes need to be parsed in, this can be achieved with the
`--ssh-params` option, please note that you must wrap the argument in quotes. See
below for an example:

    > bam --ssh instance-name --ssh-command "date" --ssh-params "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

    +------------------------------+
    | Connecting to 172.10.10.100  |
    +------------------------------+

    + ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null lucas044@172.10.10.100 date
    Warning: Permanently added '172.10.10.100' (ECDSA) to the list of known hosts.
    Mon Feb 20 21:10:35 UTC 2017

SCP
---

As with SSH, you can SCP in the same fashion, a table of instances will appear after the below
command is run, please be sure to include your source file that you would like to SCP:

    > bam --scp-upload instance-name local_file.txt
    + scp local_file.txt lucas044@172.10.10.100:/home/lucas044

You can also add the `--scp-dir` option to the command optionally to specify a custom directory, see
below for an example:

    > bam --scp-upload instance-name file.txt --scp-dir /tmp/dir
    + scp local_file.txt lucas044@172.10.10.100:/tmp/dir

You can also use the `--scp-download` command, to get a file from a remote server to your local
machine. See below for example:

    > bam --scp-download instance-name remote_file.txt
    + scp lucas044@172.10.10.100:remote_file.txt .

As well as SSH mode, you can upload/download to multiple servers at once. See below for an
example:

    > bam --scp-upload instance-name local_file.txt

    -------------------------------------------
    |                  SCP                    |
    +------+-----------------+----------------+
    | No.  | Servers         | IP Address     |
    +------+-----------------+----------------+
    | 1    | instance-name   | 172.10.10.100  |
    | 2    | instance-name   | 172.10.10.101  |
    +------+-----------------+----------------+

    Enter one of the following valid options:
    o No. - To SCP files to a single instance
    o all - To SCP files to all listed instances
    o 0 or 'quit' - To quit

    Enter one of the valid options: all
    Are you sure you want to SCP <yes/no>? yes


    +------------------------------+
    | Connecting to 172.10.10.100  |
    +------------------------------+

    + scp local_file.txt lucas044@172.10.10.100:
    Warning: Permanently added '172.10.10.100' (ECDSA) to the list of known hosts.
    local_file.txt                                           100%    0     0.0KB/s   00:00

    +------------------------------+
    | Connecting to 172.10.10.101  |
    +------------------------------+

    + scp local_file.txt lucas044@172.10.10.101:
    Warning: Permanently added '172.10.10.101' (ECDSA) to the list of known hosts.
    local_file.txt                                           100%    0     0.0KB/s   00:00

You can run the above command with the `--scp-download` to download files from remote servers
locally.

Instance Info
-------------

You can get important instance information in whatever format you specify.
By default the format is in `table`, you can change the format by using the  `--output`
option. See below for examples:

    > bam --instance-info "instance-name"

    ---------------------------------------------------------------------------------------------------------------
    |                                             DescribeInstances                                               |
    +-----------------+----------------------+---------------+-----------------+----------------+-----------------+
    |       AZ        |      InstanceId      | InstanceType  |      Name       |   PrivateIP    |    PublicIp     |
    +-----------------+----------------------+---------------+-----------------+----------------+-----------------+
    |  ap-southeast-2a|  i-083216b304e95c4b1 |  t2.xlarge    |  instance-name  |  172.10.10.100 |   200.0.0.201   |
    |  ap-southeast-2a|  i-083216b304e95c4b1 |  r3.xlarge    |  instance-name  |  172.10.10.101 |   200.0.0.202   |
    +-----------------+----------------------+---------------+-----------------+----------------+-----------------+

If you would like to find instances with a different state please append the `--instance-state <state>` with the state
you are searching for.

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

If you would like to narrow down your search further, you can use the `--instance-type` option
and specify the particular instance type, see below for example:

    > bam --instance-info "instance-name" --instance-type "t2.xlarge"

    ---------------------------------------------------------------------------------------------------------------
    |                                             DescribeInstances                                               |
    +-----------------+----------------------+---------------+-----------------+----------------+-----------------+
    |       AZ        |      InstanceId      | InstanceType  |      Name       |   PrivateIP    |    PublicIp     |
    +-----------------+----------------------+---------------+-----------------+----------------+-----------------+
    |  ap-southeast-2a|  i-083216b304e95c4b1 |  t2.xlarge    |  instance-name  |  172.10.10.100 |   200.0.0.201   |
    +-----------------+----------------------+---------------+-----------------+----------------+-----------------+

Todo
----

- Add in a parallel option, so commands can be run across multiple instances at once.
- Netcat test prior to ssh/scp and error out

Help
----

For more detailed information on each option, please use the following command:

    > bam --help
