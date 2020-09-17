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
        # Currently hard-coded but should be exported to text file later on

	mkdir /etc/portage/package.accept_keywords
	
        echo '>=dev-libs/libpcre2-10.35 pcre16'        > /etc/portage/package.use/pcre2
        echo '>=x11-libs/libxkbcommon-0.10.0-r1 X'     > /etc/portage/package.use/libxkb
        echo '>=media-libs/libglvnd-1.3.2 X'           > /etc/portage/package.use/libglvnd  
	echo '>=dev-texlive/texlive-latex-2020 xetex' > /etc/portage/package.use/texlive
	echo 'sys-apps/util-linux caps'              > /etc/portage/package.use/util-linux
	echo 'app-arch/p7zip -kde -wxwidgets'        > /etc/portage/package.use/p7zip
	echo ">=dev-lang/R-${R_VERSION}  ~${PROCESSOR}"  > /etc/portage/package.accept_keywords/R
	echo "app-text/pandoc ~${PROCESSOR}"           > /etc/portage/package.accept_keywords/pandoc
	echo 'sys-auth/polkit  introspection kde nls pam elogind'  > /etc/portage/package.use/polkit
        echo ">=net-wireless/wpa_supplicant-2.9-r2 dbus"  > /etc/portage/package.use/wpa_supplicant
        echo '>=dev-qt/qtcore-5.14.2 icu'  > /etc/portage/package.use/qtcore
        echo '>=dev-lang/python-2.7.18-r1:2.7 sqlite'  > /etc/portage/package.use/python-2.7
        echo '>=media-libs/harfbuzz-2.6.7 icu'  > /etc/portage/package.use/harfbuzz
        echo '>=media-libs/gd-2.3.0 png'  > /etc/portage/package.use/gd
        echo '>=dev-qt/qtgui-5.14.2-r1 jpeg egl dbus'  > /etc/portage/package.use/qtgui
        echo '>=media-video/vlc-3.0.11.1 vorbis ogg dbus'  > /etc/portage/package.use/vlc
        echo '>=sys-libs/zlib-1.2.11-r2 minizip'  > /etc/portage/package.use/zlib
        echo '>=x11-libs/cairo-1.16.0-r4 X'  > /etc/portage/package.use/cairo
        echo '>=kde-frameworks/kwindowsystem-5.70.0 X'  > /etc/portage/package.use/kwindowsystem
        echo '>=dev-qt/qtwebengine-5.14.2 widgets'  > /etc/portage/package.use/qtwebengine
        echo '>=media-libs/mesa-20.0.8 wayland'  > /etc/portage/package.use/mesa
        echo '>=dev-qt/qtwebchannel-5.14.2 qml'  > /etc/portage/package.use/qtwebchannel
        echo '>=dev-libs/libxml2-2.9.10-r1 icu'  > /etc/portage/package.use/libxml2
        echo '>=media-libs/libvpx-1.7.0-r1 svc'  > /etc/portage/package.use/libvpx
        echo '>=dev-libs/xmlsec-1.2.30 nss'      > /etc/portage/package.use/xmlsec
        echo '>=app-text/ghostscript-gpl-9.52-r1 cups'  > /etc/portage/package.use/ghostscript
        echo '>=dev-qt/qtprintsupport-5.14.2 cups'      > /etc/portage/package.use/qtprintsupport
        echo '>=kde-frameworks/kdelibs4support-5.70.0 X'  > /etc/portage/package.use/kdelibs4support
        echo 'app-text/xmlto text' > /etc/portage/package.use/xmlto
        
        # One needs to build cmake without the qt5 USE value first, otherwise dependencies cannot be resolved.
        
	USE='-qt5' emerge -1 cmake
	
	if test $? != 0; then
	  echo "emerge cmake failed!"
	fi

        # LZ4 is a kernel dependency for newer linux kernels.
        
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

	# Localization. TODO: possibly enlarge by parametrization of commandline

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

	make syncconfig  # replaces silentoldconfig as of 4.19
	make -s -j${NCPUS} 2>/dev/null && make modules_install && make install
	
	if test $? != 0; then
	    echo "Kernel building failed!"
            exit -1
        fi
	
	genkernel --install initramfs
	emerge sys-kernel/linux-firmware
	make clean

	if test -f /boot/vmlinu*; then
	   echo "Kernel was built"
	else
	   echo "Kernel compilation failed!"
	   exit -1  
	fi
  	if test -f /boot/initr*.img; then
	   echo "initramfs was built"
	else
	   echo "initramfs compilation failed!"
	   exit -1  
	fi
}

function install_software {

        # to eschew corruption cases
     
        emerge dos2unix
        dos2unix ${ELIST}

        # TODO: develop several options wrt to package set.
        
        local packages=`grep -E -v '(^\s*$|^\s*#.*$)' ${ELIST} | sed "s/dev-lang\/R-.*$/dev-lang\/R-${R_VERSION}/"`

        # Trace for debugging
        
        echo ${packages} > package_list
        
        # do not quote!
        
	emerge -uDN ${packages}

        if test $? != 0; then
            echo "Main package build step failed!"
            exit -1
        fi

        # cleaning up a bit aggressively before cloning...
        
        eclean -d packages
        
        rm -rf /var/tmp/*
        rm -rf /var/log/*
        rm -rf /var/cache/distfiles/*

        # kernel sources will have to be reinstalled by user if necessary

        emerge --unmerge gentoo-sources
        emerge --depclean
        
        rm -rf /usr/src/linux/*
        
        eix-update

	# RStudio
	
        if test "${DOWNLOAD_RSTUDIO}" != "TRUE"; then
           return
        fi

	#	RScript Rdeps.R  # see ad-hoc script

	mkdir Build
	cd Build
	wget ${GITHUBPATH}${RSTUDIO}.zip
	
	if test $? != 0; then
	    echo "RStudio download faild!"
            exit -1
        fi
	
	unzip *.zip
	cd rstudio*
	mkdir build
	cd dependencies/common
	./install-mathjax
	./install-dictionaries
	cd -
	cd build

	cmake .. -DRSTUDIO_TARGET=Desktop -DCMAKE_BUILD_TYPE=Release -DRSTUDIO_USE_SYSTEM_BOOST=1 -DQT_QMAKE_EXECUTABLE=1 
	make -j4
	make -k install
        cd /
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
global_config
finalize
