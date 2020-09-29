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
# *******************************************************************************
#
## @file mkvm_chroot.sh
## @author Fabrice Nicol
## @copyright GPL v.3
## @brief Creating Gentoo filesystem in virtual disk
## @note This file is included into the clonezilla ISO liveCD,
## then copied to the root of the virtual disk.
## @defgroup mkFileSystem Create Gentoo linux filesystem on VM disk and emerge software.

## @fn adjust_environment()
## @details
## @li Set @b /etc/fstab, sync portage tree, select desktop profile @n
## @li Set a set of per-package use files and keywords @n
## @li Oneshot emerge of @b cmake and @b lz4, prerequisites to
## <tt> world </tt> update.
## @li Update <tt> world </tt>. Log into emerge.build. Exit on error. @n
## @li Set keymaps, localization and time
## @todo Add more regional options by parametrization of commandline
## @retval Exit -1 on error at <tt>emerge</tt> stage.
## @ingroup mkFileSystem

adjust_environment() {

    # Adjusting /etc/fstab

    local  uuid2=$(blkid | grep sda2 | cut -f2 -d' ')
    local  uuid3=$(blkid | grep sda3 | cut -f2 -d' ')
    local  uuid4=$(blkid | grep sda4 | cut -f2 -d' ')
    echo "Partition /dev/sda2 with ${uuid2}" | tee partition_log
    echo "Partition /dev/sda3 with ${uuid3}" | tee partition_log
    echo "Partition /dev/sda4 with ${uuid4}" | tee partition_log
    echo "${uuid2} /boot           vfat defaults            0 2"    >  /etc/fstab
    echo "${uuid3} none            swap sw                  0 0"    >> /etc/fstab
    echo "${uuid4} /               ext4 defaults            0 1"    >> /etc/fstab
    echo "/dev/cdrom /mnt/cdrom  auto noauto,user,discard 0 0"      >> /etc/fstab
    source /etc/profile

    # Refresh and rebuild @world
    # frequently emerge complains about having to be upgraded before anything else.
    # We shall use emerge-webrsync as emerge --sync is a bit less robust (rsync rotation bans...)

    emerge-webrsync
    emerge -1 sys-apps/portage
    if test $? != 0; then
        echo "emerge-webrsync failed!"
	exit -1
    fi
    local profile=$(eselect profile list | grep desktop | grep plasma | grep ${PROCESSOR} | grep -v systemd | tail -1 | cut -f1 -d'[' | cut -f1 -d']')
    eselect profile set ${profile}

    # Use and keywords
    # Currently hard-coded but should be exported to text file later on

    mkdir /etc/portage/package.accept_keywords
    echo '>=dev-libs/libpcre2-10.35 pcre16'        > /etc/portage/package.use/pcre2
    echo '>=dev-texlive/texlive-latex-2020 xetex' > /etc/portage/package.use/texlive
    echo 'sys-apps/util-linux caps'              > /etc/portage/package.use/util-linux
    echo 'app-arch/p7zip -kde -wxwidgets'        > /etc/portage/package.use/p7zip
    echo ">=dev-lang/R-${R_VERSION}  ~${PROCESSOR}"  > /etc/portage/package.accept_keywords/R
    echo "app-text/pandoc ~${PROCESSOR}"           > /etc/portage/package.accept_keywords/pandoc
    echo 'sys-auth/polkit  introspection nls pam'  > /etc/portage/package.use/polkit
    echo '>=dev-qt/qtcore-5.14.2 icu'  > /etc/portage/package.use/qtcore
    echo '>=dev-lang/python-2.7.18-r1:2.7 sqlite'  > /etc/portage/package.use/python-2.7
    echo '>=media-libs/harfbuzz-2.6.7 icu'  > /etc/portage/package.use/harfbuzz
    echo '>=media-libs/gd-2.3.0 png'  > /etc/portage/package.use/gd
    echo '>=dev-qt/qtgui-5.14.2-r1 jpeg egl'  > /etc/portage/package.use/qtgui
    echo '>=media-video/vlc-3.0.11.1 vorbis ogg'  > /etc/portage/package.use/vlc
    echo '>=sys-libs/zlib-1.2.11-r2 minizip'  > /etc/portage/package.use/zlib
    echo '>=dev-qt/qtwebengine-5.14.2 widgets'  > /etc/portage/package.use/qtwebengine
    echo '>=media-libs/mesa-20.0.8 wayland'  > /etc/portage/package.use/mesa
    echo '>=dev-qt/qtwebchannel-5.14.2 qml'  > /etc/portage/package.use/qtwebchannel
    echo '>=dev-libs/libxml2-2.9.10-r1 icu'  > /etc/portage/package.use/libxml2
    echo '>=media-libs/libvpx-1.7.0-r1 svc'  > /etc/portage/package.use/libvpx
    echo '>=dev-libs/xmlsec-1.2.30 nss'      > /etc/portage/package.use/xmlsec
    echo '>=app-text/ghostscript-gpl-9.52-r1 cups'  > /etc/portage/package.use/ghostscript
    echo '>=dev-qt/qtprintsupport-5.14.2 cups'      > /etc/portage/package.use/qtprintsupport
    echo 'app-text/xmlto text' > /etc/portage/package.use/xmlto

    # One needs to build cmake without the qt5 USE value first, otherwise dependencies cannot be resolved.

    USE='-qt5' emerge -1 cmake
    if test $? != 0; then
        echo "emerge cmake failed!"
	exit -1
    fi

    # LZ4 is a kernel dependency for newer linux kernels.

    emerge app-arch/lz4

    # Now on to updating @world set. Be patient and wait for about 15-24 hours

    emerge -uDN @world  2>&1          | tee emerge.build
    if test $? != 0; then
        echo "emerge @world failed!"  | tee emerge.build
        exit -1
    fi

    # Networking in the new environment

    echo hostname=${NONROOT_USER}pc > /etc/conf.d/hostname
    emerge --verbose net-misc/netifrc
    emerge --verbose sys-apps/pcmciautils
    if test $? != 0; then
        echo "emerge netifrs/pcmiautils failed!"
    fi
    echo "config_${eth}=dhcpcd" >> /etc/conf.d/net
    cd /etc/init.d
    local eth=$(ifconfig | cut -f1 -d' ' | line | cut -f1 -d':')  # No be refreshed as it is not the same shell
    ln -s net.lo net.${eth}
    cd -
    rc-update add net.${eth} default

    # Set keymaps and time

    if test ${LANGUAGE} == "fr"; then
        echo 'keymap="fr"' > /etc/conf.d/keymaps
        echo 'keymap="us"' >> /etc/conf.d/keymaps
    else
        echo 'keymap="us"' > /etc/conf.d/keymaps
    fi
    sed -i 's/clock=.*/clock="local"/' /etc/conf.d/hwclock

    # Localization.

    echo "fr_FR.UTF-8 UTF-8" > /etc/locale.gen
    echo "fr_FR ISO-8859-15" >> /etc/locale.gen
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "en_US ISO-8859-1"  >> /etc/locale.gen
    locale-gen
    eselect locale set 1
    env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
}

