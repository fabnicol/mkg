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
* At least 100 GB of spare disk space.
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
    
Usage [1] creates a bootable ISO output file with a current Gentoo distribution.   
Usage [2] creates a VirtualBox VDI dynamic disk and a virtual machine with name Gentoo
    
*Warning: you should have at least 50 GB of free disk space in the current
directory or in vmpath if specified.*   
    
**Switches:**    
      
      vbpath           Path to VirtualBox directory                         [default /usr/bin]   
      vmpath           Path to VM base directory                            [default /home/fab/Dev/mkgentoo]   
      mem              VM RAM memory in MiB                                 [default 8000]   
      ncpus            Number of VM CPUs                                    [default 4]   
      processor        Processor type                                       [default amd64]   
      size             Dynamic disc size in MiB                             [default 50000]   
      livecd           Path to the live CD that will start the VM           [default gentoo.iso]   
      mirror           Mirror site for downloading of stage3 tarball        [default http://gentoo.mirrors.ovh.net/gentoo-distfiles/]  
      emirrors         Mirror sites for downloading ebuilds                 [default http://gentoo.mirrors.ovh.net/gentoo-distfiles/]   
      elist            File containing a list of ebuilds to add to the VM
                       on top of stage3                                     [default ebuilds.list]   
      rstudio          RStudio version to be downloaded and built from github
                       source  [default 1.3.1073]   
      r_version        R version                                            [default 4.0.2]   
      githubpath       RStudio Github path to zip: path right
                       before version.zip                                   [default https://github.com/rstudio/rstudio/archive/v]   
      cflags           GCC CFLAGS options for ebuilds                       [default -march=core-avx2 -O2]  
      nonroot_user     Non-root user                                        [default fab]   
      passwd           User password                                        [default dev20]   
      rootpasswd       Root password                                        [default dev20]   
      download         Download install ISO image from Gentoo mirror        [default TRUE]   
      download_stage3  Download and install stage3 tarball to virtual disk  [default TRUE]   
      download_rstudio Download and build RStudio                           [default TRUE]   
      stage3           Path to stage3 archive                               [default stage3.tar.xz]  
      create_squashfs  (Re)create the squashfs filesystem                   [default TRUE]   
      vmtype           gui or headless (silent)                             [default headless]   
      kernel_config    Use a custom kernel config file                      [default .config]
         





