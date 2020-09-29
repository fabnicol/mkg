# Gentoo-light
## A light Gentoo distribution for GNU/Linux developers            

### Purpose

This software is a set of simple scripts to automate the installation of
Gentoo GNU/Linux. It follows [the official AMD64 install handbook](https://wiki.gentoo.org/wiki/Handbook:AMD64/fr), with a
limited number of configuration options. It creates a KDE Plasma platform
compiled out of the latest available sources in the stable branch,
with only a handful of packages belonging to the testing branch.

### Output

The output is an ISO installation file that can be used to burn a DVD
or create a bootable USB stick using dd under *nix platforms of [Rufus](https://rufus.ie/)
on Windows.     
**WARNING**: The install media will wipe out all data on the Desktop
main disc (/dev/sda). It leaves no choice of the target disk and runs
**non-interactively** from beginning to end.   
Use it with care and only if you want to do a fresh install of your main PC disk.
You have been warned.   

### Target

This software is targeted at users who love Gentoo but want to spare
some time installing their favourite platform.

It is more specifically geared towars data science, with R installed along with 
a reasonably complete set of R libraries and the free version of the [RStudio](https://rstudio.com/) 
IDE.

Other software included are [Libreoffice](https://www.libreoffice.org/download/download/) and [Okular](https://okular.kde.org/), a complete [TeX Live](https://www.tug.org/texlive/)
distribution for PDF-report creation, and core libraries of the [Qt5 platform](https://www.qt.io).

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
  6.1 (or later)  
  - A complete install of [CloneZilla](https://clonezilla.org/) with its own
    dependencies. Debian packages can be used.  
  - Bash and squashfs  
  - Tar available with xz-compression 
  - mkisofs (from [cdrtools](https://downloads.sourceforge.net/cdrtools/cdrtools-3.02a09.tar.bz2))  
  - wget  
  - mountpoint  
  - rsync.  
* A working, preferably wired, direct internet connection (firewalls
  are not supported).  
* At least 55 GB of spare disk space if the custom-made `vbox-img` tool patched
  from VirtualBox sources work on your platform. Otherwise, 100 GB of spare
  disk space.
* A removable USB storage device (USB stick or external USB drive) with at least
  55 GB of reachable space if Gentoo is to be directly installed to an external device directly. 

## Installation guidelines

* Clone or unpack  
* Check possible options and option defaults by calling: `mkgentoo.sh help` 

## In a nutshell

* To create a bootable ISO run with root privileges:     
     `# mkgentoo.sh  full/path/to/ISO/file`  
     
* To burn to DVD run:     
     `# mkgentoo.sh  full/path/to/ISO/file burn`   (if there is only one optical disc writer to your platform).  
     
* To supervise the VM run in the VirtualBox graphical user interface, add `vmtype=gui` to commandline. By default, the virtual machine runs silently.  

## Other options   

* To create a direct install of Gentoo to e.g. block device `/dev/sdc` add `usb_device=/dev/sdc` to commandine.  

* To create a USB stick CloneZilla installer (or recovery medium) on device `/dev/sdf` add `usb_installer=/dev/sdf` to commandline  

* To process a VM disk already created at a prior stage into an ISO file and/or external device installation, add `from_vm=true vm=name-of-virtual-machine`, with sdX the device identifier, to the requested options (ISO creation and/or `usb_installer=...`  and/or `burn`)

* To process an already created Gentoo install on a disk into an ISO file and/or a USB-stick CloneZilla installer add: `from_device=true usb_device=/dev/sdX` and the requested options (`usb_installer=...`, ISO file and/or `burn`)

* Likewise to process an already created ISO installer into a USB stick CloneZilla installer and/or burn the ISO to DVD add `from_iso=true`. Direct installation to device from iso is currently not supported: please use the ISO (e.g. burned to DVD) to create the installed OS.

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

* For COREi7 and higher-end processors, you may tweak the `cflags` option
  at your own risk. A good option is `cflags="-native -O2"`.    

## Warning
Building the platforms comes in with four dedicated cores as a default.   
If resources are strained, rerun with N cores by adding `ncpus=N`
to commandline.    
The `ncpus` number of jobs is used to implement the portage `CFLAGS`
parameter in **make.conf**, so that the building process is in line with ressources granted to
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
  
Boolean values are either 'true' or 'false'. For example, to build a minimal distribution, specify on command line: `minimal=true`  
     
   
------------------------------------------------------------------------------   
   
   

 | switch | description | default value |  
 |:-----:|:--------:|:-----:|  
| debug_mode 	| Do not clean up mkgentoo custom logs at root of gentoo system files before VM shutdown. Boolean. 	| [false] |  
| minimal 	| Remove *libreoffice* and *data science tools* from default list of installed software. Boolean. 	| [false] |  
| elist 	| 	 File containing a list of Gentoo ebuilds to add to the VM on top of stage3 	| [ebuilds.list] |  
| vm 	| 	 Virtual Machine name 	| [Gentoo] |  
| vbpath 	| Path to VirtualBox directory 	| [/usr/bin] |  
| vmpath 	| Path to VM base directory 	| [/home/fab/Dev/mkgentoo] |  
| mem 	| 	 VM RAM memory in MiB 	| [8000] |  
| ncpus 	| 	 Number of VM CPUs. By default the third of available threads. 	| [4] |  
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
| download 	| Download install ISO image from Gentoo mirror. Boolean. 	| [true] |  
| download_stage3 	| Download and install stage3 tarball to virtual disk. Booelan. 	| [true] |  
| download_rstudio 	| Download and build RStudio. Boolean. 	| [true] |  
| download_clonezilla 	| Refresh CloneZilla ISO download. Boolean 	| [true] |  
| download_clonezilla_path 	| Use the following CloneZilla ISO 	| [https://sourceforge.net/projects/clonezilla/files/clonezilla_live_alternative/20200703-focal/clonezilla-live-20200703-focal-amd64.iso/download] |  
| build_virtualbox 	| Download code source and automatically build virtualbox and tools 	| [false] |  
| vbox_version 	| Virtualbox version 	| [6.1.14] |  
| vbox_version_full 	| Virtualbox full version 	| [6.1.14a] |  
| lineno_patch 	| Line patched against vbox-img.cpp in virtualbox source code 	| [797] |  
| stage3 	| Path to stage3 archive 	| [stage3.tar.xz] |  
| create_squashfs 	| (Re)create the squashfs filesystem. Boolean. 	| [true] |  
| vmtype 	| gui or headless (silent) 	| [headless] |  
| kernel_config 	| Use a custom kernel config file 	| [.config] |  
| language 	| Set default login keyboard layout 	| [us] |  
| burn 	| Burn to optical disc. Boolean. 	| [false] |  
| cdrecord 	| cdrecord path. Automatically determined if left unspecified. 	| [/usr/local/bin/cdrecord] |  
| scsi_address 	| In case of several optical disc burners, specify the SCSI address as x,y,z 	| [] |  
| usb_device 	| Create Gentoo OS on external device. Argument is either a device label (e.g. sdb1, hdb1), or a mountpoint directory (if mounted), or a few consecutive letters of the model (e.g. 'Samsu', 'PNY' or 'Kingst'), if there is just one such. 	| [] |  
| usb_installer 	| Create Gentoo clone installer on external device. Argument is either a device label (e.g. sdb2, hdb2), or a mountpoint directory (if mounted), or a few consecutive letters of the model, if there is just one such. If unspecified, **usb_device** value will be used. OS Gentoo will be replaced by Clonezilla installer. 	| [] |  
| disable_md5_check 	| Disable MD5 checkums verification after downloads. Boolean. 	| [true] |  
| cleanup 	| Clean up archives, temporary images and virtual machine after successful completion. Boolean. 	| [true] |  
| help 	| 	 This help 	| [] |  
| from_vm 	| Do not generate Gentoo but use the VM . Boolean. 	| [false] |  
| from_iso 	| Do not generate Gentoo but use the bootable ISO given on commandline. Boolean. 	| [false] |  
| from_device 	| Do not Generate Gentoo but use the external device on which Gentoo was previously installed. Boolean. 	| [false] |  

