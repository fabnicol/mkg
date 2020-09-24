# Gentoo-light
## A light Gentoo distribution for GNU/Linux developers            

### Purpose

This software is a set of simple scripts to automate the installation of
Gentoo GNU/Linux. It follows the official AMD64 install handbook, with a
limited number of configuration options. It creates a KDE Plasma platform
compiled out of the latest available sources in the stable branch,
with only a handful of packages belonging to the testing branch.

### Output

The output is an ISO installation file that can be used to burn a DVD
or create a bootable USB stick using dd under *nix platforms of [Rufus](https://rufus.ie/)
on Windows.     
**WARNING**: The install media will wipe out all data on the Desktop
main disc (/dev/sda). It leaves no choice of the target disk and runs
**non-interactively** from beginning to end, once the user has entered
its *sudo* password and replied to a handful of automated questions in the first
two minutes of the session.   
Use it with care and only if you want to do a fresh install of your main PC disk.
You have been warned.   

### Target

This software is targeted at users who love Gentoo but want to spare
some time installing their favourite platform.

It is more specifically geared towars data science, with R installed along with 
a reasonably complete set of R libraries and the free version of the [RStudio](https://rstudio.com/) 
IDE.

Other software included are Libreoffice and Okular, a complete [TeX Live](https://www.tug.org/texlive/)
distribution for PDF-report creation,  and core libraries of the [Qt5 platform](https://www.qt.io).

And, well, emacs.

## Prerequisites

This software is designed to work on *nix platforms. It has only been
tested under GNU/Linux (Ubuntu-20.04).

For the time being, supported configurations should include the
following features:

* 64-bit processor of the AMD64 (x86_64).        
* Intel or Nvidia-compatible video card.
* Pre-installed software:
  - A prior VirtualBox install (preferably complete with extpack package
  and guest additions, other configurations have not been tested), version
  6.1 (or possibly later version, untested)  
  - A complete install of [CloneZilla](https://clonezilla.org/) with its own
    dependencies    
  - Bash and squashfs    
  - Tar available with xz-compression 
  - mkisofs (from [cdrtools](https://downloads.sourceforge.net/cdrtools/cdrtools-3.02a09.tar.bz2))  
  - wget  
  - mountpoint  
  - rsync.
* A working, preferably wired, direct internet connection (firewalls
  are not supported).  
* At least 50 GB of spare disk space if the custom-made `vbox-img` tool patched
  from VirtualBox sources work on your platform. Otherwise, 100 GB of spare
  disk space.
* A removable USB storage device (USB stick or external USB drive) with at least
  50 GB of reachable space. 

## Installation guidelines

* Clone or unpack  
* Check possible options and option defaults by calling: `mkgentoo.sh help` 
* To create a bootable ISO run:     
     `mkgentoo.sh  full/path/to/ISO/file`  
* To burn to DVD run:     
     `mkgentoo.sh  burn`   if there is only one DVD-writer to your platform.    
     Otherwise run:   
     `mkgentoo.sh  burn=x,y,z`   
     where `x,y,z` is the scsi bus identifier of the adequate DVD-writer
     to be used. Select this identifier as the output of a prior call
     to `cdrecord -scanbus`
     
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

* If your PC was made prior to 2015, its processor may not enable
  the AVX2 register, which is set as a global compiling option.
  In this case you should tweak the building process by adding:   
  `cflags="-core2 -O2"` to commandline, if your processor is at least
  CORE2-compatible, otherwise just cflags="-O2".      

* For COREI7 and higher-end processors, you may tweak the `cflags` option
  at your own risk. A good option is `cflags="-native -O2"`.    

## Warning
PROJECT CURRENTLY IN ITS FINAL STEPS. DO NOT USE FOR NOW.   
Building the platforms comes in with four dedicated cores as a default.   
If resources are strained, rerun with N cores by adding `ncpus=N`
to commandline.    
The `ncpus` number of jobs is used to implement the portage **make.conf**` CFLAGS`
parameter, so that the building process is in line with ressources granted to
the virtual machine. User should review this parameter later on according to
the characteristics of the target platform.    
  
## Limitations

Currently video card support is limited to Intel and Nvidia.
Internationalization is restricted to English and French.
Gnome is not supported, nor other Gentoo profiles.
Wifi is not completely configured.

## Licence

This software is licenced under the terms of the [GNU
GPLv3](https://www.gnu.org/licenses/gpl-3.0.html).

-------------------------------------------------------------------
**USAGE:**  
**mkgentoo**  [[switch=argument]...]  filename.iso  [1]  
**mkgentoo**  [[switch=argument]...]                [2]  
**mkgentoo**  help[=md]                             [3]  
  
Usage [1] creates a bootable ISO output file with a current Gentoo distribution.  
Usage [2] creates a VirtualBox VDI dynamic disk and a virtual machine with name Gentoo.  
Usage [3] prints this help, in markdown form if argument 'md' is specified.  
Warning: you should have at least 55 GB of free disk space in the current directory or in vmpath if specified.  
  
**Switches:**  
  
Boolean values are either 'true' or 'false'. For example, to build a minimal distribution, specify:  
>  minimal=true  
  
on command line.  
  
 | switch | description | default value |  
 |:-----:|:--------:|:-----:|  
| minimal 	| Remove *libreoffice* and *data science tools* from default list of installed software 	| [false] |  
| elist 	| 	 File containing a list of Gentoo ebuilds to add to the VM on top of stage3 	| [ebuilds.list] |  
| vm 	| 	 Virtual Machine name 	| [Gentoo] |  
| vbpath 	| Path to VirtualBox directory 	| [/usr/bin] |  
| vmpath 	| Path to VM base directory 	| [/home/fab/Dev/mkgentoo] |  
| mem 	| 	 VM RAM memory in MiB 	| [8000] |  
| ncpus 	| 	 Number of VM CPUs 	| [4] |  
| processor 	| Processor type 	| [amd64] |  
| size 	| 	 Dynamic disc size 	| [55000] |  
| livecd 	| Path to the live CD that will start the VM 	| [gentoo.iso] |  
| mirror 	| Mirror site for downloading of stage3 tarball 	| [http://gentoo.mirrors.ovh.net/gentoo-distfiles/] |  
| emirrors 	| Mirror sites for downloading ebuilds 	| [http://gentoo.mirrors.ovh.net/gentoo-distfiles/] |  
| rstudio 	| RStudio version to be downloaded and built from github source 	| [1.3.1073] |  
| r_version 	| R version 	| [4.0.2] |  
| githubpath 	| RStudio Github path to zip: path right before version.zip 	| [https://github.com/rstudio/rstudio/archive/v] |  
| cflags 	| GCC CFLAGS options for ebuilds 	| [-march=core-avx2 -O2] |  
| nonroot_user 	| Non-root user 	| [fab] |  
| passwd 	| User password 	| [dev20] |  
| rootpasswd 	| Root password 	| [dev20] |  
| download 	| Download install ISO image from Gentoo mirror 	| [true] |  
| download_stage3 	| Download and install stage3 tarball to virtual disk 	| [true] |  
| download_rstudio 	| Download and build RStudio 	| [true] |  
| download_clonezilla 	| Refresh CloneZilla ISO download 	| [false] |  
| donwload_clonezilla_path 	| Use the following CloneZilla ISO 	| [https://sourceforge.net/projects/clonezilla/files/clonezilla_live_alternative/20200703-focal/clonezilla-live-20200703-focal-amd64.iso/download] |  
| stage3 	| Path to stage3 archive 	| [stage3.tar.xz] |  
| create_squashfs 	| (Re)create the squashfs filesystem 	| [true] |  
| vmtype 	| gui or headless (silent) 	| [headless] |  
| kernel_config 	| Use a custom kernel config file 	| [.config] |  
| language 	| Set default login keyboard layout 	| [us] |  
| burn 	| Burn to optical disc. Argument is either a device label (e.g. cdrom, sr0) or a mountpoint directory. 	| [false] |  
| scsi_address 	| In case of several optical disc burners, specify the SCSI address as x,y,z 	| [0,0,0] |  
| usb_device 	| Create Gentoo OS on external device. Argument is either a device label (e.g. sdb1, hdb1), or a mountpoint directory. 	| [] |  
| usb_installer 	| Create Gentoo clone installer on external device. Argument is either a device label (e.g. sdb2, hdb2), or a mountpoint directory. If unspecified, usb_device value will be used. OS Gentoo will be replaced by Clonezilla installer. 	| [] |  
| disable_md5_check 	| Disable MD5 checkums verification after downloads 	| [true] |  
| cleanup 	| Cleanup archives, images and virtual machine after successful completion 	| [true] |  
| help 	| 	 This help 	| [] |  

