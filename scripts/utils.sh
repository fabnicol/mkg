##
# Copyright (c) 2020 Fabrice Nicol <fabrnicol@gmail.com>
#
# This file is part of mkgentoo.
#
# mkgentoo is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# FFmpeg is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with FFmpeg; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
##
#!/bin/bash

## @file utils.sh
## @author Fabrice Nicol <fabrnicol@gmail.com>
## @copyright GPL v.3
## @brief Auxiliary functions
## @note This file is not included into the clonezilla ISO liveCD.
## @defgroup auxiliaryFunctions Auxiliary functions to check files, devices and burn disk.

## @fn check_md5sum()
## @param filename Local name of file to be checked for md5sum.
## @brief Check md5sums in file MD5SUMS
## @retval Return 0 on success otherwise -1 on exit
## @ingroup auxiliaryFunctions

check_md5sum() {
    local ref=$(cat MD5SUMS | grep "$1" | cut -f 1 -d' ')
    downloaded=$(md5sum $1 | cut -f 1 -d' ')
    if test ${downloaded} = ${ref}; then
        return 0
    else
        echo "MD5 checkum for $1 is not correct. Please download manually..."
        exit -1
    fi
}

## @fn list_block_devices()
## @brief List all non-loop block devices
## @ingroup auxiliaryFunctions

list_block_devices() {
    echo  "$(lsblk -a -n -o KNAME | grep -v loop)"
}

## @fn is_block_device()
## @brief Test if argument is non-loop block device
## @param label  Label of potential block device (e.g. \b sdc) to be tested.
## @retval Return 0 (true) if input is a block device otherwise 1.
## @ingroup auxiliaryFunctions

is_block_device() {
    local devices=$(list_block_devices)
    grep -q "$1" <<< "${devices}" && return 0
    return 1
}

## @fn get_mountpoint()
## @brief Gives mount folder from device label input
## @ingroup auxiliaryFunctions

get_mountpoint() {
    if is_block_device "$1"; then
        echo "$1  is not a block device!"
        echo "Device labels should be in the following list:"
        echo $(list_block_devices)
        exit -1
    fi
    echo "$(findmnt --raw --first -a -n -c "$1" | cut -f1 -d' ')"
}

## @fn get_device()
## @brief Give device from mount folder input
## @ingroup auxiliaryFunctions

get_device() {
    if test -d "$1"; then
        device=$(findmnt --raw --first -a -n -c $1 | cut -f2 -d' ')
    else
        if is_block_device "$1"; then
            echo "$1"
        else
            echo "$1 is neither a mountpoint nor a block device"
            exit -1
        fi
    fi
    echo ${device}
}

## @fn test_cdrecord()
## @brief Test whether \b cdrecord is functional
## @details Try to scan the SCSI bus and exit on error
## @warning There may be a rights issue with versions of \b cdrecord
## built from original source as they sometimes request elevated
## rights to perform burning with some hardware configurations. @n
## In such an event, either run script with elevated rights or
## modify \b cdrecord rights using: @code
## chown root cdrecord && chgrp bin cdrecord && chmod 04755 cdrecord @endcode
## @retval 0 on success otherwise exits -1 on failure.
## @ingroup auxiliaryFunctions

test_cdrecord() {
    echo "cdrecord scanbus: "
    ${CDRECORD} -scanbus
    if test $? != 0; then
        echo "cdrecord version is not functional"
        echo "Try reinstalling cdrecord"
        exit -1
    fi
    return 0
}

## @fn burn_iso()
## @brief Burn Gentoo clonezilla installer to DVD using \b cdrecord
## @note \b cdrecord should have been installed beforehand
## @retval Return \b cdrecord return code
## @ingroup auxiliaryFunctions

burn_iso() {
    if test "${CDRECORD}" = ""; then
         if $(which cdrecord); then
             echo "Could not find cdrecord"
             echo "Please install cdrtools in your PATH or specify cdrecord full filepath on commandline:"
             echo "burn=true cdrecord=/path/to/cdrecord/executable"
             return -1
         else
             CDRECORD=$(which cdrecord)
             test_cdrecord
         fi
    else
         test_cdrecord
    fi
    echo "Burning installation medium to optical disc..."
    if test "${SCSI_ADDRESS}" = ""; then
       ${CDRECORD} -eject  "${ISO_OUTPUT}"
    else
       ${CDRECORD} -eject dev=${SCSI_ADDRESS} "${ISO_OUTPUT}"
    fi
}

## @fn create_install_usb_device()
## @brief Create USB-stick (or any external device) Gentoo clonezilla installer
## @warning Use with care, check your USB_DEVICE variable.
## @ingroup createInstaller

create_install_usb_device() {
    res=0
    echo "Creating installation stick..."
    dd if="${ISO_OUTPUT}" of=/dev/${USB_DEVICE} bs=4M status=progress
    res=$?
    sync
    res=$? | res
    return ${res}
}
