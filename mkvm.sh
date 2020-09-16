# *
# * Copyright (c) 2020 Fabrice Nicol <fabrnicol@gmail.com>
# *
# * This file is part of mkgentoo.
# *
# * mkgentoo is free software; you can redistribute it and/or
# * modify it under the terms of the GNU Lesser General Public
# * License as published by the Free Software Foundation; either
# * version 3 of the License, or (at your option) any later version.
# *
# * FFmpeg is distributed in the hope that it will be useful,
# * but WITHOUT ANY WARRANTY; without even the implied warranty of
# * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# * Lesser General Public License for more details.
# *
# * You should have received a copy of the GNU Lesser General Public
# * License along with FFmpeg; if not, write to the Free Software
# * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
# *


# Network

function setup_network {

if test "${SETUP_NETWORK}" = "DONE"; then
   return
fi

local	eth=$(ifconfig | cut -f1 -d' ' | line | cut -f1 -d':')
	    net-setup  $eth #enp0s3
	    dhcpcd -HD $eth #enp0s3

SETUP_NETWORK=DONE
}

# Partitioning

function partition {

if test "${PARTITION}" = "DONE"; then
   return
fi

	parted --script --align=opt /dev/sda "mklabel gpt unit mib mkpart primary 1 3 name 1 grub set 1 bios_grub on mkpart primary 3 131  name 2 boot mkpart primary 131 643 name 3 swap mkpart primary 643 -1 set 2 boot on"  
	mkfs.fat -F 32 /dev/sda2
	mkfs.ext4 /dev/sda4
	mkswap /dev/sda3
	swapon /dev/sda3
	
	mount  /dev/sda4 /mnt/gentoo

PARTITION="DONE"
}

function install_stage3 {

if test "${INSTALL_STAGE3}" = "DONE"; then
   return
fi


	# Time

	ntpd -q -g

	# Fetching stage3 tarball

	cd /mnt/gentoo
	
	wget ${MIRROR}/releases/${PROCESSOR}/autobuilds/latest-stage3-${PROCESSOR}.txt
	if test $? != 0; then
	  echo "Could not download stage3 from mirrors: ${MIRROR}/releases/${PROCESSOR}/autobuilds/latest-stage3-${PROCESSOR}.txt"
	  exit -1
	fi
	local current=$(cat latest-stage3-${PROCESSOR}.txt | grep "stage3-${PROCESSOR}.*.tar.xz" | cut -f 1 -d' ')  
	echo "Downloading $current..."
	wget "${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}"
	if test $? != 0; then
	  echo "Could not download stage3 tarball from mirror: ${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}"
	  exit -1
	fi
	tar xpJf $(ls stage3*) --xattrs-include='*.*' --numeric-owner 

	# Ajusting portage
	
	local m_conf="etc/portage/make.conf"

	sed  -i "s/COMMON_FLAGS=.*/COMMON_FLAGS='${CFLAGS} -pipe'/g"  ${m_conf}
	echo 'MAKEOPTS="-j8"'  >> ${m_conf}
	echo 'L10N="fr en"'    >> ${m_conf}
	echo 'LINGUAS="fr en"' >> ${m_conf}
	sed  -i 's/USE=".*"//g'    ${m_conf}
	echo 'USE="-gtk -gnome qt4 qt5 kde dvd alsa cdr bindist virtualbox networkmanager"' >>  ${m_conf}
	echo "GENTOO_MIRRORS=${EMIRRORS}"  >> ${m_conf}
	echo ACCEPT_LICENSE="-* @FREE linux-fw-redistributable no-source-code" >> ${m_conf}
	echo 'GRUB_PLATFORMS="efi-64"' >> ${m_conf}
	echo 'VIDEO_CARDS="nouveau"'   >> ${m_conf}
	echo 'INPUT_DEVICES="evdev synaptics"' >> ${m_conf}

	mkdir --parents etc/portage/repos.conf
	cp usr/share/portage/config/repos.conf etc/portage/repos.conf/gentoo.conf
	cp --dereference /etc/resolv.conf etc/

	# Chrooting the new environment

	mount --types proc /proc proc
	mount --rbind /sys  sys
	mount --make-rslave sys
	mount --rbind /dev  dev
	mount --make-rslave dev

	chroot . /bin/bash ./mkvh_chroot.sh
			
	INSTALL_STAGE3="DONE"
}


setup_network
partition
install_stage3
adjust_environment
#build_kernel
#install_software
#global_config
#finalize

