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
     "download"    "Download install ISO image from Gentoo mirror"                       "TRUE"
     "download_stage3" "Download and install stage3 tarball to virtual disk"             "TRUE"
     "download_rstudio"  "Download and build RStudio"                                    "TRUE"
     "stage3"      "Path to stage3 archive"                                              "stage3.tar.xz"     
     "create_squashfs"  "(Re)create the squashfs filesystem"                             "TRUE"
     "vmtype"      "gui or headless (silent)"                                            "headless"
     "kernel_config"  "Use a custom kernel config file"                                  ".config"
    )
     
ARRAY_LENGTH=$((${#ARR[*]}/3))

# test_cli 
#
# Analyses commandline
#
# arguments :
#  cli          Commandline
#  switch       Commandline switch
#  description  What the switch will be performing

function test_cli {

local sw=${ARR[$(($1 * 3))]}
local desc=${ARR[$(($1 * 3 + 1))]}
local default=${ARR[$(($1 * 3 + 2))]}
local vm_arg=$(echo ${CLI} | sed -E "s/(^${sw}|.* ${sw})=([^ ]+).*/\2/")

ISO_OUTPUT=$(echo ${CLI} | sed -E 's/.*(\b\w+)\.(iso|ISO)/\1\.iso/')

if test "${ISO_OUTPUT}" != "" -a "${ISO_OUTPUT}" != "${CLI}"; then
    echo "Build Gentoo distribution to bootable ISO output ${ISO_OUTPUT}"
    CREATE_ISO=1
else
    echo "You did not indicate an ISO output file."
    echo "A Virtual machine will be created with name Gentoo under /root"
    CREATE_ISO=0
fi

VAR=$(echo $sw | tr [a-z] [A-Z])

if test "${vm_arg}" != "" -a "${vm_arg}" != "${CLI}" ; then  # No args or no option
   echo "${desc}" = "${vm_arg}" | sed 's/\\t //' 
   eval "${VAR}"="\"${vm_arg}\""
else
   echo "${desc}" = "${default}" | sed 's/\\t //'   
   eval "${VAR}"="\"${default}\""
fi

}

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

function fetch_livecd {

        local CACHED_ISO="install-${PROCESSOR}-minimal.iso"
        ISO="downloaded.iso"
        
	if test "${DOWNLOAD}" != "TRUE"; then
           if test -f ${CACHED_ISO}; then   
             cp -vf ${CACHED_ISO} ${ISO}
             LIVECD=${ISO}
             return
           else
             echo "No ISO file was found, please rerun with download=TRUE"
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
	
	echo "Downloading $current..."
	
	wget "${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}"
	
        if test $? != 0; then
        
	   echo "Could not download live CD"
	   exit -1
	   
	else
	
           local downloaded=$(basename ${current})	
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
}

function fetch_stage3 {

        # Fetching stage3 tarball

	local CACHED_STAGE3="stage3-${PROCESSOR}.tar.xz"

	echo "download_stage3=${DOWNLOAD_STAGE3}"
	if test "${DOWNLOAD_STAGE3}" = "TRUE"; then
	    echo "Cleaning up stage3 data..."
            rm -vf lastest-stage3*.txt*
	    echo "Downloading stage3 data..."
            wget ${MIRROR}/releases/${PROCESSOR}/autobuilds/latest-stage3-${PROCESSOR}.txt
            if test $? != 0; then
	      echo "Could not download stage3 from mirrors: ${MIRROR}/releases/${PROCESSOR}/autobuilds/latest-stage3-${PROCESSOR}.txt"
	      exit -1
	    fi
	else
	    if ! test -f latest-stage3-${PROCESSOR}.txt; then
		echo "No stage 3 download information available!"
		echo "Rerun with download_stage3=TRUE"
		exit -1
	    fi
	fi
		
	local current=$(cat latest-stage3-${PROCESSOR}.txt | grep "stage3-${PROCESSOR}.*.tar.xz" | cut -f 1 -d' ')

	if test "${DOWNLOAD_STAGE3}" = "TRUE"; then
	  echo "Cleaning up stage3 archives(s)..."  
          rm -vf stage3-${PROCESSOR}-*tar.xz*
	  rm  ${STAGE3} 
          echo "Downloading ${current}..."
	  wget "${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}"
	
	  if test $? != 0; then
	    echo "Could not download stage3 tarball from mirror: ${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}"
	    exit -1
	  fi

          cp -vf $(echo ${current} | sed 's/.*stage3/stage3/')  ${CACHED_STAGE3}

	fi

	if ! test -f "${CACHED_STAGE3}"; then
            echo "No stage3 tarball!"
	    echo "Rerun with download_stage3=TRUE"
            exit -1
	fi

	cp -vf ${CACHED_STAGE3} ${STAGE3}
}

function make_boot_from_livecd {

  if ! test -f ${ISO}; then
    echo "No active ISO file in current directory!"
    exit -1
  fi

  if test "${CREATE_SQUASHFS}" != "TRUE"; then
    return;
  fi
  
  mountpoint -q mnt && umount -l mnt 
  
  if test -d mnt; then
    rm -rf mnt 
  fi
  
  mkdir mnt
  
  mount -oloop ${ISO} mnt/
  
  ! mountpoint -q mnt && echo "ISO not mounted!" && exit -1
  
  if test -d mnt2; then  
    rm -rf mnt2
  fi
  
  mkdir mnt2
  
  rsync -av mnt/ mnt2
  
  cd mnt2/isolinux
  
  sed -i 's/timeout.*/timeout 1/' isolinux.cfg
  sed -i 's/ontimeout.*/ontimeout gentoo/' isolinux.cfg
  
  cd ..
  
  unsquashfs image.squashfs

  cd ..
  
  if test $? != 0; then
    echo "unsquashfs failed !"
    exit -1
  fi  
  
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
  mksquashfs squashfs-root/ image.squashfs
  rm -rf squashfs-root/
  
  cd ..
  
  mkisofs -J -R -o  ${ISO} -b isolinux/isolinux.bin  -c isolinux/boot.cat  -no-emul-boot -boot-load-size 4  -boot-info-table  mnt2
  
  umount -l mnt
  rm -rf mnt
  rm -rf mnt2
  
}


# mkvm.sh should be adjacent to mkgentoo.sh

function create_vm {

	export PATH=${PATH}:${VBPATH}
	if test "$(VBoxManage list vms | grep '${VM}')" != ""; then
          if test "$(VBoxManage list runningvms | grep '${VM}')" != ""; then
             VBoxManage controlvm "${VM}" poweroff
          fi
          VBoxManage unregistervm Gentoo --delete
        fi	
	VBoxManage createvm --name "${VM}" --ostype gentoo_64  --register  --basefolder "${VMPATH}"
	VBoxManage modifyvm "${VM}" --cpus ${NCPUS} --cpu-profile host --memory ${MEM} --vram 256 --ioapic on --usbxhci on --usbehci on
	VBoxManage createhd --filename "${VMPATH}/${VM}.vdi" --size ${SIZE} --variant Standard
	VBoxManage storagectl "${VM}" --name "SATA Controller" --add sata --bootable on
	VBoxManage storageattach "${VM}" --storagectl "SATA Controller"  --medium "${VMPATH}/${VM}.vdi" --port 0 --device 0 --type hdd
	VBoxManage storagectl "${VM}" --name "IDE Controller" --add ide 
        VBoxManage storageattach "${VM}" --storagectl "IDE Controller"  --port 0  --device 0   --type dvddrive --medium ${LIVECD}  --tempeject on
	VBoxManage storageattach "${VM}" --storagectl "IDE Controller"  --port 0  --device 1   --type dvddrive --medium emptydrive 
        VBoxManage startvm "${VM}" --type ${VMTYPE}
	

}

function clone_vm_to_raw {

 VBoxManage clonemedium "${VMPATH}/${VM}.vdi" "${VMPATH}/tmpdisk.raw" --format RAW   
}


function dd_to_USB {

    "Bare metal copy of RAW disk to USB device..."
    
    dd if="${VMPATH}/tmpdisk.raw" of=${USB_DEVICE} bs=4M status=progress
    
    if test $? = 0; then
        echo "Removing temporary RAW disk..."
        rm -f ${VMPATH}/tmpdisk.raw
    fi    
    return 0    
}

function clonezilla_to_image {
    return 0
}

function clonezilla_to_iso {
    retrun 0
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
if test ${CREATE_ISO} != 1; then
    exit 0
fi

echo "Cloning virtual disk to raw..."

clone_vm_to_raw

if test $? != 0; then
    echo "Cloning VDI disk to RAW failed !"
    exit -1
fi

echo
echo "Copying to USB stick..."
echo

dd_to_USB

echo
if test $? != 0; then
    echo "Copying raw file to USB device failed!"
    echo "Check that your USB device has at least 50 GiB of reachable space"
    exit -1
fi

echo "Launching Clonezilla to create compressed image..."
echo

clonezilla_to_image

echo

if test $? != 0; then
    echo "Clonezilla image failed to be created out of USB stick!"
    exit -1
fi

echo "Launching Clonezilla to create ISO install medium..."

clonezilla_to_iso

echo
if test $? = 0; then
    echo "Success."
    if test -f "${ISO_OUTPUT}"; then
        echo "ISO install medium was created here: ${ISO_OUTPUT}"
    else
        echo "ISO install medium failed to be created."
    fi
else
    echo "ISO install medium failed to be created!"
    exit -1
fi




