[![Build Status](https://travis-ci.org/CSCfi/ansible-role-stress.svg?branch=master)](https://travis-ci.org/CSCfi/ansible-role-stress)
# ansible-role-stress

Run a stress test on a machine using Ansible. This role uses
[stress-ng](http://kernel.ubuntu.com/~cking/stress-ng/) to stress the CPU,
memory and disk on a system. It installs stress-ng and runs it with
configurable parameters. Since running a stress test is something that is
generally done for a long period continuously, screen is used to contain
stress-ng so that the Ansible run finishes in a timely manner and simply leaves
stress-ng running in the background.

Requirements
------------

  * Only tested on CentOS 7. Should also work on Ubuntu

Role variables
--------------

  * test_duration: sets the timeout limit for stress-ng in seconds
  * Variables to set the number of each type of worker:
    * cpu_workers
    * vm_workers
    * hdd_workers
  * Variables to set how much memory and disk space to consume per worker
    * bytes_per_hdd_worker
    * bytes_per_vm_worker

Notes
----
   * Up until version 2019-01-02 this role also supported CentOS 6. After that we no longer support that as we assume stress-ng is available in a yum repo configured on the server.
