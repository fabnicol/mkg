#!/bin/bash

# * Copyright (c) 2020 Fabrice Nicol <fabrnicol@gmail.com>.
# * This file is part of mkg.
# * mkg is free software; you can
# * redistribute it and/or modify it under the terms of the GNU Lesser
# * General Public License as published by the Free Software
# * Foundation; either version 3 of the License, or (at your option)
# * any later version. mkgento distributed in the hope that it will be
# * useful, but WITHOUT ANY WARRANTY; without even the implied
# * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# * See the GNU Lesser General Public License for more details.  You
# * should have received a copy of the GNU Lesser General Public
# * License along with FFmpeg; if not, write to the Free Software
# * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# * 02110-1301 USA
# * ******************************************************************
#
## @file mkvm_chroot.sh
## @author Fabrice Nicol
## @copyright GPL v.3
## @brief Creating Gentoo filesystem in virtual disk
## @note This file is included into the clonezilla ISO liveCD,
## then copied to the root of the virtual disk.
## @defgroup mkFileSystem Create Gentoo linux filesystem on VM disk
## and emerge software.

## @fn adjust_environment()
## @details
## @li Set @b /etc/fstab, sync portage tree, select desktop profile @n
## @li Set a set of per-package use files and keywords @n
## @li Oneshot emerge of @b cmake and @b lz4, prerequisites to
## <tt> world </tt> update.
## @li Update <tt> world </tt>. Log into emerge.build. Exit on error.
## @li Set keymaps, localization and time
## @todo Add more regional options by parametrization of commandline
## @retval -1 on error at <tt>emerge</tt> stage.
## @ingroup mkFileSystem

