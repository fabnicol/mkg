#!/bin/bash

# *
# * Copyright (c) 2020 Fabrice Nicol <fabrnicol@gmail.com>
# *
# * This file is part of mkg.
# *
# * mkg is free software; you can redistribute it and/or
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

## @fn setup_network()
## @brief Call net-setup and dhcpcd to enable networking
## @details Create file \b setup_network on success for debugging purposes
## @retval Otherwise exit 1 on failure
## @ingroup mkFileSystem

setup_network() {

    [ -f setup_network ] && return
    local res=0
    if "${GUI}"
    then
       if  "${CLONEZILLA_INSTALL}"
       then
           echo "[INF] Running ocs-live-netcfg..." | tee setup_network.log
           ocs-live-netcfg
       else
           echo "[INF] Running net-setup..." | tee -a setup_network.log
           net-setup
       fi
    else
        if "${CLONEZILLA_INSTALL}"
        then
            dhclient
        else

            # Workaround a VirtualBox bug, you need a keyboard input here of
            # some sort.  This is why we wait some time in mkgentoo.sh

            read -p "[MSG] Waiting for keyboard input..."  input_str
            echo "[MSG] Got input string: $input_str" | tee -a setup_network.log
            echo "[INF] Running dhcpcd..."            | tee -a setup_network.log
            dhcpcd -HD $(ifconfig | cut -d' ' -f1   | head -n 1 | cut -d':' -f1)
        fi
    fi
    res=$?
    [ ${res} = 0 ] && touch setup_network || {
        echo  "[ERR] Could not fix internet access!" | tee -a setup_network.log
        "${GUI}" && exit 1 || shutdown -h now
    }
}

## @fn partition()
## @brief Create partition table, \b /dev/sda1 (bios_grub), \b /dev/sda2 (boot),
##        \b dev/sda3 (swap) and \b /dev/sda4 (system)
## @details Create file \b partition. @n
##  On error, fill this file with successive exit codes of commands and exit.@n
##  On success, just create empty file.
## @warning The VM needs time to recognize /dev/sda in some cases, for unclear
##          reasons.
## This may be a kernel issue or a VirtualBox issue.
## @bug  Same issue with mkswap and swapon. Cleaning VBox config/settings,
## syncing and a bit of sleep fixed these issues for the \e net-setup method.
## @bug However if vm type is \e 'headless' the \e dhcpcd method is consistently
## hampered by a VBox bug, which is tentatively circumvented
## by sending a `controlvm keyboardputscancode 1c` instruction.
## Tests show that this is linked to a requested user keyboard or mouse input by
## the Gentoo minimal install CD. This cannot be simulated
## owing to the lack of /dev/uinput. The reason why user input is requested has
## not been found. Without it, /dev/sda2 and/or sda4 are
## mistakenly identified as being mounted and/or busy, while this cannot be the
## case. With even a single keystroke for a `read`command, all
## falls back into place. This is why using the net-setup script, which forces
## user input, circumvents the issue.
## This may be caused by an aging kernel and/or incompatibilities with
## virtualization.
## Using a CloneZilla CD as a replacement solved the issue completely.
## It might be better to use a beefed-up Gentoo install CD.
## @note It might be necessary with older machines to increase the amount of
## sleep.
## @ingroup mkFileSystem

partition() {

    [ -f partition ] && [ ! -s partition ] && return 0
    sleep 5
    parted --script \
           --align=opt \
           /dev/sda \
           "mklabel gpt \
           unit mib \
           mkpart primary 1 3 \
           name 1 grub \
           set 1 bios_grub on \
           mkpart primary 3 131\
           name 2 boot \
           mkpart primary 131 643 \
           name 3 swap \
           mkpart primary 643 -1 \
           set 2 boot on"
    res0=$?
    sync
    sleep 10
    mkfs.fat -v -F 32 /dev/sda2
    res1=$?
    sync
    sleep 10
    mkfs.ext4 -e continue -q -F -F /dev/sda4
    res2=$?
    swapoff -a
    sync
    sleep 10
    mkswap /dev/sda3
    res3=$?
    sync
    swapon /dev/sda3
    res4=$?
    sync
    findmnt /dev/sda4 &&  umount -l /dev/sda4
    mount  /dev/sda4 /mnt/gentoo
    res5=$?
    res=$((${res0} | ${res1} | ${res2} | ${res3} | ${res4} | ${res5}))
    if [ ${res} = 0 ]
    then
        touch partition
        echo "[MSG] Partioned /dev/sda4 correctly."
    else
        echo "[ERR] parted exit code: ${res0}"    | tee partition.log
        echo "[ERR] mkfs.fat exit code: ${res1}"  | tee -a partition.log
        echo "[ERR] mkfs.ext4 exit code: ${res2}" | tee -a partition.log
        echo "[ERR] mkswap exit code: ${res3}"    | tee -a partition.log
        echo "[ERR] swapon exit code: ${res4}"    | tee -a partition.log
        echo "[ERR] mount exit code:  ${res5}"    | tee -a partition.log
        echo "[ERR] Failed to cleanly partition main disk" | tee -a partition.log
        sleep 10
        if [ $((${res1} | ${res2} | ${res3} | ${res5})) != 0 ]
        then
            echo  "[ERR] Critical errors while partitioning" | tee -a partition.log
            swapoff -a
            findmnt /dev/sda4 && umount -l /dev/sda4
            if "${GUI}"
            then
                return 1
            else
                echo "[ERR] Shutting down in 5 seconds..."
                sleep 5
                shutdown -h now
            fi
        else
            echo "[WAR] Parted issue but mkfs and mount OK. Going on..." \
                 | tee partition.log
            return 1
        fi
    fi
}

