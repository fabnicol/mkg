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
main disk (/dev/sda). Use it with care and only if you want to do a
fresh install of your PC. No responsability for lost data will be
accepted.   
You have been warned.   

### Target

This software is targeted at users who love Gentoo but want to spare
some time installing their favourite platform.

It is more specifically geared towars data science, with R installed along with 
a reasonably complete set of R libraries and the free version of the [RStudio](https://rstudio.com/) 
IDE.

Other software included are Libreoffice and Okular and core libraries of
the [Qt5 platform](https://www.qt.io). 

## Prerequisites

This software is designed to work on *nix platforms. It has only been
tested under GNU/Linux (Ubuntu-20.04).

For the time being, supported configurations should include the
following features:

* 64-bit processor of the AMD64 (x86_64) category with at least the
  core-avx2 register (most Desktop processors released since 2015)      
* Intel or Nvidia-compatible video card
* Pre-installed software:
  - A prior VirtualBox install (preferably complete with extpack package
  and guest additions, other configurations have not been tested), version
  6.1 (or possibly later version, untested)  
  - A complete install of [CloneZilla](https://clonezilla.org/) with its own dependencies    
  - Bash and squashfs    
  - Tar available with xz-compression 
  - mkisofs (from [cdrtools](https://downloads.sourceforge.net/cdrtools/cdrtools-3.02a09.tar.bz2))  
  - wget  
  - mountpoint  
  - rsync
* A working, preferably wired, direct internet connection (firewalls
  are not supported)  
* At least 50 GB of spare disk space

## Installation guidelines

* Clone or unpack  
* Check possible options and option defaults by calling: `mkgentoo.sh help` 
* To create a bootable ISO run:     
     `mkgentoo.sh  full/path/to/ISO/file`  
* To burn to DVD run:     
     `mkgentoo.sh  burn`   if there is only one DVD-writer to your platform  
     `mkgentoo.sh  burn=x,y,z` where x,y,z 3is the scsi bus identifier of the
     adequate DVD-writer to be used. Select this identifier as the output of
     a prior call to `cdrecord -scanbus`
     
* To create a bootable ISO run:     
     `mkgentoo.sh  full/path/to/ISO/file`  

## Options   
  
* The project comes in with a default kernel configuration file (.config)
  adapted from the Ubuntu 20.04 platform. This configuration may be averall
  too overloaded with unnecessary built-in drivers but will come in handy to
  many users. Should you wish a lighter, possibly more reactive kernel, please
  add your configuration file with option:
      `kernel_config=/path/to/cutom/config/file`

* The default user is **fab** with password **dev20** (same as root). You can
  specify other choices by adding `nonroot_user=name_of_user` and
  `passwd=password_of_user` to commandline.


## Warning
PROJECT CURRENTLY IN ITS FINAL STEPS. DO NOT USE FOR NOW.   
Building the platforms comes in with four dedicated cores as a default.
If resources are strained, rerun with N cores by adding `ncpus=N` to commandline.

## Licence

This software is licenced under the terms of the [GNU
GPLv3](https://www.gnu.org/licenses/gpl-3.0.html).


