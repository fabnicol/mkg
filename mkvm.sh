/*
 * Copyright (c) 2020 Fabrice Nicol <fabrnicol@gmail.com>
 *
 * This file is part of mkgentoo.
 *
 * mkgentoo is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */


# Network

function setup_network {
local	eth=$(ifconfig | cut -f1 -d' ' | line | cut -f1 -d':')
	    net-setup  $eth #enp0s3
	    dhcpcd -HD $eth #enp0s3
}

# Partitioning

function partition {

	parted -a optimal /dev/sda "mklabel gpt unit mib \
	  mkpart primary 1 3 \
	  name 1 grub \
	  set 1 bios_grub on \
	  mkpart primary 3 131  \
	  name 2 boot  \
	  mkpart primary 131 643  \
	  name 3 swap  \
	  mkpart primary 643 -1  \
	  set 2 boot on"  
	mkfs.fat -F 32 /dev/sda2
	mkfs.ext4 /dev/sda4
	mkswap /dev/sda3
	swapon /dev/sda3
	mount  /dev/sda4 /mnt/gentoo

	# Adjusting /etc/fstab

    fstab="/mnt/gentoo/etc/fstab"
	
	local uuid2=$(blkid | grep sda2 | cut -f2 -d' ')
	local uuid3=$(blkid | grep sda3 | cut -f2 -d' ')
	local uuid4=$(blkid | grep sda4 | cut -f2 -d' ')

	echo "${uuid2} /boot           vfat defaults            0 2"    >  ${fstab}
	echo "${uuid3} none            swap sw                  0 0"    >> ${fstab}
	echo "${uuid4} /               vfat defaults            0 1"    >> ${fstab}
	echo "/dev/cdrom /mnt/cdrom  auto noauto,user,discard 0 0"      >> ${fstab}

}

function install_stage3 {

	# Time

	ntpd -q -g

	# Fetching stage3 tarball

	cd /mnt/gentoo
	wget ${MIRROR}/latest-stage3-${PROCESSOR}.txt
	if test $? != 0; then
	  echo "Could not download stage3 from Gentoo mirrors"
	  exit -1
	fi
	local current=$(cat latest-stage3-${PROCESSOR}.txt | grep "stage3-${PROCESSOR}.*.tar.xz" | cut -f 1 -d' ')S  
	echo "Downloading $current..."
	wget ${MIRROR}/${current}
	if test $? != 0; then
	  echo "Could not download stage3 tarball from OVH"
	  exit -1
	fi
	tar xpJvf $(ls stage3*) --xattrs-include='*.*' --numeric-owner 

	# Ajusting portage
	
	local m_conf=/mnt/gentoo/etc/portage/make.conf

	sed  -i 's/COMMON_FLAGS=".*"/COMMON_FLAGS="${CFLAGS} -pipe"/g'  $m_conf
	echo 'MAKEOPTS="-j8"'  >> $m_conf
	echo 'L10N="fr en"'    >> $m_conf
	echo 'LINGUAS="fr en"' >> $m_conf
	sed  -i 's/USE=".*"//g'    $m_conf
	echo 'USE="-gtk -gnome qt4 qt5 kde dvd alsa cdr bindist virtualbox networkmanager"' >>  $m_conf
	echo "GENTOO_MIRRORS=${EMIRRORS}"  >> $m_conf
	echo ACCEPT_LICENSE="-* @FREE linux-fw-redistributable no-source-code" >> $m_conf
	echo 'GRUB_PLATFORMS="efi-64"' >> $m_conf
	echo 'VIDEO_CARDS="nouveau"'   >> $m_conf
	echo 'INPUT_DEVICES="evdev synaptics"' >> $m_conf

	mkdir --parents /mnt/gentoo/etc/portage/repos.conf
	cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
	cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

	# Chrooting the new environment

	mount --types proc /proc /mnt/gentoo/proc
	mount --rbind /sys /mnt/gentoo/sys
	mount --make-rslave /mnt/gentoo/sys
	mount --rbind /dev /mnt/gentoo/dev
	mount --make-rslave /mnt/gentoo/dev
	cp .config /mnt/gentoo
	chroot /mnt/gentoo /bin/bash
	source /etc/profile
	export PS1="(chroot) ${PS1}"
}


