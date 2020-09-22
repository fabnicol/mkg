##
# Copyright (c) 2020 Fabrice Nicol <fabrnicol@gmail.com>
#
# This file is part of mkgentoo.
#
# mkgentoo is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# FFmpeg is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with FFmpeg; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 
##

#!/bin/bash
 
# USAGE
# mkgentoo  [[switch=argument]...] file.iso
# 
# Switches:
#  vm          Virtual Machine name [default Gentoo]
#  vbpath      Path to VirtualBox directory [default to /usr/bin]   
#  mem         VM RAM memory in MiB [default 8000]
#  ncpus       Number of VM CPUs    [default 4]
#  size        Dynamic disc size    [default 30000]
#  livecd      Path to the live CD that will start the VM    [default gentoo.iso]
#  mirror      Mirror site for downloading of stage3 tarball [default https://mirror.init7.net/gentoo//releases/amd64/autobuilds]
#  emirror     Mirror site for downloading ebuilds [default http://gentoo.mirrors.ovh.net/gentoo-distfiles/]
#  elist       File containing a list of ebuilds to add to the VM on top of stage3 [default ebuilds.list]
#  rstudio     RStudio version to be downloaded and built from github source [default v1.3.1073]


# GLOBAL VARIABLES:

CLI="$*"

ARR=("vm"          "Virtual Machine name"                                                "Gentoo"
     "vbpath"      "Path to VirtualBox directory"                                        "/usr/bin"
     "vmpath"      "Path to VM base directory"                                           "$PWD"  
     "mem"         "\t VM RAM memory in MiB"                                             "8000"
     "ncpus"       "Number of VM CPUs"                                                   "4"
     "processor"   "Processor type"                                                      "amd64"
     "size"        "\t Dynamic disc size"                                                "55000"
     "livecd"      "Path to the live CD that will start the VM"                          "gentoo.iso"
     "mirror"      "Mirror site for downloading of stage3 tarball"                       "http://gentoo.mirrors.ovh.net/gentoo-distfiles/"
     "emirrors"    "Mirror sites for downloading ebuilds"                                "http://gentoo.mirrors.ovh.net/gentoo-distfiles/"
     "elist"       "File containing a list of ebuilds to add to the VM on top of stage3" "ebuilds.list"
     "rstudio"     "RStudio version to be downloaded and built from github source"       "1.3.1073"
     "r_version"   "R version"                                                           "4.0.2"  
     "githubpath"  "RStudio Github path to zip: path right before version.zip"           "https://github.com/rstudio/rstudio/archive/v"
     "cflags"      "GCC CFLAGS options for ebuilds"                                      "-march=core-avx2 -O2" 
     "nonroot_user" "Non-root user"                                                      "fab"
     "passwd"      "User password"                                                       "dev20"
     "rootpasswd"  "Root password"                                                       "dev20" 
     "download"    "Download install ISO image from Gentoo mirror"                       "true"
     "download_stage3" "Download and install stage3 tarball to virtual disk"             "true"
     "download_rstudio"  "Download and build RStudio"                                    "true"
     "download_clonezilla" "Refresh CloneZilla ISO download"                             "false"
     "donwload_clonezilla_path" "Use the following CloneZilla ISO"                       "https://sourceforge.net/projects/clonezilla/files/clonezilla_live_alternative/20200703-focal/clonezilla-live-20200703-focal-amd64.iso/download"
     "stage3"      "Path to stage3 archive"                                              "stage3.tar.xz"     
     "create_squashfs"  "(Re)create the squashfs filesystem"                             "true"
     "vmtype"      "gui or headless (silent)"                                            "headless"
     "kernel_config"  "Use a custom kernel config file"                                  ".config"
     "language"    "Set default login keyboard layout"                                   "us"
     "burn"        "Burn to optical disc. Argument is either a device label (e.g. cdrom, sr0) or a mountpoint directory."  "false"
     "scsi_address" "In case of several optical disc burners, specify the SCSI address as x,y,z"  "0,0,0"
     "usb_device"  "Create Gentoo OS on external device.\n\t\tArgument is either a device label (e.g. sdb1, hdb1), or a mountpoint directory."    ""
     "usb_installer" "Create Gentoo clone installer on external device.\n\t\tArgument is either a device label (e.g. sdb2, hdb2), or a mountpoint directory.\n\t\tIf unspecified, usb_device value will be used. OS Gentoo will be replaced by Clonezilla installer."  ""
     "disable_md5_check" "Disable MD5 checkums verification after downloads"             "true"
     
    )
     
