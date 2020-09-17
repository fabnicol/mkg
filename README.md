# Gentoo-light
## A light Gentoo distribution for GNU/Linux developers            

### Purpose

This software is a set of simple scripts to automate the installation of
Gentoo GNU/Linux. It follows the official AMD64 install handbook, with a
limited number of configuration options. It creates a platform
compiled out of the latest available sources in the stable branch,
with only a handful of packages belonging to the testing branch.

### Output

The output is an ISO installation file that can be used to burn a DVD
or create a bootable USB stick.   
**WARNING**: The install media will wipe out all data on the Desktop
main disk (/dev/sda). Use it with care and only if you want to do a fresh install of
your PC. No responsability for lost data will be accepted. You have
been warned.   

### Target

This software is targeted at users who love Gentoo but want to spare
some time installing their favourite platform.

## Prerequisits

This software is designed to work on *nix platforms. It has only been
tested under GNU/Linux (Ubuntu-20.04).

For the time being, supported configurations should include the
following features:

* 64-bit processor of the AMD64 (x86_64) category with at least the
  core-avx2 register (most Desktop processors released since 2015)      
* Intel or Nvidia-compatible video card   
* A prior VirtualBox install (preferably complete with extpack package
  and guest additions, other configurations have not been tested)   
* A complete install of CloneZilla with its own dependencies   
* Bash and squashfs   
* Tar available with xz-compression   
* A working, preferably wired, direct internet connection (firewalls
  unsupported)  
* At least 50 GB of spare disk space

### Licence

This software is licenced under the terms of the [GNU
GPLv3](https://www.gnu.org/licenses/gpl-3.0.html).