## @fn build_kernel()
## @details
## @li Emerge \b gentoo-sources, \b genkernel, \b pciutils and \b linux-firmware
## @li Mount /dev/sda2 to /boot/
## @li Build kernel and initramfs. Log into kernel.log.
## @retval Exit -1 on error.
## @ingroup mkFileSystem

build_kernel() {

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
    make -s -j${NCPUS} 2>&1 > kernel.log && make modules_install && make install
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

## @fn install_software()
## @details
## @li Emerge list of ebuilds on top of stage3 and system utils already merged.
## @li Optionaly download and build RStudio
## @retval Exit -1 on building errors
## @todo Add a script to build R dependencies
## @ingroup mkFileSystem

install_software() {

    # to avoid corruption cases of ebuild list dues to Windows editing

    cd /
    emerge dos2unix
    chown root ${ELIST}
    chmod +rw ${ELIST}
    dos2unix ${ELIST}

    # TODO: develop several options wrt to package set.

    local packages=`grep -E -v '(^\s*$|^\s*#.*$)' ${ELIST} | sed "s/dev-lang\/R-.*$/dev-lang\/R-${R_VERSION}/"`

    # Trace for debugging

    echo ${packages} > package_list

    # do not quote `packages' variable!

    emerge -uDN ${packages}
    res=$?

    # update environment

    env-update
    source /etc/profile
    if test $? != 0; then
        echo "Main package build step failed!" | tee log_install_software
        exit -1
    fi

    # optionally build RStudio and R dependencies (TODO)

    if test "${DOWNLOAD_RSTUDIO}" != "true"; then
        echo "No RStudio build" | tee log_install_software
        return
    fi

    mkdir Build
    cd Build
    wget ${GITHUBPATH}${RSTUDIO}.zip
    if test $? != 0; then
        echo "RStudio download failed!"  | tee log_install_software
        exit -1
    fi
    echo "Building RStudio" | tee log_install_software
    unzip *.zip
    cd rstudio*
    mkdir build
    cd dependencies/common
    ./install-mathjax
    ./install-dictionaries
    ./install-pandoc
    cd -
    cd build
    cmake .. -DRSTUDIO_TARGET=Desktop -DCMAKE_BUILD_TYPE=Release -DRSTUDIO_USE_SYSTEM_BOOST=1 -DQT_QMAKE_EXECUTABLE=1
    make -j${NCPUS} | tee log_install_software
    make -k install
    cd /
}


## @fn global_config()
## @details @li Cleanup log, distfiles (for deployment), kernel build sources and objects
## @li Log this into \b log_uninstall_software
## @li Update \b eix cache. Sets displaymanager for \b xdm.
## @li Add services: <b>sysklog, cronie, xdm, dbus, elogind</b>
## @li Substitute \b NetworkManager to temporary networking setup.
## @li Adjust group and \b sudo settings for non-root user and \b sddm
## @li Install \b grub in EFI mode.
## @li Set passwords for root and non-root user.
## @warning Fix \b sddm startup keyboard issue using <tt> setxkbmap</tt>
## @ingroup mkFileSystem

global_config() {
    echo "Cleaning up a bit aggressively before cloning..." | tee log_uninstall_software
    eclean -d packages                                      | tee log_uninstall_software
    rm -rf /var/tmp/*
    rm -rf /var/log/*
    rm -rf /var/cache/distfiles/*

    # kernel sources will have to be reinstalled by user if necessary

    emerge --unmerge gentoo-sources  2>&1 | tee log_uninstall_software.log
    emerge --depclean   2>&1              | tee log_uninstall_software.log
    rm -rf /usr/src/linux/*               | tee log_uninstall_software.log
    eix-update

    # Idealy the installers should do:
    # emerge gentoo-sources
    # cd /usr/src/linux
    # cp -f /boot/config* .config
    # make syncconfig
    # make modules_prepare
    # for the sake of ebuilds requesting prepared kernel sources
    # TODO: test ocs-run post_run commands.
    # Also for usb_installer=... *alone* the above code could be deactivated. But then a later from_vm call would have to clean sources to lighten the resulting ISO clonezilla image.

    # Configuration
    #-- sddm

    echo "#!/bin/sh"                   > /usr/share/sddm/scripts/Xsetup
    echo "setxkbmap ${LANGUAGE},us"    > /usr/share/sddm/scripts/Xsetup
    chmod +x /usr/share/sddm/scripts/Xsetup
    sed -i 's/DISPLAYMANAGER=".*"/DISPLAYMANAGER="sddm"/' /etc/conf.d/xdm

    #-- Services

    rc-update add sysklogd default
    rc-update add cronie default
    rc-update add xdm default
    rc-update add dbus default
    rc-update add elogind boot

    #-- Networkmanager

    for x in /etc/runlevels/default/net.* ; do rc-update del $(basename $x) default ; rc-service --ifstarted $(basename $x) stop; done
    rc-update del dhcpcd default
    rc-update add NetworkManager default

    #-- groups and sudo

    useradd -m -G users,wheel,audio,video,plugdev,sudo  -s /bin/bash ${NONROOT_USER}
    echo "${NONROOT_USER}     ALL=(ALL:ALL) ALL" >> /etc/sudoers
    gpasswd -a sddm video

    #-- Creating the bootloader

    grub-install --target=x86_64-efi --efi-directory=/boot --removable
    grub-mkconfig -o /boot/grub/grub.cfg

    #-- Passwords

    echo ${NONROOT_USER}:${PASSWD}  | chpasswd
    echo root:${ROOTPASSWD} | chpasswd
}

## @fn finalize()
## @details @li Cleanup \b .bashrc
## @li Cleanup other files except for logs if debug mode is on.
## @li Write zeros as much as possible to prepare for compacting.
## @ingroup mkFileSystem

finalize() {

    # Final steps: cleaning up

    sed -i 's/^export .*$//g' .bashrc
    rm -f mkvm_chroot.sh package_list ${ELIST}
    if test "${DEBUG_MODE}" != "true"; then
        rm -f *
    fi

    # prepare to compact with vbox-img compact --filename ${VMPATH}/${VM}.vdi

    cat /dev/zero > zeros ; sync ; rm zeros
}

adjust_environment
build_kernel
install_software
global_config
finalize
exit 0
