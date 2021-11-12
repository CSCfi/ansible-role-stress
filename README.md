[![Build Status](https://travis-ci.org/CSCfi/ansible-role-stress.svg?branch=master)](https://travis-ci.org/CSCfi/ansible-role-stress)
# ansible-role-stress

Run a stress test on a machine using Ansible. This role uses
[stress-ng](http://kernel.ubuntu.com/~cking/stress-ng/) to stress the CPU,
memory and HDD disk(s), and [FIO](https://fio.readthedocs.io/en/latest/fio_doc.html)
to stress SSD(s) on a system. It installs stress-ng and fio and runs it wrapped on a
script with configurable parameters. Since running a stress test is something that is
generally done for a long period continuously, screen is used to contain
the script so that the Ansible run finishes in a timely manner and simply leaves
the stress test running in the background.

Requirements
------------

  * Only tested on CentOS 7. Should also work on Ubuntu

Role variables
--------------

  * stress_ng_duration: sets the timeout limit for stress-ng in seconds
  * Variables to set the number of each type of worker:
    * cpu_workers
    * vm_workers
    * hdd_workers
  * Variables to set how much memory and disk space to consume per worker:
    * bytes_per_hdd_worker
    * bytes_per_vm_worker
  * Variables to set how the SSD test (FIO) is done:
    * ssd_test: Test SSD disks using FIO (if there are SSD disks)
    * fio_test_duration: sets the timeout limit for fio test in seconds
    * ssd_block_size: Size of each block for FIO's SSD test
    * ssd_workers: Number of workers for FIO's SSD test
    * ssd_tests_folder: Folder to mount a new Logical Volume in the Volume Group vg_instances and where FIO would store the files for the test
    * ssd_volume_group: Volume Group name to test the SSDs. Check that this is contained in the SSDs

Notes
----
   * Up until version 2019-01-02 this role also supported CentOS 6. After that we no longer support that as we assume stress-ng is available in a yum repo configured on the server.