adjust_environment() {

    # Adjusting /etc/fstab

    local uuid2=$(blkid | grep sda2 | cut -f2 -d' ')
    local uuid3=$(blkid | grep sda3 | cut -f2 -d' ')
    local uuid4=$(blkid | grep sda4 | cut -f2 -d' ')
    echo "Partition /dev/sda2 with ${uuid2}" | tee log
    echo "Partition /dev/sda3 with ${uuid3}" | tee -a log
    echo "Partition /dev/sda4 with ${uuid4}" | tee -a log
    echo "${uuid2} /boot           vfat defaults            0 2" \
         >  /etc/fstab
    echo "${uuid3} none            swap sw                  0 0" \
         >> /etc/fstab
    echo "${uuid4} /               ext4 defaults            0 1" \
         >> /etc/fstab
    echo "/dev/cdrom /mnt/cdrom  auto noauto,user,discard 0 0"   \
         >> /etc/fstab

        # select profile (most recent plasma desktop)

    local profile
    if [ "${STAGE3_TAG}" = "openrc" ]
    then
        profile=$(eselect --color=no --brief profile list \
                      | grep desktop \
                      | grep gnome \
                      | grep ${PROCESSOR} \
                      | grep -v systemd \
                      | head -n 1)
    elif [ "${STAGE3_TAG}" = "systemd" ]
    then
        profile=$(eselect --color=no --brief profile list \
                      | grep desktop \
                      | grep gnome \
                      | grep ${PROCESSOR} \
                      | grep systemd \
                      | head -n 1)
        emerge -q --deselect sys-apps/openrc
        emerge -q --deselect sys-apps/sysvinit
    elif [ "${STAGE3_TAG}" = "hardened-openrc" ]
    then
        profile=$(eselect --color=no --brief profile list \
                      | grep hardened \
                      | grep ${PROCESSOR} \
                      | head -n 1)
    fi # Other values have been ruled out on launch.

    eselect profile set ${profile}

    # Use and keywords (mkdir -p to neutralize error msg)

    mkdir -p /etc/portage/package.accept_keywords
    mkdir -p /etc/portage/package.use
    cp -vf "${ELIST}.accept_keywords" \
       /etc/portage/package.accept_keywords/ \
        | tee emerge.build

    cp -vf "${ELIST}.use" /etc/portage/package.use/ \
        |  tee -a emerge.build

    cp -vf "${ELIST}.accept_keywords" \
       /etc/portage/package.accept_keywords/ \
        |  tee -a emerge.build

    source /etc/profile

    # Refresh and rebuild @world frequently emerge complains about
    # having to be upgraded before anything else.  We shall use
    # emerge-webrsync as emerge --sync is a bit less robust (rsync
    # rotation bans...)

    if ! emerge-webrsync
    then
        echo "[ERR] emerge-webrsync failed!" | tee -a emerge.build
        return 1
    fi

    perl-cleaner --reallyall | tee -a emerge.build


    # emerging gcc and glibc is mainly for CFLAGS changes and
    # otherwise for hardened profiles

    if  ! emerge -1 sys-devel/gcc
    then
        echo "[ERR] emerge gcc failed!" | tee -a emerge.build
        return 1
    fi

    if ! emerge -1 sys-libs/glibc
    then
        echo "[ERR] emerge glibc failed!" | tee -a emerge.build
        return 1
    fi

    if ! emerge -1 binutils virtual/libc
    then
        echo "[ERR] emerge binutils/libc failed!" | tee -a emerge.build
        return 1
    fi

    source /etc/profile

    # One needs to build cmake without the qt5 USE value first,
    # otherwise dependencies cannot be resolved.

    USE='-qt5' emerge -1 cmake
    if [ $? != 0 ]
    then
        echo "emerge cmake failed!" | tee -a emerge.build
        return 1
    fi

    # There is an intractable circular dependency that
    # can be broken by pre-emerging python

    USE="-sqlite -bluetooth" emerge -1 dev-lang/python \
        | tee -a emerge.build
    if [ $? != 0 ]
    then
        echo "emerge python failed!" | tee -a emerge.build
        return 1
    fi

    emerge -1 -u sys-apps/portage

    # solving circular dep.

    USE=-harfbuzz emerge -1 media-libs/freetype

    # add logger. However it will not be usable for now,
    # this is why we are using custom logs and tee's.

    if [ "${STAGE3_TAG}" != "systemd" ]
    then
        emerge -uD app-admin/sysklogd
        emerge -u sys-apps/pcmciautils net-misc/netifrc
        rc-update add sysklogd default
    fi

    # other core sysapps to be merged first. LZ4 is a kernel
    # dependency for newer linux kernels.

    if ! emerge -u net-misc/wget
    then
       echo "[ERR] emerge netifrs/pcmiautils failed!" | tee -a emerge.build
       return 1
    fi

    emerge -u app-arch/lz4

    # Now on to updating @world set. Be patient and wait for about
    # 15-24 hours
    # as syslogd is not yet there we tee a custom build log

    ## ---- PATCH ----
    #
    # This is temporarily necessary while display-manager is not
    # stabilized in the portage tree (March 2021)
    # NOTE: should be retrieved later on

    if [ "${STAGE3_TAG}" != "systemd" ]
    then
      emerge -q --unmerge sys-apps/sysvinit | tee -a emerge.build
    fi

    ## ---- End of patch ----

    emerge -uDN --with-bdeps=y @world 2>&1 | tee -a emerge.build

    # Second try

    if [ $? != 0 ]
    then
        echo "[ERR] emerge @world failed! Retrying..."  | tee -a emerge.build
        emerge -uDN --with-bdeps=y @world 2>&1 | tee -a emerge.build
    fi

    if [ $? != 0 ]
    then
        echo "[ERR] emerge @world failed!"  | tee -a emerge.build
        return 1
    fi

    if [ "${STAGE3_TAG}" != "systemd" ]
    then
      emerge -q -u sys-apps/sysvinit
    fi

    # Networking in the new environment

    echo hostname=${NONROOT_USER}pc > /etc/conf.d/hostname

    # Localization: we now generate all locales.

    locale-gen -A -j ${NCPUS} | tee -a emerge.build

    # Note: VM_LANGUAGE must be at least 5 characters, like fr_FR, fr_BE etc.

    [ -z "${VM_LANGUAGE}" ] && VM_LANGUAGE="en_US.utf8"

    LOCALE_FOUND=$(eselect locale list | \
                       grep -i -o -E \
                            "${VM_LANGUAGE}[@_a-zA-Z0-9.]*" | head -1)

    if [ -n "${LOCALE_FOUND}" ]
    then
        eselect locale set ${LOCALE_FOUND}
        if [ $? = 0 ]
        then
            LOCALE_UTF8=$(sed -E \
                           's/([a-z_A-Z]{2,5})\.?([@a-z_A-Z.0-9]*)/\1.UTF8/' \
                              <<< ${LOCALE_FOUND})
        else
            # fallback
            eselect locale set en_US.utf8
        fi
    else
        # fallback
        eselect locale set en_US.utf8
    fi

    # Gnome-specific. Missing LC_ALL blocks gnome-terminal startup.
    # Known gnome-terminal moot point. Useless on Plasma.
    # To be placed after call to locale-gen.

    if [ -n "${LOCALE_UTF8}" ]
    then
        echo "LC_ALL=${LOCALE_UTF8}" >> /etc/env.d/02locale
    else
        echo "LC_ALL=en_US.UTF8" >> /etc/env.d/02locale
    fi

    # Set keymaps and time
    # Check keymap existence

    KEYMAP_FOUND=$(ls -R /usr/share/keymaps | grep  ^${VM_KEYMAP}.map.gz \
                       | head -1)

    # Fallback

    if [ -z "${KEYMAP_FOUND}" ]
    then
        echo "Did not find keymap ${VM_KEYMAP} in /usr/share/keymaps." > log
        echo "Falling back on us" >> log
        VM_KEYMAP="us"
        KEYMAP_FOUND=us.map.gz
    fi

    echo "keymap=${KEYMAP_FOUND}" >>  /etc/conf.d/keymaps

    # GDM keyboard layout and X11 fallback

    mkdir -p /etc/X11/xorg.conf.d/
    pushd /etc/X11/xorg.conf.d/
    echo 'Section "InputClass"'                         > 00-keyboard.conf
    echo -e '\tIdentifier "system-keyboard"'           >> 00-keyboard.conf
    echo -e '\tMatchIsKeyboard "on"'                   >> 00-keyboard.conf
    echo -e "\tOption \"XkbLayout\" \"${VM_KEYMAP}\""  >> 00-keyboard.conf
    echo 'EndSection'                                  >> 00-keyboard.conf
    popd

    if [ "${STAGE3_TAG}" = "systemd" ]
    then
        ln -sf ../usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    else
        echo "${TIMEZONE}" > /etc/timezone
        emerge -u --config sys-libs/timezone-data | tee -a emerge.build
        sed -i 's/clock=.*/clock="local"/' /etc/conf.d/hwclock
    fi

    # endof Gnome-specific

    env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
}

