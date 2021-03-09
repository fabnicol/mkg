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
    echo "Partition /dev/sda2 with ${uuid2}" | tee partition_log
    echo "Partition /dev/sda3 with ${uuid3}" | tee -a partition_log
    echo "Partition /dev/sda4 with ${uuid4}" | tee -a partition_log
    echo "${uuid2} /boot           vfat defaults            0 2" \
         >  /etc/fstab
    echo "${uuid3} none            swap sw                  0 0" \
         >> /etc/fstab
    echo "${uuid4} /               ext4 defaults            0 1" \
         >> /etc/fstab
    echo "/dev/cdrom /mnt/cdrom  auto noauto,user,discard 0 0"   \
         >> /etc/fstab

    source /etc/profile

    # Refresh and rebuild @world frequently emerge complains about
    # having to be upgraded before anything else.  We shall use
    # emerge-webrsync as emerge --sync is a bit less robust (rsync
    # rotation bans...)

    emerge-webrsync
    ! emerge -1 sys-apps/portage \
        && { echo "[ERR] emerge-webrsync failed!" | tee emerge.build
        return 1; }

    # select profile (most recent plasma desktop)

    local profile=$(eselect --color=no --brief profile list \
                        | grep desktop \
                        | grep gnome \
                        | grep ${PROCESSOR} \
                        | grep -v systemd \
                        | head -n 1)

    eselect profile set ${profile}

    # Use and keywords (mkdir -p to neutralize error msg)

    mkdir -p /etc/portage/package.accept_keywords
    mkdir -p /etc/portage/package.use
    cp -vf "${ELIST}.accept_keywords" \
       /etc/portage/package.accept_keywords/ \
        | tee emerge.build

    cp -vf "${ELIST}.use"             /etc/portage/package.use/ \
        |  tee emerge.build

    cp -vf "${ELIST}.accept_keywords" \
       /etc/portage/package.accept_keywords/ \
        |  tee emerge.build

    # One needs to build cmake without the qt5 USE value first,
    # otherwise dependencies cannot be resolved.

    USE='-qt5' emerge -1 cmake
    if [ $? != 0 ]
    then
        echo "emerge cmake failed!" | tee -a emerge.build
        return 1
    fi

    # add logger. However it will not be usable for now,
    # this is why we are using custom logs and tee's.

    emerge -uD app-admin/sysklogd
    rc-update add sysklogd default
    rc-service sysklogd start

    # other core sysapps to be merged first. LZ4 is a kernel
    # dependency for newer linux kernels.

    emerge -u net/misc/wget
    emerge -u app-arch/lz4 net-misc/netifrc sys-apps/pcmciautils

    if [ $? != 0 ]
    then
       echo "[ERR] emerge netifrs/pcmiautils failed!" | tee -a emerge.build
       return 1
    fi

    # Now on to updating @world set. Be patient and wait for about
    # 15-24 hours
    # as syslogd is not yet there we tee a custom build log

    emerge -uDN @world 2>&1 | tee -a emerge.build
    [ $? != 0 ] && {
        echo "[ERR] emerge @world failed!"  | tee -a emerge.build
        return 1; }

    # Networking in the new environment

    echo hostname=${NONROOT_USER}pc > /etc/conf.d/hostname
    cd /etc/init.d || exit 2
    ln -s net.lo net.${iface}
    cd - || exit 2
    rc-update add net.${iface} default

    # Set keymaps and time

    if [ -n "${VM_LANGUAGE}" ]
    then
        echo "keymap=${VM_LANGUAGE}" >  /etc/conf.d/keymaps
        echo 'keymap="us"' >> /etc/conf.d/keymaps
    else
        echo 'keymap="us"' >  /etc/conf.d/keymaps
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
## @li Emerge \b gentoo-sources, \b genkernel, \b pciutils and
##     \b linux-firmware
## @li Mount /dev/sda2 to /boot/
## @li Build kernel and initramfs. Log into kernel.log.
## @retval  -1 on error.
## @ingroup mkFileSystem

