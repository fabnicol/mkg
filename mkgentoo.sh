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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
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
     "mem"         "\t VM RAM memory in MiB"                                             "8000"
     "ncpus"       "Number of VM CPUs"                                                   "4"
     "processor"   "Processor type"                                                      "amd64"
     "size"        "\t Dynamic disc size"                                                "30000"
     "livecd"      "Path to the live CD that will start the VM"                          "gentoo.iso"
     "mirror"      "Mirror site for downloading of stage3 tarball"                       "http://gentoo.mirrors.ovh.net/gentoo-distfiles/"
     "emirrors"    "Mirror sites for downloading ebuilds"                                "http://gentoo.mirrors.ovh.net/gentoo-distfiles/"
     "elist"       "File containing a list of ebuilds to add to the VM on top of stage3" "ebuilds.list"
     "rstudio"     "RStudio version to be downloaded and built from github source"       "1.3.1073"
     "githubpath"  "RStudio Github path to zip: path right before version.zip"           "https://github.com/rstudio/rstudio/archive/v"
     "cflags"      "GCC CFLAGS options for ebuilds"                                      "-march=core-avx2 -O2" 
     "nonroot_user" "Non-root user"                                                       "fab"
     "passwd"  "User password"                                                       "dev20"
     "rootpasswd"  "Root password"                                                       "dev20" 
     "download"    "Download install ISO image from Gentoo mirror"                       "TRUE" 
     "create_squashfs"  "(Re)create the squashfs filesystem"                             "TRUE"
     "vmtype"      "gui or headless (silent)"                                            "headless")
     
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
local vm_arg=$(echo ${CLI} | sed -E "s/.*${sw}=([^ ]+).*/\1/")

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
echo "USAGE"
echo "mkgentoo  [[switch=argument]...] gentoo.iso"
echo 
echo "Switches:"

for ((i=1; i<${ARRAY_LENGTH}; i++)); do 

local sw=$(($i*3))
local desc=$(($i*3+1))
local def=$(($i*3+2))

echo -e "  ${ARR[$sw]} \t ${ARR[$desc]} \t [default ${ARR[$def]}]"   
done

echo 
echo "Argument: path to ISO file to be created [default gentoo.iso]"
}

function fetch_livecd {

	if test "${DOWNLOAD}" != "TRUE"; then
	   LIVECD=install*.iso
	   return;
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
	  downloaded=$(basename ${current})	
	   if test -f ${downloaded}; then
	     LIVECD=${downloaded}
	   else
  	     echo "Could not find downloaded live CD"
	     exit -1
	   fi
	fi
        
}



function make_boot_from_livecd {

  if ! test -f install*.iso; then
    "No ISO file in current directory"
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
  
  mount -oloop install*.iso mnt/
  
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
  
  if test $? != 0; then
    echo "unsquashfs failed !"
    exit -1
  fi  
  
  cd squashfs-root
  
  if ! test -f ../../mkvm.sh; then
      echo "No mkvm.sh script!"
      exit -1
  fi
  if ! test -f ../../mkvm_chroot.sh; then
      echo "No mkvm_chroot.sh script!"
      exit -1
  fi
  if ! test -f ../../${ELIST}; then
      echo "No ebuild list!"
      exit -1
  fi
  
  cp -vf ../../mkvm.sh root
  chmod +x root/mkvm.sh
  cp -vf ../../mkvm_chroot.sh root
  chmod +x root/mkvm_chroot.sh

  cp -vf ../../${ELIST} root
  
  rc="root/.bashrc"
  cp -vf /etc/bash.bashrc ${rc}
  echo  "export MIRROR='${MIRROR}'"          >> ${rc}                   
  echo  "export EMIRRORS='${EMIRRORS}'"      >> ${rc}        
  echo  "export ELIST='${ELIST}'"            >> ${rc}        
  echo  "export RSTUDIO='${RSTUDIO}'"        >> ${rc}                 
  echo  "export CFLAGS='${CFLAGS}'"          >> ${rc}        
  echo  "export NONROOT_USER='${NONROOT_USER}'"      >> ${rc}        
  echo  "export ROOTPASSWD='${ROOTPASSWD}'"  >> ${rc}        
  echo  "export USERPASSWD='${USERPASSWD}'"  >> ${rc}        
  echo  "export GITHUBPATH='${GITHUBPATH}'"  >> ${rc}        
  echo  "export PROCESSOR='${PROCESSOR}'"    >> ${rc}        
  echo  "/bin/bash mkvm.sh"                  >> ${rc}

  cd  ..
  
  rm  image.squashfs
  mksquashfs squashfs-root/ image.squashfs
  rm -rf squashfs-root/
  
  cd ..
  
  mkisofs -J -R -o  install*.iso -b isolinux/isolinux.bin  -c isolinux/boot.cat  -no-emul-boot -boot-load-size 4  -boot-info-table  mnt2
  
  umount -l mnt
  rm -rf mnt
  rm -rf mnt2
  
}


# mkvm.sh should be adjacent to mkgentoo.sh

function create_vm {

	export PATH=${PATH}:${VBPATH}
	if test "$(VBoxManage list vms | grep ${VM})" != ""; then
        	if test "$(VBoxManage list runningvms | grep ${VM})" != ""; then
        	   VBoxManage controlvm ${VM} poweroff
        	fi
        	VBoxManage unregistervm Gentoo --delete
        fi	
	VBoxManage createvm --name ${VM} --ostype gentoo_64  --register
	VBoxManage modifyvm ${VM} --cpus ${NCPUS} --memory ${MEM} --vram 256
	VBoxManage createhd --filename ~/${VM}.vdi --size ${SIZE} --variant Standard
	VBoxManage storagectl ${VM} --name "SATA Controller" --add sata --bootable on
	VBoxManage storageattach ${VM} --storagectl "SATA Controller"  --medium ~/${VM}.vdi --port 0 --device 0 --type hdd
	VBoxManage storagectl ${VM} --name "IDE Controller" --add ide 
        VBoxManage storageattach ${VM} --storagectl "IDE Controller"  --port 0  --device 0   --type dvddrive --medium ${LIVECD}  --tempeject on
	VBoxManage storageattach ${VM} --storagectl "IDE Controller"  --port 0  --device 1   --type dvddrive --medium VBoxGuestAdditions.iso 
        VBoxManage startvm ${VM} --type ${VMTYPE}
	
#	sleep 30
#       local dest='"/root"'
# VBox bug : no copyto,  	
#	VBoxManage guestcontrol ${VM} --verbose  run --exe "'/root/mkvm.sh'" \
#	  --putenv   "MIRROR='${MIRROR}'"                     \
#	  --putenv   "EMIRRORS='${EMIRRORS}'"                 \
#          --putenv	  "ELIST='${ELIST}'"                  \
#          --putenv	  "RSTUDIO='${RSTUDIO}'"              \
#          --putenv	  "CFLAGS='${CFLAGS}'"                \
#          --putenv	  "NONROOT_USER='${NONROT_USER}'"                    \
#          --putenv	  "ROOTPASSWD='${ROOTPASSWD}'"        \
#          --putenv	  "USERPASSWD='${USERPASSWD}'"        \
#	  --putenv	  "GITHUBPATH='${GITHUBPATH}'"        \
#  	  --putenv	  "PROCESSOR='${PROCESSOR}'"          \
#	  --wait-stdout --wait-stderr 
}


if test "$(echo ${CLI} | sed 's/help//' )" != "${CLI}"; then
  help
  exit 0
fi

for ((i=0; i<ARRAY_LENGTH; i++)) ; do test_cli $i; done

fetch_livecd
make_boot_from_livecd
create_vm
