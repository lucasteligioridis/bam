am
==

Gather a list of EC2 instances - run commands on them!

Prerequisites
-------------

0. Uninstall previous versions of this application especially if they're called bam
1. Install [AWS CLI](https://github.com/aws/aws-cli)
2. Run aws configure
3. Setup ssh

Installation
------------

    git clone git@github.com:alexlance/am
    cp am/am /usr/bin/

Usage
-----

    # print a list of servers matching this name
    am server-name

    # run a command on a bunch of servers that match this name eg
    am webservers ps -ef

    # remember to escape pipes and ampersands etc if you want them to run remotely
    am webservers ps -ef \| grep apache

    # run privileged commands too using sudo - only type sudo password once, even though multiple hosts!
    am workers sudo docker ps

    # run a shell
    am some-host bash

    # do random stuff to each server
    for i in $(am cluster | awk '{ print $3 }'); do ping -c1 $i; done
