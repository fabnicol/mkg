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

function adjust_environment {

       # Adjusting /etc/fstab

        export  uuid2=$(blkid | grep sda2 | cut -f2 -d' ')
	export  uuid3=$(blkid | grep sda3 | cut -f2 -d' ')
	export  uuid4=$(blkid | grep sda4 | cut -f2 -d' ')

        echo "Partition /dev/sda2 with ${uuid2}"
        echo "Partition /dev/sda2 with ${uuid3}"
        echo "Partition /dev/sda2 with ${uuid4}"

	echo "${uuid2} /boot           vfat defaults            0 2"    >  /etc/fstab
	echo "${uuid3} none            swap sw                  0 0"    >> /etc/fstab
	echo "${uuid4} /               vfat defaults            0 1"    >> /etc/fstab
	echo "/dev/cdrom /mnt/cdrom  auto noauto,user,discard 0 0"      >> /etc/fstab
	
	source /etc/profile
	
	# Refresh and rebuild @world
	
	emerge --sync --quiet
	if test $? != 0; then
	  echo "emerge --sync failed!"
	fi
	  
	local profile=$(eselect profile list | grep desktop | grep plasma | grep ${PROCESSOR} | grep -v systemd | tail -1 | cut -f1 -d'[' | cut -f1 -d']')
	eselect profile set ${profile}

	# Use and keywords

	mkdir /etc/portage/package.accept_keywords
	echo '=dev-texlive/texlive-latex-2020 "xetex"' > /etc/portage/package.use/texlive
	echo 'util-linux "caps"'                 > /etc/portage/package.use/util-linux
	echo 'app-arch/p7zip "-kde -wxwidgets"'  > /etc/portage/package.use/p7zip
	echo '=dev-lang/R-4.0.2 "~${PROCESSOR}"' > /etc/portage/package.accept_keywords/R
	echo 'app-text/pandoc "~${PROCESSOR}"'   > /etc/portage/package.accept_keywords/pandoc
	
	USE='-qt5' emerge -1 cmake
	
	if test $? != 0; then
	  echo "emerge cmake failed!"
	fi
	
        emerge app-arch/lz4
	
	emerge -uDN @world

        if test $? != 0; then
	  echo "emerge @world failed!"
	fi
	
	# Networking in the new environment

	echo "hostname='${USER}pc'" > /etc/conf.d/hostname
	
	emerge --verbose net-misc/netifrc
	emerge --verbose sys-apps/pcmciautils

        if test $? != 0; then
	  echo "emerge netifrs/pcmiautils failed!"
	fi
	
	echo 'config_${eth}="dhcpcd"' >> /etc/conf.d/net
	
	cd /etc/init.d
	
	local eth=$(ifconfig | cut -f1 -d' ' | line | cut -f1 -d':')  # No be refreshed as it is not the same shell

	ln -s net.lo net.${eth}
	
	cd -
	
	rc-update add net.${eth} default
	
	echo 'keymap="fr"' > /etc/conf.d/keymaps
	sed -i 's/clock=.*/clock="local"/' /etc/conf.d/hwclock

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
        cp -vf .config /usr/src/linux        
	cd /usr/src/linux

	# kernel config issue here

	make synccconfig  # replaces silentoldconfig as of 4.19
	make -s -j${NCPUS} 2>/dev/null && make modules_install && make install
	
	if test $? != 0; then
	    echo "Kernel building failed!"
            exit -1
        fi
	
	genkernel --install initramfs
	emerge sys-kernel/linux-firmware

	if test -f /boot/vmlinu*; then
	   echo "Kernel was built"
	else
	   echo "Kernel compilation failed!"
	   exit -1  
	fi
  	if test -f /boot/initrd*.img; then
	   echo "initramfs was built"
	else
	   echo "initramfs compilation failed!"
	   exit -1  
	fi
}

function install_software {

        local EBUILDS_LIST="$(cat ${ELIST} | grep -E -v '\s*($|#.*)')"
	
	emerge -uDN ${EBUILDS_LIST}

	eix-update

	# RStudio
	
        if test "${DOWNLOAD_RSTUDIO}" != "TRUE"; then
           return
        fi

	#	RScript Rdeps.R  # see ad-hoc script

	mkdir /home/${USER}/Build
	cd /home/${USER}/Build
	wget ${GITHUBPATH}${RSTUDIO}.zip
	
	if test $? != 0; then
	    echo "RStudio download faild!"
            exit -1
        fi
	
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

adjust_environment
build_kernel
install_software
#global_config
#finalize