build_kernel() {

    # Building the kernel

    emerge gentoo-sources sys-kernel/genkernel pciutils \
        | tee kernel.log

    # Now mount the new boot partition

    mount /dev/sda2 /boot
    cp -vf .config /usr/src/linux
    cd /usr/src/linux

    if [ "$PWD" != "/usr/src/linux" ]
    then
        echo "[ERR] Could not cd to /usr/src/linux" | tee -a kernel.log
        exit 2
    fi

    # kernel config issue here

    make syncconfig  # replaces silentoldconfig as of 4.19
    make -s -j${NCPUS}   2>&1 | tee -a  kernel.log
    make modules_install 2>&1 | tee -a  kernel.log
    make install         2>&1 | tee -a  kernel.log
    if  [ $? != 0 ]
    then
        echo "[ERR] Kernel building failed!" | tee -a kernel.log
        return 1
    fi

    genkernel --install initramfs
    emerge sys-kernel/linux-firmware
    make clean

    if [ -f /boot/vmlinuz* ]
    then
        echo "[MSG] Kernel was built" | tee -a kernel.log
    else
        echo "[ERR] Kernel compilation failed!"  | tee -a  kernel.log
        return 1
    fi

    if [ -f /boot/initr*.img ]
    then
        echo "[MSG] initramfs was built" | tee -a  kernel.log
    else
        echo "[ERR] initramfs compilation failed!" | tee -a  kernel.log
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
    emerge -u dos2unix  | tee log_install_software.log
    chown root ${ELIST}
    chmod +rw ${ELIST}
    dos2unix ${ELIST}

    local packages=`grep -E -v '(^\s*$|^\s*#.*$)' ${ELIST} \
| sed "s/dev-lang\/R-.*$/dev-lang\/R-${R_VERSION}/"`

    # Trace for debugging

    echo "${packages}" > package_list

    # There is an intractable circular dependency that
    # can be broken by pre-emerging python

    USE="-sqlite -bluetooth" emerge -1 dev-lang/python

    # v1.3: adding --keep-going. Limited emerge failures may not render
    # the build useless.
    # allow some tolerance for incomplete builds caused
    # by changes in portage tree package names and versions.

    # do not quote `packages' variable!

    emerge -uDN --keep-going ${packages}  2>&1 \
    | tee -a log_install_software.log
    local res_install=$?

    if [ "${res_install}" != "0" ]
    then
	# one more chance, who knows
	emerge --resume | tee -a log_install_software.log
    res_install=$?
        res_install=$?
    fi

    if [ $? != 0 ]
    then
	# one more chance, who knows
	emerge --resume | tee -a log_install_software.log
    fi

    # do not use \ to continue line below:

    if ! "${MINIMAL}"
    then
       Rscript libs.R 2>&1 | tee Rlibs.log
       rm -f libs.R
       echo "install.packages(c('data.table', 'dplyr', 'ggplot2',
'bit64', 'devtools', 'rmarkdown'), repos=\"${CRAN_REPOS}\")" \
> libs.R
    fi

    # update environment

    env-update
    source /etc/profile

    if [ "${res_install}" != "0" ]
    then
        echo "[ERR] Main package build step failed" \
            | tee -a log_install_software.log
        return 1
    fi
}

## @fn global_config()
## @details @li Cleanup log, distfiles (for deployment),
##          kernel build sources and objects
## @li Log this into \b log_uninstall_software
## @li Update \b eix cache. Sets displaymanager for \b xdm.
## @li Add services: <b>sysklog, cronie, xdm, dbus, elogind</b>
## @li Substitute \b NetworkManager to temporary networking setup.
## @li Adjust group and \b sudo settings for non-root user and \b sddm
## @li Install \b grub in EFI mode.
## @li Set passwords for root and non-root user.
## @warning Fix \b sddm startup keyboard issue using
##          <tt> setxkbmap</tt>
## @ingroup mkFileSystem

global_config() {

    # Configuration --- sddm

    echo "#!/bin/sh"               > /usr/share/sddm/scripts/Xsetup \
        | tee -a sddm.log
    echo "setxkbmap ${VM_LANGUAGE},us" > /usr/share/sddm/scripts/Xsetup \
        | tee -a sddm.log
    chmod +x /usr/share/sddm/scripts/Xsetup
    sed -i 's/DISPLAYMANAGER=".*"/DISPLAYMANAGER="sddm"/' \
        /etc/conf.d/xdm

    gpasswd -a sddm video

    #--- Services

    rc-update add cronie default
    rc-update add xdm default
    rc-update add dbus default
    rc-update add elogind boot

    #--- Networkmanager

    for x in /etc/runlevels/default/net.*
    do
        rc-update del $(basename $x) default
        rc-service --ifstarted $(basename $x) stop
    done
    rc-update del dhcpcd default
    rc-update add NetworkManager default

    #--- groups and sudo

    useradd -m -G users,wheel,audio,video,plugdev \
            -s /bin/bash "${NONROOT_USER}"

    if [ $? != 0 ]
    then
        echo "[ERR] Could not useradd root" | tee useradd.log
    fi

    echo "${NONROOT_USER}     ALL=(ALL:ALL) ALL" >> /etc/sudoers

    # normally a non-op (useradd -m), just for paranoia

    chown -R ${NONROOT_USER}:${NONROOT_USER} /home/${NONROOT_USER}

    if ! which grub-mkconfig
    then
        echo "[ERR] Did not find grub!" | tee grub.log
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
        echo "[ERR] Could not install grub" | tee -a grub.log
        exit 1
    fi

    grub-mkconfig -o /boot/grub/grub.cfg

    if [ $? != 0 ]
    then
        echo "[ERR] Could not configure grub" | tee -a grub.log
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
        | tee log_uninstall.log

    # MINIMAL_SIZE should only be set for packaging purposes.
    # and avoided for personal use

    if "${MINIMAL_SIZE}"
    then
        emerge --unmerge gentoo-sources  2>&1 | tee -a log_uninstall.log
        rm -rf /usr/src/linux/*               | tee -a log_uninstall.log
        rm -rf /var/cache/distfiles/*
    else
        eclean -d packages 2>&1 | tee -a log_uninstall.log
    fi

    # kernel sources will have to be reinstalled by user if necessary

    emerge --depclean 2>&1 | tee -a log_uninstall.log
    rm -rf /var/tmp/*
    rm /tmp/*

    # Final steps: cleaning up

    if ! "${DEBUG_MODE}"
    then
        rm -rf /var/log/*
        find . -maxdepth 1 -type f -delete
    fi

    [ -n "$(which eix-update)" ] && eix-update

    # prepare to compact with vbox-img comp act --filename
    # ${VMPATH}/${VM}.vdi

    cat /dev/zero > zeros ; sync ; rm zeros
}

# Normally a non-op
source .bashrc

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
echo "[MSG] Exiting with code: ${res}" 2>&1 | tee res.log
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