## @fn build_kernel()
## @details
## @li Emerge \b gentoo-sources, \b genkernel,
##     \b pciutils and \b linux-firmware
## @li Mount /dev/sda2 to /boot/
## @li Build kernel and initramfs. Log into log.
## @retval  -1 on error.
## @ingroup mkFileSystem

build_kernel() {

    [ -d /usr/src/linux ] && rm -rf /usr/src/linux

    # Building the kernel

    emerge gentoo-sources   | tee -a log

    emerge sys-kernel/genkernel pciutils | tee -a log

    eselect kernel set 1

    # Now mount the new boot partition

    mount /dev/sda2 /boot
    cp -vf .config /usr/src/linux
    cd /usr/src/linux

    if [ "$PWD" != "/usr/src/linux" ]
    then
        echo "[ERR] Could not cd to /usr/src/linux" | tee -a log
        exit 2
    fi

    # kernel config issue here

    make olddefconfig # uses defaults for new config params.
    make -s -j${NCPUS}   2>&1 | tee -a  log
    make modules_install 2>&1 | tee -a  log
    make install         2>&1 | tee -a  log
    if  [ $? != 0 ]
    then
        echo "[ERR] Kernel building failed!" | tee -a log
        return 1
    fi

    genkernel --install initramfs     | tee -a log
    emerge sys-kernel/linux-firmware  | tee -a log
    make clean

    if [ -f /boot/vmlinuz* ]
    then
        echo "[MSG] Kernel was built" | tee -a log
    else
        echo "[ERR] Kernel compilation failed!"  | tee -a  log
        return 1
    fi

    if [ -f /boot/initr*.img ]
    then
        echo "[MSG] initramfs was built" | tee -a  log
    else
        echo "[ERR] initramfs compilation failed!" | tee -a  log
        return 1
    fi
}