## @fn install_stage3()
## @details @li Copy stage3 archive, ebuild list, kernel config and
##              mkvm_chroot.sh to /mnt/gentoo
## @li Extract it, fix basic make.conf options
## @li Install repos.conf from liveCD (networking parameters)
## @li Mount liveCD proc/sys/dev files into new filesystem
## @li On failure, print error codes into file \b partition
## @li On success, create empty file \b partition
## @li <tt> chroot </tt> into new system
## @ingroup mkFileSystem

install_stage3() {

    [ -f stage3 ] && return 0
    echo "[INF] Installing stage 3..." | tee stage3.log
    # move or copy system files to target OS

    ! [ -d /mnt/gentoo ] && mkdir -p /mnt/gentoo

    mv -vf "${STAGE3}" \
       "${ELIST}" \
       "${ELIST}.accept_keywords" \
       "${ELIST}.use" \
       mkvm_chroot.sh \
       "${KERNEL_CONFIG}"  /mnt/gentoo/
    cp -vf .bashrc /mnt/gentoo/bashrc_temp

    # cd to target OS and extract stage3 archive

    cd /mnt/gentoo

    if [ $? != 0 ]
    then
        echo "[ERR] Could not cd to /mnt/gentoo"   | tee -a stage3.log
        echo "[ERR] Shutting down in 5 seconds..." | tee -a stage3.log
        sleep 5
        shutdown -h now
    fi

    head -n -1 -q bashrc_temp > temp_bashrc && rm bashrc_temp
    tar xpJf ${STAGE3} --xattrs-include='*.*' --numeric-owner

    if [ $? != 0 ]
    then
        echo "[ERR] stage3 tarball could not be extracted" | tee -a stage3.log
        sleep 10
        swapoff /dev/sda3
        findmnt /dev/sda4 && umount -l /dev/sda4
        "${GUI}" && exit 1 || shutdown -h now
    fi
    cat temp_bashrc >> .bashrc
    rm temp_bashrc
    rm -vf ${STAGE3}

    # Ajusting portage

    local m_conf="etc/portage/make.conf"
    sed  -i "s/COMMON_FLAGS=.*/COMMON_FLAGS=\"${CFLAGS} -pipe\"/g"  ${m_conf}
    echo MAKEOPTS=-j${NCPUS}  >> ${m_conf}
    echo "L10N=\"${LANGUAGE} en\""    >> ${m_conf}
    echo "LINGUAS=\"${LANGUAGE} en\"" >> ${m_conf}
    sed  -i 's/USE=".*"//g'    ${m_conf}
    echo 'USE="gtk gtk2 gtk3 gnome -qt4 -qt5 -kde dvd alsa cdr bindist networkmanager \
elogind -consolekit -systemd mpi dbus X"' >>  ${m_conf}
    echo "GENTOO_MIRRORS=\"${EMIRRORS}\""  >> ${m_conf}

    # note linux-fw-redistributable no-source-code for genkernel
    # note bh-luxi for font-bh-* requested by xorg-x11

    echo 'ACCEPT_LICENSE="-* @FREE linux-fw-redistributable no-source-code \
bh-luxi"' >> ${m_conf}
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
    if [ ${res} = 0 ]
    then
        touch stage3
        echo "[MSG] Installed stage3 correctly."    | tee -a stage3.log
    else
        echo "mounting proc exit code: ${res0}"     | tee -a stage3.log
        echo "mounting sys exit code: ${res1}"      | tee -a stage3.log
        echo "rslave sys exit code: ${res2}"        | tee -a stage3.log
        echo "mounting dev dev exit code: ${res3}"     | tee -a stage3.log
        echo "rslave dev exit code exit code: ${res4}" | tee -a stage3.log
        echo "Failed to bind liveCD to main disk"  | tee -a stage3.log
        sleep 10
        swapoff /dev/sda3
        findmnt /dev/sda4 && umount -l /dev/sda4
        if "${GUI}"
        then
            exit 1
        else
            echo "[INF] Shutting down in 5 seconds..."
            sleep 5
            shutdown -h now
        fi
    fi

    cd ~
    if [ $? != 0 ]
    then
        echo "[ERR] Could not cd to $HOME" | tee -a stage3.log
        exit 2
    fi

    chroot /mnt/gentoo /bin/bash mkvm_chroot.sh

    if [ $? != 0 ]
    then
        echo "[ERR] Could not chroot to /mnt/gentoo" | tee -a stage3.log
        echo "[INF] Shutting down in 5 seconds" | tee -a stage3.log
        sleep 5
        exit 2
    fi
}

## @fn finalize()
## @brief Unmount chrooted system, restore user rights and shutdown VM
## @ingroup mkFileSystem

finalize() {

    umount -l /mnt/gentoo/dev{/shm,/pts,}
    umount /mnt/gentoo/run
    umount /mnt/gentoo/proc
    umount /mnt/gentoo/sys
    umount -R -l  /mnt/gentoo
    umount -l /dev/sda4
    fsck -AR -y
    echo "[INF] Shutting down in 5 seconds..."
    sleep 5
    shutdown -h now
}

# Logging will only subsist as long as the liveCD is not shut down
# Logs are provided for debugging purposes

setup_network  2>&1 | tee setup_network.log
if ! partition
then
    echo "[WAR] Second try at partitioning..." | tee -a partion.log
    findmnt /dev/sda2 && umount -l /dev/sda2
    findmnt /dev/sda4 && umount -l /dev/sda4
    swapoff -a
    partition
fi
install_stage3 2>&1 | tee -a stage3.log
finalize       2>&1 | tee finalize.log
