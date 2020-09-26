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


## setup_network
##
## Call net-setup and dhcpcd to enable networking
## Create file \b setup_network on success for debugging purposes
## Otherwise exit
## @fn
setup_network() {
    if test -f setup_network; then
        return
    fi
    local   eth=$(ifconfig | cut -f1 -d' ' | line | cut -f1 -d':')
    net-setup  $eth #enp0s3
    dhcpcd -HD $eth #enp0s3
    if test $? = 0; then
        touch setup_network
    else
        exit -1
    fi
}

## partition
##
## Create partition table, \b /dev/sda1 (bios_grub), \b /dev/sda2 (boot), \b dev/sda3 (swap) and \b /dev/sda4 (system)
## Create file \b partition.
## On error, fill this file with successive exit codes of commands and exit.
## On success, just create empty file.
## @fn
partition() {
    if test -f partition; then
        return
    fi
    parted --script --align=opt /dev/sda "mklabel gpt unit mib mkpart primary 1 3 name 1 grub set 1 bios_grub on mkpart primary 3 131  name 2 boot mkpart primary 131 643 name 3 swap mkpart primary 643 -1 set 2 boot on"
    res0=$?
    mkfs.fat -F 32 /dev/sda2
    res1=$?
    mkfs.ext4 /dev/sda4
    res2=$?
    mkswap /dev/sda3
    res3=$?
    swapon /dev/sda3
    res4=$?
    mount  /dev/sda4 /mnt/gentoo
    res5=$?
    res=$((${res0} | ${res1} | ${res2} | ${res3} | ${res4} | ${res5}))
    if test ${res} = 0; then
        touch partition
    else
        echo "parted exit code: ${res0}"    > partition
        echo "mkfs.fat exit code: ${res1}"  >> partition
        echo "mkfs.ext4 exit code: ${res2}" >> partition
        echo "mkswap exit code: ${res3}"    >> partition
        echo "swapon exit code: ${res4}"    >> partition
        echo "mount exit code:  ${res5}"    >> partition
        exit -1
    fi
}

## install_stage3
##
## Copy stage3 archive, ebuild list, kernel config and mkvm_chroot.sh to /mnt/gentoo
## Extract it, fix basic make.conf options
## Install repos.conf from liveCD (networking parameters)
## Mount liveCD proc/sys/dev files into new filesystem
## On failure, print error codes into file \b partition
## On success, create empty file \b partition
## \code chroot \endcode into new system
## @fn
install_stage3 {
    if test -f install_stage3; then
        return
    fi
    mv -vf ${STAGE3} ${ELIST}  mkvm_chroot.sh ${KERNEL_CONFIG} /mnt/gentoo/
    cp -vf .bashrc /mnt/gentoo/bashrc_temp
    cd /mnt/gentoo
    head -n -1 -q bashrc_temp > temp_bashrc && rm bashrc_temp

    # Time

    ntpd -q -g
    tar xpJf ${STAGE3} --xattrs-include='*.*' --numeric-owner
    if test $? != 0; then
        echo "stage3 tarball could not be extracted"
        exit -1
    fi
    cat temp_bashrc >> .bashrc
    rm temp_bashrc
    rm -vf ${STAGE3}

    # Ajusting portage

    local m_conf="etc/portage/make.conf"
    sed  -i "s/COMMON_FLAGS=.*/COMMON_FLAGS='${CFLAGS} -pipe'/g"  ${m_conf}
    echo MAKEOPTS=-j${NCPUS}  >> ${m_conf}
    echo 'L10N="fr en"'    >> ${m_conf}
    echo 'LINGUAS="fr en"' >> ${m_conf}
    sed  -i 's/USE=".*"//g'    ${m_conf}
    echo 'USE="-gtk -gnome qt4 qt5 kde dvd alsa cdr bindist networkmanager elogind -consolekit -systemd dbus X"' >>  ${m_conf}
    echo "GENTOO_MIRRORS=${EMIRRORS}"  >> ${m_conf}

    # note linux-fw-redistributable no-source-code for genkernel
    # note bh-luxi for font-bh-* requested by xorg-x11

    echo 'ACCEPT_LICENSE="-* @FREE linux-fw-redistributable no-source-code bh-luxi"' >> ${m_conf}
    echo 'GRUB_PLATFORMS="efi-64"' >> ${m_conf}
    echo 'VIDEO_CARDS="nouveau intel"'   >> ${m_conf}
    echo 'INPUT_DEVICES="evdev synaptics"' >> ${m_conf}
    mkdir --parents etc/portage/repos.conf
    cp usr/share/portage/config/repos.conf etc/portage/repos.conf/gentoo.conf
    cp --dereference /etc/resolv.conf etc/

    # Chrooting the new environment

    mount --types proc /proc proc
    res0=$?
    mount --rbind /sys  sys
    res1=$?
    mount --make-rslave sys
    res2=$?
    mount --rbind /dev  dev
    res3=$?
    mount --make-rslave dev
    res4=$?
    res=$((${res0} | ${res1} | ${res2} | ${res3} | ${res4}))
    if test ${res} = 0; then
        touch partition
    else
        echo "parted exit code: ${res0}"    > partition
        echo "mkfs.fat exit code: ${res1}"  >> partition
        echo "mkfs.ext4 exit code: ${res2}" >> partition
        echo "mkswap exit code: ${res3}"    >> partition
        echo "swapon exit code: ${res4}"    >> partition
        exit -1
    fi
    cd ~
    chroot /mnt/gentoo ./mkvm_chroot.sh
}

## finalize
##
## Unmount chrooted system, restore user rights and shutdown VM
## @fn
finalize() {
    umount -l /mnt/gentoo/dev{/shm,/pts,}
    umount /mnt/gentoo/run
    umount /mnt/gentoo/proc
    umount /mnt/gentoo/sys
    umount -R -l  /mnt/gentoo
    chown -R fab:fab /home/fab
    shutdown -h now
}

# Logging will only subsist as long as the liveCD is not shut down
# Logs are provided for debugging purposes

setup_network  | tee setup_network
partition      | tee partition
install_stage3 | tee install_stage3
finalize       | tee finalize