## @fn install_software()
## @details
## @li Emerge list of ebuilds on top of stage3 and system utils
##     already merged.
## @li Optionaly download and build RStudio
## @retval -1 on building errors
## @todo Add a script to build R dependencies
## @ingroup mkFileSystem

install_software() {

    # to avoid corruption cases of ebuild list
    # caused by Windows editing

    cd / || exit 2
    emerge -u dos2unix  | tee -a log
    chown root ${ELIST}
    chmod +rw ${ELIST}
    dos2unix ${ELIST}

    local packages=`grep -E -v '(^\s*$|^\s*#.*$)' "${ELIST}"`

    # Trace for debugging

    echo "${packages}" > package_list

    # v1.3: adding --keep-going. Limited emerge failures may not render
    # the build useless.
    # allow some tolerance for incomplete builds caused
    # by changes in portage tree package names and versions.

    # do not quote `packages' variable!

    emerge -uDN --with-bdeps=y --keep-going ${packages}  2>&1 \
        | tee -a log
    local res_install=$?

    if [ "${res_install}" != "0" ]
    then
	    # one more chance, who knows
  	    emerge --resume | tee -a log
        res_install=$?
    fi

    if [ "${res_install}" != "0" ]
    then
    	# one more chance, who knows
	    emerge --resume | tee -a log
        res_install=$?
    fi

    if [ "${res_install}" != "0" ]
    then
        echo "[ERR] Main package build step failed" \
             | tee -a log
        return 1
    fi

    emerge -u gdm | tee -a log

    # do not use \ to continue line below:

    if [ "${MINIMAL}" = "false" ]
    then
        # this test is for second-chance debugging runs

        if ! Rscript -e "library(ggplot2)"
        then
            echo "install.packages(c('data.table', 'dplyr', 'ggplot2',
'bit64', 'devtools', 'rmarkdown'), repos=\"${CRAN_REPOS}\")" \
             > libs.R
            Rscript libs.R 2>&1 | tee -a log
        fi
    fi

    # update environment

    env-update
    source /etc/profile
    return ${res_install}
}

## @fn global_config()
## @details @li Cleanup log, distfiles (for deployment),
##          kernel build sources and objects
## @li Log this into \b log_uninstall_software
## @li Update \b eix cache. Sets display for \b display-manager.
## @li Add services: <b>sysklog, cronie, display-manager, dbus, elogind</b>
## @li Substitute \b NetworkManager to temporary networking setup.
## @li Adjust group and \b sudo settings for non-root user and \b sddm
## @li Install \b grub in EFI mode.
## @li Set passwords for root and non-root user.
## @warning Fix \b sddm startup keyboard issue using
##          <tt> setxkbmap</tt>
## @ingroup mkFileSystem

