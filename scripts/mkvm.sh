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

## @fn setup_network()
## @brief Call net-setup and dhcpcd to enable networking
## @details Create file \b setup_network on success for debugging purposes
## @retval Otherwise exit -1 on failure
## @ingroup mkFileSystem

setup_network() {
    if test -f setup_network; then
        return
    fi
    if test "${VMTYPE}" = "gui"; then
        net-setup
        sleep 40
    else
        eth=$(ifconfig | cut -f1 -d' ' | line | cut -f1 -d':')
        echo "eth=${eth}"
        sleep 10
        dhcpcd ${eth}
        sleep 40
    fi
    if test $? = 0; then
        touch setup_network
    else
        echo "Could not fix internet access!" | tee setup_network.log
        sleep 10
        if test "${VMTYPE}" = "gui"; then
            exit -1
        else

            # A stricter measure for headless VMs to avoid waiting for 2 days uselessly

            shutdown -h now
        fi

    fi
}


## @fn partition()
## @brief Create partition table, \b /dev/sda1 (bios_grub), \b /dev/sda2 (boot), \b dev/sda3 (swap) and \b /dev/sda4 (system)
## @details Create file \b partition. @n
##  On error, fill this file with successive exit codes of commands and exit.@n
##  On success, just create empty file.
## @warning The VM needs time to recognize /dev/sda in some cases, for unclear reasons.
## This may be a kernel issue or a VirtualBox issue.
## @bug  Same issue with mkswap and swapon. Syncing and a bit of sleep fixed these issues.
## @note It might be necessary with older machines to increase the amount of sleep.
## @ingroup mkFileSystem

partition() {
    if test -f partition; then
        return
    fi
    parted --script --align=opt /dev/sda "mklabel gpt unit mib mkpart primary 1 3 name 1 grub set 1 bios_grub on mkpart primary 3 131  name 2 boot mkpart primary 131 643 name 3 swap mkpart primary 643 -1 set 2 boot on"
    res0=$?

    # This may look unnatural, but it has occurred quite a few times, with /dev/sdaX "still mounted"
    # thereby thwarting filesystem authoring. This insane beavior has been circumvented by syncing,
    # testing for mount and umounting should the case arise. This has even occurred with the swap partition.
    sync
    sleep 20
    mkfs.fat -v -F 32 /dev/sda2
    res1=$?
    sync
    mkfs.ext4 -e continue -q -F -F /dev/sda4
    res2=$?
    sync
    declare -i index=0
    while ! mkswap /dev/sda3; do
        index=index+1
        if (( index < 10 )); then
            continue
        else
            break
        fi
    done
    res3=$?
    sync
    index=0
    while ! swapon /dev/sda3; do
        index=index+1
        if (( index < 10 )); then
            continue
        else
            break
        fi
    done
    res4=$?
    sync
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
        echo "Failed to cleanly partition main disk"
        sleep 10
        if test $((${res1} | ${res2} | ${res3} | ${res4} | ${res5})) != 0; then
            echo  "Critical errors whicle partitioning"
            if test "${VMTYPE}" = "gui"; then
                exit -1
            else

                # A stricter measure for headless VMs to avoid waiting for 2 days uselessly

                shutdown -h now
            fi
        else
            echo "Parted issue but mkfs and mount OK. Going on..."
            return -1
        fi
    fi
}

## @fn install_stage3()
## @details @li Copy stage3 archive, ebuild list, kernel config and mkvm_chroot.sh to /mnt/gentoo
## @li Extract it, fix basic make.conf options
## @li Install repos.conf from liveCD (networking parameters)
## @li Mount liveCD proc/sys/dev files into new filesystem
## @li On failure, print error codes into file \b partition
## @li On success, create empty file \b partition
## @li <tt> chroot </tt> into new system
## @ingroup mkFileSystem

install_stage3() {
    if test -f stage3; then
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
        sleep 10
        if test "${VMTYPE}" = "gui"; then
            exit -1
        else

            # A stricter measure for headless VMs to avoid waiting for 2 days uselessly

            shutdown -h now
        fi
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
        touch stage3
    else
        echo "mounting proc exit code: ${res0}"    > stage3
        echo "mounting sys exit code: ${res1}"     >> stage3
        echo "rslave sys exit code: ${res2}"       >> stage3
        echo "mounting dev dev exit code: ${res3}" >> stage3
        echo "rslave dev exit code exit code: ${res4}"    >> stage3
        echo "Failed to bind liveCD to main disk"
        sleep 10
        if test "${VMTYPE}" = "gui"; then
            exit -1
        else

            # A stricter measure for headless VMs to avoid waiting for 2 days uselessly

            shutdown -h now
        fi
    fi
    cd ~
    chroot /mnt/gentoo /bin/bash mkvm_chroot.sh
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
    chown -R ${NONROOT_USER}:${NONROOT_USER} /home/${NONROOT_USER}
    shutdown -h now
}

# Logging will only subsist as long as the liveCD is not shut down
# Logs are provided for debugging purposes

setup_network  2>&1 | tee setup_network.log
partition      2>&1 | tee partition.log
install_stage3 2>&1 | tee install_stage3.log
finalize       2>&1 | tee finalize.log