ARRAY_LENGTH=$((${#ARR[*]}/3))

ISO="downloaded.iso"

# test_cli 
#
# Analyses commandline
#
# arguments :
#  cli          Commandline
# creates globals of the form VAR=arg  when there is var=arg on commandline
# otherwise assigns default values VAR=defaults (3rd argument in array ARR)

function test_cli {

# check version

local vbox_version=$(VBoxManage -v)
local version_major=$(echo ${vbox_version} | sed -E 's/([0-9]+)\..*/\1/')
local version_minor=$(echo ${vbox_version} | sed -E 's/[0-9]+\.([0-9]+)\..*/\1/')
local version_index=$(echo ${vbox_version} | sed -E 's/[0-9]+\.[0-9]+\.([0-9][0-9]).*/\1/')

if test ${version_major} -lt 6 -o ${version_minor} -lt 1 -o ${version_index} -lt 10; then
    echo "VirtualBox must be at least version 6.1.14"
    echo "Please update and reinstall"
    exit -1
fi
    
local sw=${ARR[$(($1 * 3))]}
local desc=${ARR[$(($1 * 3 + 1))]}
local default=${ARR[$(($1 * 3 + 2))]}
local vm_arg=$(echo ${CLI} | sed -E "s/(^${sw}|.* ${sw})=([^ ]+).*/\2/")

ISO_OUTPUT=$(echo ${CLI} | sed -E 's/.*(\b\w+)\.(iso|ISO)/\1\.iso/')

if test "${ISO_OUTPUT}" != "" -a "${ISO_OUTPUT}" != "${CLI}"; then
    echo "Build Gentoo distribution to bootable ISO output ${ISO_OUTPUT}"
    CREATE_ISO="true"
else
    echo "You did not indicate an ISO output file."
!    echo "A Virtual machine will be created with name Gentoo under $HOME"
    CREATE_ISO="false"
fi

VAR=$(echo ${sw} | tr "[a-z]" "[A-Z]")

if test "${vm_arg}" != "" -a "${vm_arg}" != "${CLI}" ; then  # No args or no option
   echo "${desc}" = "${vm_arg}" | sed 's/\\t //' 
   eval "${VAR}"="\"${vm_arg}\""
else
   echo "${desc}" = "${default}" | sed 's/\\t //'   
   eval "${VAR}"="\"${default}\""
fi

}

# check_md5sum
#
# Checks md5sums in file MD5SUMS
# Returns 0 on success otherwise -1 on exit

function check_md5sum {

  local ref=$(cat MD5SUMS | grep "$1" | cut -f 1 -d' ')  

  downloaded=$(md5sum $1 | cut -f 1 -d' ')

  if test ${downloaded} = ${ref}; then
      return 0
  else
      echo "MD5 checkum for $1 is not correct. Please download manually..."
      exit -1
  fi
    
}

# help
#
# Prints usage

function help {
echo "USAGE:"
echo "mkgentoo  [[switch=argument]...]  filename.iso  [1]"
echo "mkgentoo  [[switch=argument]...]                [2]" 
echo
echo "Usage [1] creates a bootable ISO output file with a current Gentoo distribution."
echo "Usage [2] creates a VirtualBox VDI dynamic disk and a virtual machine with name Gentoo."
echo "Warning: you should have at least 50 GB of free disk space in the current directory or in vmpath if specified."
echo "Switches:"

for ((i=1; i<${ARRAY_LENGTH}; i++)); do 

local sw=$(($i*3))
local desc=$(($i*3+1))
local def=$(($i*3+2))

echo -e "  ${ARR[$sw]} \t ${ARR[$desc]} \t [default ${ARR[$def]}]"   
done

echo 

}


# fetch_livecd
#
# Downloads Gentoo install CD
# Caches it as ${ISO}
# Returns 0 on success or -1 on exit

function fetch_livecd {

        local CACHED_ISO="install-${PROCESSOR}-minimal.iso"        
	if test ${DOWNLOAD} = "false"; then
           if test -f ${CACHED_ISO}; then   
             cp -vf ${CACHED_ISO} ${ISO}
             LIVECD=${ISO}
             return 0
           else
             echo "No ISO file was found, please rerun with download=true"
             exit -1  
           fi  
	fi   
	
	rm install-${PROCESSOR}-minimal*\.iso*
	rm latest-install-${PROCESSOR}-minimal*\.txt*
	
        local downloaded=""

        wget ${MIRROR}/releases/${PROCESSOR}/autobuilds/latest-install-${PROCESSOR}-minimal.txt
	
	if test $? != 0; then
	  echo "Could not download live CD from Gentoo mirror"
	  exit -1
	fi
	
	local current=$(cat latest-install-${PROCESSOR}-minimal.txt | grep "install-${PROCESSOR}-minimal.*.iso" | sed -E 's/iso.*$/iso/' )
        local downloaded=$(basename ${current})	
	
	echo "Downloading $current..."
	
	wget "${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}"

        if test $? != 0; then
        
	   echo "Could not download live CD"
	   exit -1
	   
	else
	
            if test ${DISABLE_MD5_CHECK} = "false"; then
                check_md5sum ${downloaded}
            fi
        
 	   if test -f ${downloaded}; then
	     
             cp -vf ${downloaded} ${CACHED_ISO}
             mv ${downloaded} ${ISO}
             if test -f ${ISO}; then
                LIVECD=${ISO}
             else
                echo "No active ISO (downloaded.iso) file!"
                exit -1   
             fi   
               
	   else
	   
  	     echo "Could not find downloaded live CD ${downloaded}"
	     exit -1
	     
	   fi
	fi

        return 0
}

# fetch_stage3
#
# Downloads a fresh stage3 Gentoo archive
# Caches it as ${STAGE3}
# Returns 0 on success or -1 on exit

function fetch_stage3 {

        # Fetching stage3 tarball

	local CACHED_STAGE3="stage3-${PROCESSOR}.tar.xz"

	echo "download_stage3=${DOWNLOAD_STAGE3}"
	if test ${DOWNLOAD_STAGE3} = "true"; then
	    echo "Cleaning up stage3 data..."
            rm -vf latest-stage3*.txt*
	    echo "Downloading stage3 data..."
            wget ${MIRROR}/releases/${PROCESSOR}/autobuilds/latest-stage3-${PROCESSOR}.txt
            if test $? != 0; then
	      echo "Could not download stage3 from mirrors: ${MIRROR}/releases/${PROCESSOR}/autobuilds/latest-stage3-${PROCESSOR}.txt"
	      exit -1
	    fi
	else
	    if ! test -f latest-stage3-${PROCESSOR}.txt; then
		echo "No stage 3 download information available!"
		echo "Rerun with download_stage3=true"
		exit -1
	    fi
	fi
		
	local current=$(cat latest-stage3-${PROCESSOR}.txt | grep "stage3-${PROCESSOR}.*.tar.xz" | cut -f 1 -d' ')

	if test ${DOWNLOAD_STAGE3} = "true"; then
	  echo "Cleaning up stage3 archives(s)..."  
          rm -vf stage3-${PROCESSOR}-*tar.xz*
	  rm  ${STAGE3} 
          echo "Downloading ${current}..."
          
	  wget "${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}"
	
	  if test $? != 0; then
	    echo "Could not download stage3 tarball from mirror: ${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}"
	    exit -1
	  fi
          
          if test ${DISABLE_MD5_CHECK} = "false"; then
              check_md5sum $(basename ${current})
          fi    

          cp -vf $(echo ${current} | sed 's/.*stage3/stage3/')  ${CACHED_STAGE3}

	fi

	if ! test -f "${CACHED_STAGE3}"; then
            echo "No stage3 tarball!"
	    echo "Rerun with download_stage3=true"
            exit -1
	fi

	cp -vf ${CACHED_STAGE3} ${STAGE3}
}

# make_boot_from_livecd
#
# Unless create_squashfs=false is given on commandline
# tweaks the Gentoo minimal install CD so that the custom-
# made shell scripts are included into the squashfs filesystem
# as well as the stage3 archive.
# to be run in the ${VM} virtual machine
# Returns  0 on success or -1 on exit

function make_boot_from_livecd {

  if ! test -f ${ISO}; then
    echo "No active ISO file in current directory!"
    exit -1
  fi

  if test ${CREATE_SQUASHFS} = "false"; then
    return 0;
  fi
  
  mountpoint -q mnt && sudo umount -l mnt 
  
  if test -d mnt; then
   sudo rm -rf mnt 
  fi
  
  mkdir mnt
  
  sudo mount -oloop ${ISO} mnt/
  
  ! mountpoint -q mnt && echo "ISO not mounted!" && exit -1
  
  if test -d mnt2; then  
    sudo rm -rf mnt2
  fi
  
  mkdir mnt2
  
  rsync -av mnt/ mnt2
  
  cd mnt2/isolinux
  
  sed -i 's/timeout.*/timeout 1/' isolinux.cfg
  sed -i 's/ontimeout.*/ontimeout gentoo/' isolinux.cfg
  
  cd ..
  
  sudo unsquashfs image.squashfs
  
  if test $? != 0; then
    echo "unsquashfs failed !"
    exit -1
  fi  

  cd ..
  
  if ! test -f mkvm.sh; then
      echo "No mkvm.sh script!"
      exit -1
  fi
  if ! test -f mkvm_chroot.sh; then
      echo "No mkvm_chroot.sh script!"
      exit -1
  fi
  if ! test -f ${ELIST}; then
      echo "No ebuild list!"
      exit -1
  fi
  if ! test -f ${STAGE3}; then
      echo "No stage3 archive!"
      exit -1
  fi
  if ! test -f ${KERNEL_CONFIG}; then
      echo "No kernel configuration file!"
      exit -1
  fi

  local sqrt="mnt2/squashfs-root/root/"
  sudo chown fab ${sqrt}
  mv -vf ${STAGE3} ${sqrt}
  
  cp -vf mkvm.sh ${sqrt}
  chmod +x ${sqrt}mkvm.sh
  
  cp -vf mkvm_chroot.sh ${sqrt}
  chmod +x ${sqrt}mkvm_chroot.sh

  cp -vf ${ELIST} ${sqrt}

  cp -vf ${KERNEL_CONFIG} ${sqrt}

  cd ${sqrt}
    
  rc=".bashrc"
  cp -vf /etc/bash.bashrc ${rc}
  
  for ((i=0; i<ARRAY_LENGTH; i++)); do
     local  capname=${ARR[$((i * 3))]^^}
     local  expstring="export ${capname}=\"${!capname}\""
      echo "${expstring}"
      echo "${expstring}" >> ${rc}
  done    
    
  echo  "/bin/bash mkvm.sh"  >> ${rc}

  cd ../..
  
  rm  image.squashfs
  sudo mksquashfs squashfs-root/ image.squashfs
  sudo rm -rf squashfs-root/
  
  cd ..
  
  mkisofs -J -R -o  ${ISO} -b isolinux/isolinux.bin  -c isolinux/boot.cat  -no-emul-boot -boot-load-size 4  -boot-info-table  mnt2

  if test $? != 0; then
      echo "mkisofs could not recreate the ISO file to boot virtual machine ${VM}"
      exit -1
  fi
  
  sudo umount -l mnt
  sudo chown -R fab .
  rm -rvf mnt
  rm -rvf mnt2
  return 0
}

# test_vm_running
#
# Checks if VM as first named argument exists and is running
# Returns 0 on success and 1 is VM is not listed or not running

function test_vm_running {

   if test "$(VBoxManage list vms | grep "$1")" != "" -a "$(VBoxManage list runningvms | grep "$1")" != ""; then
     return 0
   fi   
return 1
}

# delete_vm
#
# Powers off, possibly with emergency stop, the VM names as first argument
# Unregisters it
# Deletes its folder structure and hard drive (default is "vdi" as a second argument)
# Returns 0 if Directory and hard drive could be erased, otherwise the OR value of both
# erasing commands

function delete_vm  {
          
   if test_vm_running "$1"; then 
        VBoxManage controlvm "$1" poweroff
   fi
   if test_vm_running "$1"; then
       VBoxManage startvm $1 --type emergencystop
   fi    
   
   if test "$(VBoxManage list vms | grep "$1")" != ""; then
       VBoxManage unregistervm "$1" --delete
   fi
	
   if test -d "${VMPATH}/$1"; then
      sudo rm -rvf  "${VMPATH}/$1"
   fi
   res=$?   
   if test "$2" != "" -a -f "${VMPATH}/$1.$2"; then
      sudo rm -f   "${VMPATH}/$1.$2"
   fi
   res=$(($? | ${res}))
   return ${res}
}

# mkvm.sh should be adjacent to mkgentoo.sh

function create_vm {

        export PATH=${PATH}:${VBPATH}
	cd ${VMPATH}
        
        delete_vm ${VM} "vdi"
        
	VBoxManage createvm --name "${VM}" --ostype gentoo_64  --register  --basefolder "${VMPATH}"
	VBoxManage modifyvm "${VM}" --cpus ${NCPUS} --cpu-profile host --memory ${MEM} --vram 256 --ioapic on --usbxhci on --usbehci on
	VBoxManage createhd --filename "${VM}.vdi" --size ${SIZE} --variant Standard
	VBoxManage storagectl "${VM}" --name "SATA Controller" --add sata --bootable on
	VBoxManage storageattach "${VM}" --storagectl "SATA Controller"  --medium "${VM}.vdi" --port 0 --device 0 --type hdd
	VBoxManage storagectl "${VM}" --name "IDE Controller" --add ide 
        VBoxManage storageattach "${VM}" --storagectl "IDE Controller"  --port 0  --device 0   --type dvddrive --medium ${LIVECD}  --tempeject on
	VBoxManage storageattach "${VM}" --storagectl "IDE Controller"  --port 0  --device 1   --type dvddrive --medium emptydrive 
        VBoxManage startvm "${VM}" --type ${VMTYPE}
        
        # VM is created in a separate process
        # Wait for it to come to end 
        # Test if still running every minute

        while test_vm_running ${VM}; do
            echo "${VM} running..."
            sleep 60
        done
 
        VBoxManage modifyhd "${VM}.vdi" --compact  
	
}

function clonezilla_to_iso {

    if ! test -f "${VMPATH}/$2"/syslinux/isohdpfx.bin; then
        sudo cp -vf ${VMPATH}/clonezilla/syslinux/isohdpfx.bin "${VMPATH}/$2"/syslinux
    fi

    xorriso -as mkisofs   -isohybrid-mbr "$2"/syslinux/isohdpfx.bin  \
            -c syslinux/boot.cat   -b syslinux/isolinux.bin   -no-emul-boot \
            -boot-load-size 4   -boot-info-table   -eltorito-alt-boot   -e boot/grub/efiboot.img \
            -no-emul-boot   -isohybrid-gpt-basdat   -o "$1"  "$2"

    if test $? != 0; then
        echo "Could not create ISO image from ISO package creation directory"
        exit -1
    fi
}


# download_clonezilla_iso
#
# Performs a fresh download of clonezilla ISO to create the ISOVM machine
# Returns 0 on success and -1 on exit

function download_clonezilla_iso {

    local clonezilla_file=$(echo ${DOWNLOAD_CLONEZILLA_PATH} | sed -E 's/.*\/(.*)\/download/\1/')
    wget ${DOWNLOAD_CLONEZILLA_PATH} -O ${clonezilla_file}
    
    if test $? != 0; then
        echo "Could not download CloneZilla iso"
        exit -1
    fi
    local clonezilla_iso=$(ls clonezilla-live*amd64.iso)

    if test ${DISABLE_MD5_CHECK} = "false"; then
        check_md5sum  ${clonezilla_iso}
    fi
    CLONEZILLACD=${clonezilla_iso}
    return 0
}



function process_clonezilla_iso {

    # first cache it
    
    if test -f "${CLONEZILLACD}" -a "${CLONEZILLACD}" != "clonezilla.iso"; then
       cp -vf ${CLONEZILLACD} clonezilla.iso
    fi

    # now mount and unsquashfs
       
    if ! test -d mnt; then sudo rm -rf mnt; mkdir mnt; fi
    if ! test -d mnt2; then sudo rm -rf mnt2; mkdir mnt2; fi

    sudo mount -oloop ${CLONEZILLACD} ./mnt
    rsync -av ./mnt/ mnt2
    cd mnt2/live
    sudo unsquashfs filesystem.squashfs
    cp ${VMPATH}
    rm -rf ISOFILES/*
    rsync mnt2/ ISOFILES
    cp -vf clonezilla/restoredisk/isolinux.cfg ISOFILES/syslinux/
    cd -
    sudo cp -vf /etc/resolv.conf squashfs-root/etc
    for i in proc sys dev run; do sudo mount -B /$i squashfs-root/$i; done
    sudo chroot squashfs-root
    sudo mkdir /boot
    sudo apt update -y -q
    sudo apt upgrade -y -q
    local kernel=$(apt-cache search ^linux-image.*oem | tail -n1 | cut -f1 -d' ')
    sudo apt install -y -q ${kernel}
    local headers=$(apt-cache search ^linux-headers.*oem | tail -n1 | cut -f1 -d' ')
    sudo apt install --reinstall -y -q ${headers}
    sudo apt install -y -q build-essential gcc 
    sudo apt install -y -q virtualbox-dkms
    sudo apt install -y -q virtualbox-guest-additions-iso
    sudo mount -oloop /usr/share/virtualbox/VBoxGuestAdditions.iso /mnt
    
    cd /mnt
    /sbin/rcvboxadd quicksetup all
    sudo /bin/bash VBoxLinuxAdditions.run
    cd /
    sudo umount /mnt
    sudo apt remove -y -q ${headers} build-essential gcc  virtualbox-guest-additions-iso
    sudo apt autoremove -y -q
    exit
    sudo cp -vf --dereference squashfs-root/boot/vmlinuz  vmlinuz
    sudo cp -vf --dereference squashfs-root/boot/initrd.img  initrd.img
    sudo rm -rf squashfs-root/boot
    sudo rm -vf filesystem.squashfs
    for i in proc sys dev  run; do sudo umount squashfs-root/$i; done
    sudo mksquashfs squashfs-root filesystem.squashfs
    sudo rm -rf squashfs-root/
    cd "${VMPATH}/mnt2"
    sudo cp -vf ../clonezilla/savedisk/isolinux.cfg  syslinux
    cd "${VMPATH}"
    sudo rm -vf ${CLONEZILLACD}
    echo
    clonezilla_to_iso ${CLONEZILLACD} "mnt2"
    sudo rm -rf mnt2
}

function create_iso_vm {
        cd ${VMPATH}

        if test ${DOWNLOAD_CLONEZILLA} = "true"; then
            download_clonezilla_iso
            process_clonezilla_iso
        fi
    
        gpasswd -a ${USER} -g vboxusers
        chgrp vboxusers "ISOFILES/home/partimag/image"
	delete_vm ${ISOVM}        
	VBoxManage createvm --name "${ISOVM}" --ostype ubuntu_64  --register  --basefolder "${VMPATH}"

	VBoxManage modifyvm "${ISOVM}" --cpus ${NCPUS} --cpu-profile host --memory ${MEM} --vram 256 --ioapic on --usbxhci on --usbehci on
	VBoxManage storagectl "${ISOVM}" --name "SATA Controller" --add sata --bootable on
        # This to avoid issues with already-used vdis in debug tests
        VBoxManage internalcommands sethduuid "${ISOVM.vdi}"
	VBoxManage storageattach "${ISOVM}" --storagectl "SATA Controller"  --medium "${ISOVM}.vdi" --port 0 --device 0 --type hdd
	VBoxManage storagectl "${ISOVM}" --name "IDE Controller" --add ide 
        VBoxManage storageattach "${ISOVM}" --storagectl "IDE Controller"  --port 0  --device 0   --type dvddrive --medium ${CLONEZILLACD}  --tempeject on
	VBoxManage storageattach "${ISOVM}" --storagectl "IDE Controller"  --port 0  --device 1   --type dvddrive --medium emptydrive 
        VBoxManage startvm "${ISOVM}" --type ${VMTYPE}
        
        # must be running to work: note, requests 6.1.14 at least
        VBoxManage sharedfolder add "${ISOVM}" --name shared --hostpath "${VMPATH}/ISOFILES/home/partimag/image"  --automount --auto-mount-point "/home/partimag" --transient
        
        while test_vm_running ${ISOVM}; do
            echo "${ISOVM} running..."
            sleep 60
        done
}

# Gives device from mount folder input

function get_device {

  local device=""
    
  if test -d "$1"; then
      device=$(findmnt --raw --first -a -n -c $1 | cut -f2 -d' ')
  else
      if is_block_device "$1"; then
          echo "$1"
      else
          echo "$1 is neither a mountpoint nor a block device"
          exit -1
      fi
  fi

echo ${device}
    
}


function list_block_devices {

  echo  "$(lsblk -a -n -o KNAME | grep -v loop)"
}

# Returns 0 (true) if input is a block device otherwise 1

function is_block_device {

    local devices=$(list_block_devices)

    grep -q "$1" <<< "${devices}" && return 0
   
    return 1
}

# Gives mount folder from device label input

function get_mountpoint {

    if is_block_device "$1"; then
        
        echo "$1  is not a block device!"
        echo "Device labels should be in the following list:"
        echo $(list_block_devices)
        
        exit -1
    fi

    echo "$(findmnt --raw --first -a -n -c "$1" | cut -f1 -d' ')"
}


function clone_vm_to_usb {

    # Test whether USB_DEVICE is a mountpoint or a block device label

    USB_DEVICE=$(get_device ${USB_DEVICE})  

    # Should not occur, only for paranoia
    
    if test "${USB_DEVICE}" = ""; then
        echo "Could not set USB device ${USB_DEVICE}"
        exit -1
    fi
    
    # Using the custom-patched version of the vbox-img utility:
    bin/vbox-img compact --filename "${VMPATH}/${VM}.vdi" 
    bin/vbox-img convert --srcfilename "${VMPATH}/${VM}.vdi" --stdout --dstformat RAW | dd of=/dev/${USB_DEVICE} bs=4M status=progress
    
    if test $? = 0; then
        sync
        return $?
    else
        echo "Could not convert dynamic virtual disk to raw USB device!"
        exit -1
    fi
}

function clone_vm_to_raw {

    VBoxManage clonemedium "${VMPATH}/${VM}.vdi" "${VMPATH}/tmpdisk.raw" --format RAW   
}


function dd_to_usb {

    "Bare metal copy of RAW disk to USB device..."

    # Test whether USB_DEVICE is a mountpoint or a block device label

    USB_DEVICE=$(get_device ${USB_DEVICE})  

    # Should not occur, only for paranoia
    
    if test "${USB_DEVICE}" = ""; then
        echo "Could not set USB device ${USB_DEVICE}"
        exit -1
    fi
    
    dd if="${VMPATH}/tmpdisk.raw" of=/dev/${USB_DEVICE} bs=4M status=progress
    
    if test $? = 0; then
        echo "Removing temporary RAW disk..."
        rm -f ${VMPATH}/tmpdisk.raw
    fi    
    return $?  
}

function clonezilla_usb_to_image {

    find_ocs_sr=`which ocs-sr`
    if test "$find_ocs_sr" = ""; then
        echo "Could not find ocs_sr !"
        echo "Install Clonezilla in a standard path or rerun after adding its parth to the PATH environment variable"
        echo "Note: Debian-based distributions provide a handy `clonezilla` package."
        exit -1
    fi

    # At this stage USB_DEVICE can no longer be a mountpoint as it has been previously converted to device label
    
    findmnt /dev/${USB_DEVICE}  && echo "Device ${USB_DEVICE} is mounted to: $(get_mountpoint /dev/${USB_DEVICE})"  && echo "The external USB device should not be mounted"  && echo "Trying to unmount..." && sudo umount -l /dev/${USB_DEVICE}

    if test $? =0; then 
        echo "Managed to unmount /dev/${USB_DEVICE}"
    else
        echo "Could not manage to unmount external USB device"
        echo "Unmount it manually and rerun."
        exit -1
    fi
    
    # double check

    if  test `findmnt /dev/${USB_DEVICE}`; then
        echo "Impossible to unmount device ${USB_DEVICE}"
        exit -1
    fi

    if test -d /home/partimag; then
        echo "/home/partimag needs to be wiped out..."
        echo "Trying with user rights..."
        rm -rf /home/partimag
        if test $? != 0; then
            echo "Directory /home/partimag needs elevated rights..."
            echo "Waiting for sudo passwd..."
            sudo  rm -rf /home/partimag
            if test $? != 0; then
                echo "Could not fix /home/partimag issue."
                exit -1;
            fi
        fi   
    fi

    if test ${MINIMIZE_DISK_SPACE} = "true"; then

        echo "Erasing virtual disk and virtual machine to save disk space..."
        rm -f "${VMPATH}/${VM}.vdi"
        rm -rf "${VMPATH}/${VM}"
    fi

    rm -rf ISOFILES/home/partimag/image/*

    if test $? != 0; then
        echo "Could not remove old Clonezilla image"
        exit -1
    fi
            
    sudo ln -s  ${VMPATH}/ISOFILES/home/partimag/image  /home/partimag
    
    /usr/sbin/ocs-sr -q2 -c -j2 -nogui -batch -gm -gmf -noabo -z5 \
                     -i 40960000000 -fsck -senc -p poweroff savedisk gentoo.img ${USB_DEVICE}
   
    if test $? = 0 -a -f /home/partimag/gentoo.img; then
        echo "Cloning succeeded!"
    else
        echo "Cloning failed!"
        exit -1
    fi

    return 0
}

function burn_iso {

    res=0
    
    if test ${BURN} = "true"; then
        echo "Burning installation medium to optical disc..."
        if test "${SCSI_ADDRESS}" = ""; then
            cdrecord "${LIVECD}"
        else
            cdrecord "${LIVECD}" dev=${SCSI_ADDRESS}
        fi
        res=$?
    fi

    return ${res}
}


function create_install_usb_device {

    res=0
    
    if test ${USB_INSTALLER} = "true"; then
        echo "Creating installation stick..."
        dd if=${LIVECD} of=/dev/${USB_DEVICE} bs=4M status=progress
        res=$?
        sync
        res=$? | res
    fi

    return ${res}
}

if test "$(echo ${CLI} | sed 's/help//' )" != "${CLI}"; then
  help
  exit 0
fi

echo "PARAMETERS"
echo
for ((i=0; i<ARRAY_LENGTH; i++)) ; do test_cli $i; done
echo
echo "Fetching live CD..."
echo

fetch_livecd

echo
echo "Fetching stage3 tarball..."
echo

fetch_stage3

echo
echo "Tweaking live CD..."
echo

make_boot_from_livecd

echo 
echo "Creating VM"
echo

create_vm

if test $? != 0; then
    echo "VM failed to be created!"
    exit -1
fi

echo
if test ${CREATE_ISO} != "true"; then
    exit 0
fi

if test $VBOX_IMG_WORKS; then 

     echo "Cloning virtual disk to USB device ${USB_DEVICE} ..."
    
     clone_vm_to_usb
     
     if test $? != 0; then
        echo "Cloning VDI disk to USB deice failed !"
        exit -1
     fi
     
else
     echo "Cloning virtual disk to raw..."

     clone_vm_to_raw

     if test $? != 0; then
        echo "Cloning VDI disk to RAW failed !"
        exit -1
     fi

     echo
     echo "Copying to USB stick..."
     echo

     dd_to_usb

     echo
     if test $? != 0; then
       echo "Copying raw file to USB device failed!"
       echo "Check that your USB device has at least 50 GiB of reachable space"
       exit -1
     fi
fi     

echo "Launching Clonezilla to create compressed image..."
echo

# Succeeds or exits

clonezilla_usb_to_image

echo

echo "Launching Clonezilla to create ISO install medium..."
echo

clonezilla_to_iso ${LIVECD} ISOFILES

echo
if test $? = 0; then
    echo "Done."
    if test -f "${ISO_OUTPUT}"; then
        echo "ISO install medium was created here: ${ISO_OUTPUT}"
    else
        echo "ISO install medium failed to be created."
    fi
else
    echo "ISO install medium failed to be created!"
    exit -1
fi