global_config() {

    sed -i 's/DISPLAYMANAGER=".*"/DISPLAYMANAGER="gdm"/' \
                /etc/conf.d/display-manager | tee -a log

    #--- Services
    if [ "${STAGE3_TAG}" = "systemd" ]
    then
        systemctl enable cronie.service
        systemctl enable gdm.service
    else
        rc-update add cronie default
        rc-update add display-manager default
        rc-update add dbus default
        rc-update add elogind boot
        rc-update add keymaps boot
    fi

    #--- Networkmanager
    if [ "${STAGE3_TAG}" != "systemd" ]
    then
        for x in /etc/runlevels/default/net.*
        do
            rc-update del $(basename $x) default
            rc-service --ifstarted $(basename $x) stop
        done
    fi

    if [ "${STAGE3_TAG}" = "systemd" ]
    then
        systemctl disable dhcpcd
        systemctl enable NetworkManager
    else
        rc-update del dhcpcd default
        rc-update add NetworkManager default
    fi

    #--- groups and sudo

    useradd -m -G users,wheel,audio,video,plugdev \
            -s /bin/bash "${NONROOT_USER}"

    if [ $? != 0 ]
    then
        echo "[ERR] Could not useradd user ${NONROOT_USER}" | tee -a log
    fi

    echo "${NONROOT_USER}     ALL=(ALL:ALL) ALL" >> /etc/sudoers

    # normally a non-op (useradd -m), just for paranoia

    chown -R ${NONROOT_USER}:${NONROOT_USER} /home/${NONROOT_USER}

    if ! which grub-mkconfig
    then
        echo "[ERR] Did not find grub!" | tee -a log
        return 3
    fi

    #--- Creating the bootloader

    if [ "${BIOS}" = "true" ]
    then
        grub-install /dev/sda
    else
        grub-install --target=x86_64-efi --efi-directory=/boot --removable
    fi

    if [ $? != 0 ]
    then
        echo "[ERR] Could not install grub" | tee -a log
        exit 1
    fi

    if [ "${STAGE3_TAG}" = "systemd" ]
    then
        echo 'GRUB_CMDLINE_LINUX="init=/lib/systemd/systemd"' >> /etc/default/grub
    fi

    grub-mkconfig -o /boot/grub/grub.cfg

    if [ $? != 0 ]
    then
        echo "[ERR] Could not configure grub" | tee -a log
        exit 1
    fi

    #--- Passwords: take care to use long enough passwds

    chpasswd <<< "${NONROOT_USER}":"${PASSWD}"
    chpasswd <<<  root:"${ROOTPASSWD}"
}

## @fn finalize()
## @details @li Cleanup \b .bashrc
## @li Cleanup other files except for logs if debug mode is on.
## @li Write zeros as much as possible to prepare for compacting.
## @ingroup mkFileSystem

finalize() {

    umount -l /boot

    # freeing up some disk space

    echo "Cleaning up a bit aggressively before cloning..." \
        | tee -a log

    # MINIMAL_SIZE should only be set for packaging purposes.
    # and avoided for personal use

    if "${MINIMAL_SIZE}"
    then
        emerge --unmerge gentoo-sources  2>&1 | tee -a log
        rm -rf /usr/src/linux/*               | tee -a log
        rm -rf /var/cache/distfiles/*
    else
        eclean -d packages 2>&1 | tee -a log
    fi

    # kernel sources will have to be reinstalled by user if necessary

    emerge --depclean 2>&1 | tee -a log
    rm -rf /var/tmp/*
    rm /tmp/*

    # Final steps: cleaning up

    if [ "${DEBUG_MODE}" = "false" ]
    then
        rm -rf /var/log/*
        find . -maxdepth 1 -type f -delete
    fi

    [ -n "$(which eix-update)" ] && eix-update

    cat /dev/zero > zeros ; sync ; rm zeros
}

# Normally a non-op
source .bashrc

# without pipefail, piping to tee would mask failures
set -o pipefail

declare -i res=0
adjust_environment
[ $? = 0 ] || res=1
build_kernel
[ $? = 0 ] || res=$((res | 2))
install_software
[ $? = 0 ] || res=$((res | 4))
global_config
[ $? = 0 ] || res=$((res | 8))
finalize
[ $? = 0 ] || res=$((res | 16))
echo "[MSG] Virtual Gentoo build exited with code: ${res}" 2>&1 | tee -a log
exit ${res}

# note: return code will be 0 if all went smoothly
# otherwise:
# odd number: Issue with adjust_environment
# code & 2 == 1:
# Issue with build_kernel
# code & 4 == 1:
# Issue with install_software
# code & 8 == 1:
# Issue with global_config
# code & 16 == 1: Issue with finalize