function adjust_environment {

	# Refresh and rebuild @world
	
	emerge --sync --quiet
	local profile=$(eselect profile list | grep desktop | grep plasma | grep ${PROCESSOR} | grep -v systemd | tail -1 | cut -f1 -d'[' | cut -f1 -d']')
	eselect profile set ${profile}
	
	USE='-qt5' emerge -1 cmake
	emerge -uDN @world

	# Networking in the new environment

	echo "hostname='${USER}pc'" > /etc/conf.d/hostname
	emerge  net-misc/netifrc
	emerge sys-apps/pcmciautils
	echo 'config_${eth}="dhcpcd"' >> /etc.conf.d/net
	cd /etc/init.d 
	local eth=$(ifconfig | cut -f1 -d' ' | line | cut -f1 -d':')  # No be refreshed as it is not the same shell

	ln -s net.lo net.${eth}
	rc-update add net.${eth} default
	echo 'keymap="fr"' > /etc/conf.d/keymaps
	sed -i 's/clock=.*/clock="local"/' /etc/conf.d/hwclock

	# Use and keywords

	mkdir /etc/portage/package.accept_keywords
	echo 'app-arch/p7zip "-kde -wxwidgets"' > /etc/portage/package.use/p7zip
	echo '=dev-lang/R-4.0.2 "~${PROCESSOR}"' >/etc/portage/package.accept_keywords/R
	echo '=app-text/pandoc "~${PROCESSOR}"' >/etc/portage/package.accept_keywords/pandoc

	# Localization

	echo "fr_FR.UTF-8 UTF-8" > /etc/locale.gen
	echo "fr_FR ISO-8859-15" >> /etc/locale.gen
	echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
	echo "en_US ISO-8859-1" >> /etc/locale.gen
	locale-gen
	eselect locale set 1
	env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
}

function build_kernel {

	# Building the kernel

	emerge gentoo-sources
	emerge sys-kernel/genkernel
	emerge pciutils

	# Now mount the new boot partition 
	mount /dev/sda2 /boot

	cd /usr/src/linux
	# kernel config issue here
	mv /.config .
	make silentoldconfig
	make && make modules_install
	make install
	genkernel --install initramfs
	emerge sys-kernel/linux-firmware
}

function install_software {

	# E-builds

	## Extra sysutils

    local EBUILDS_LIST="$(cat ${ELIST} | grep -E -v '\s*($|#.*)')"
	
	emerge -uDN ${EBUILDS_LIST}

	eix-update

	RScript Rdeps.R  # see ad-hoc script

	# RStudio

	mkdir /home/${USER}/Build
	cd /home/${USER}/Build
	wget ${GITHUBPATH}${RSTUDIO}.zip
	unzip *.zip
	cd "rstudio*"
	mkdir build
	cd dependencies/common
	./install-mathjax
	./install-dictionaries
	cd -
	cd build

	cmake .. -DRSTUDIO_TARGET=Desktop -DCMAKE_BUILD_TYPE=Release -DRSTUDIO_USE_SYSTEM_BOOST=1 -DQT_QMAKE_EXECUTABLE=1 
	make -j4
	make -k install
}

function global_config {

	# Configuration

	## sddm 

	echo "setxkbmap fr" > /usr/share/sddm/scripts/Xsetup

	sed -i 's/DISPLAYMANAGER=""/DISPLAYMANAGER="sddm"/' /etc/conf.d/xdm

	## "LOCALAPPDATA" config dir

	mkdir -p ~/.local/share/Altair

	# Services

	rc-update add sysklogd default
	rc-update add cronie default
	rc-update add xdm default
	rc-update add virtualbox-guest-additions default
	rc-update add dbus default

	## Networkmanager

	for x in /etc/runlevels/default/net.* ; do rc-update del $(basename $x) default ; rc-service --ifstarted $(basename $x) stop; done

	rc-update del dhcpcd default
	rc-update add NetworkManager default

	# groups

	gpasswd -a ${USER}  video
	gpasswd -a sddm video
	gpasswd -a ${USER}  vboxguest
	gpasswd -a ${USER}  plugdev

	# Creating the bootloader

	grub-install --target=x86_64-efi --efi-directory=/boot --removable
	grub-mkconfig -o /boot/grub/grub.cfg
	useradd -m -G users,wheel,audio -s /bin/bash ${USER}

	# Passwords

	chpasswd ${USER}:${USERPASSWD}
	chpasswd root:${ROOTPASSWD}
}

function finalize {

	# Final steps
    exit	
	umount -l /mnt/gentoo/dev{/shm,/pts,}
	umount -R /mnt/gentoo
	shutdown -h now
}


exit 0 # debug

setup_network
partition
install_stage3
adjust_environment
build_kernel
install_software
global_config
finalize

