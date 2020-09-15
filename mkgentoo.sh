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
#  vbpath      Path to VirtualBox directory [default to /c/Program Files/Oracle/VirtualBox]   
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
     "vbpath"      "Path to VirtualBox directory"                                        "/c/Program Files/Oracle/VirtualBox"   
     "mem"         "\t VM RAM memory in MiB"                                             "8000"
     "ncpus"       "Number of VM CPUs"                                                   "4"
	 "processor"   "Processor type"                                                      "amd64"
     "size"        "\t Dynamic disc size"                                                "30000"
     "livecd"      "Path to the live CD that will start the VM"                          "gentoo.iso"
     "mirror"      "Mirror site for downloading of stage3 tarball"                       "https://mirror.init7.net/gentoo"
     "emirrors"    "Mirror sites for downloading ebuilds"                                "http://gentoo.mirrors.ovh.net/gentoo-distfiles/"
     "elist"       "File containing a list of ebuilds to add to the VM on top of stage3" "ebuilds.list"
     "rstudio"     "RStudio version to be downloaded and built from github source"       "1.3.1073"
     "githubpath"  "RStudio Github path to zip: path right before version.zip"           "https://github.com/rstudio/rstudio/archive/v"
	 "cflags"      "GCC CFLAGS options for ebuilds"                                      "-march=core-avx2 -O2" 
	 "user"        "Non-root user"                                                       "fab"
	 "userpasswd"  "User password"                                                       "dev20"
	 "rootpasswd"  "Root password"                                                       "dev20" )

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
local vm_arg=$(echo $CLI | sed -E "s/.*${sw}=(\w+)\s+.*$/\1/")

VAR=$(echo $sw | tr [a-z] [A-Z])

if test "${vm_arg}" != ""; then
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

local downloaded=""

    wget ${MIRROR}/releases/${PROCESSOR}/autobuilds/latest-install-${PROCESSOR}-minimal.txt
	
	if test $? != 0; then
	  echo "Could not download live CD from Gentoo mirror"
	  exit -1
	fi
	
	local current=$(cat latest-install-${PROCESSOR}-minimal.txt | grep "install-${PROCESSOR}.*.iso" | cut -f 1 -d' ')  
	
	echo "Downloading $current..."
#	wget ${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}
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


# mkvm.sh should be adjacent to mkgentoo.sh

function create_vm {

	export PATH=${PATH}:${VBPATH}
	VBoxManage createvm --name ${VM} --ostype gentoo_64  --register
	VBoxManage modifyvm ${VM} --cpus ${NCPUS} --memory ${MEM} --vram 256
	VBoxManage createhd --filename ~/${VM}.vdi --size ${SIZE} --variant Standard
	VBoxManage storagectl ${VM} --name "SATA Controller" --add sata --bootable on
	VBoxManage storageattach ${VM} --storagectl "SATA Controller"  --medium ~/${VM}.vdi --port 0 --device 0 --type hdd
	VBoxManage storagectl ${VM} --name "IDE Controller" --add ide 
    VBoxManage storageattach ${VM} --storagectl "IDE Controller"  --port 0  --device 0   --type dvddrive --medium ${LIVECD}  --tempeject on
	VBoxManage storageattach ${VM} --storagectl "IDE Controller"  --port 0  --device 1   --type dvddrive --medium VBoxGuestAdditions.iso 
    VBoxManage startvm ${VM} --type headless
	
	sleep 30
#VBoxManage bug
local dest='"/root"'
  	VBoxManage guestcontrol ${VM} copyto 'C:\Users\Public\Dev\mkgentoo\mkvm.sh' '/' --verbose
	VBoxManage guestcontrol ${VM} --verbose  run --exe "'/mkvm.sh'" \
	  --putenv   "MIRROR='${MIRROR}'"                 \
	  --putenv   "EMIRRORS='${EMIRRORS}'"             \
      --putenv	  "ELIST='${ELIST}'"                  \
      --putenv	  "RSTUDIO='${RSTUDIO}'"              \
      --putenv	  "CFLAGS='${CFLAGS}'"                \
      --putenv	  "USER='${USER}'"                    \
      --putenv	  "ROOTPASSWD='${ROOTPASSWD}'"        \
      --putenv	  "USERPASSWD='${USERPASSWD}'"        \
	  --putenv	  "GITHUBPATH='${GITHUBPATH}'"        \
  	  --putenv	  "PROCESSOR='${PROCESSOR}'"          \
	  --wait-stdout --wait-stderr 
}


if test "$(echo ${CLI} | sed 's/help//' )" != "${CLI}"; then
  help
  exit 0
fi

for ((i=0; i<ARRAY_LENGTH; i++)) ; do test_cli $i; done

fetch_livecd
create_vm
