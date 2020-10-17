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
# mkgentoo is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with FFmpeg; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301
##
#!/bin/bash

## @file utils.sh
## @author Fabrice Nicol <fabrnicol@gmail.com>
## @copyright GPL v.3
## @brief Auxiliary functions
## @note This file is not included into the clonezilla ISO liveCD.
## @defgroup auxiliaryFunctions Auxiliary functions to check
##           lines, files, devices and burn disk.

## @fn create_options_array()
## @brief Read file @b options into a temporary array A
##        which will contain command line specifications
## @details Later on A initializes the read-only array #ARR
## @ingroup auxiliaryFunctions

create_options_array() {
    IFS=';'
    read -r -a A <<< $(awk -F"\"" \
     '{if ( ! match($1, "#")  && $1 != "") printf "%s;%s;%s;%s;",$2,$4,$6,$8}' \
       options)
    export A
}

## @fn check_md5sum()
## @param filename Local name of file to be checked for md5sum.
## @brief Check md5sums in file MD5SUMS
## @retval Return 0 on success otherwise -1 on exit
## @ingroup auxiliaryFunctions

check_md5sum() {
    local ref=$(cat MD5SUMS | grep "$1" | cut -f 1 -d' ')
    downloaded=$(md5sum $1 | cut -f 1 -d' ')
    [ ${downloaded} = ${ref} ] && return 0
    logger -s "[ERR] MD5 checkum for $1 is not correct. \
Please download manually..."
    exit -1
}

## @fn test_numeric()
## @brief Test whether the input value is numeric
## @param number in string form
## @return grep value against input string
## @ingroup auxiliaryFunctions

test_numeric() {
  grep -E "^[+-]?[0-9]+([.][0-9]+)?$" <<< "$1"
}

## @fn test_URL()
## @brief Test whether the input value is a valid URL
## @param Internet URL
## @return grep value against input string
## @ingroup auxiliaryFunctions

test_URL() {
    grep -E \
         "(\w+:\/\/)[-a-zA-Z0-9:@;?&=\/%\+\.\*!\(\),\$_\{\}\^~\[\]|]+"\
         <<< "$1"
}

## @fn test_email()
## @brief Test whether the input value is a valid email address
## @param Email address
## @return grep value against input string
## @ingroup auxiliaryFunctions

test_email() {
    grep -E "[a-z]+@[a-z]+\.[a-z]+" <<< "$1"
}

## @fn list_block_devices()
## @brief List all non-loop block devices
## @ingroup auxiliaryFunctions

list_block_devices() {
    echo  "$(lsblk -a -n -o KNAME | grep -v loop)"
}

## @fn is_block_device()
## @brief Test if argument is non-loop block device
## @param label  Label of potential block device (e.g. \b sdc) to be
##               tested.
## @retval Return 0 (true) if input is a block device otherwise 1.
## @ingroup auxiliaryFunctions

is_block_device() {
    local devices="$(list_block_devices)"
    grep -q "$1" <<< ${devices}
    return $?
}

## @fn get_mountpoint()
## @brief Gives mount folder from device label input
## @ingroup auxiliaryFunctions

get_mountpoint() {
    if is_block_device "$1"
    then
        logger -s "[ERR] $1  is not a block device!"
        logger -s "[MSG] Device labels should be in the following \
list:"
        logger -s $(list_block_devices)
        exit -1
    fi
    echo $(findmnt --raw --first -a -n -c "$1" | cut -f1 -d' ')
}

## @fn get_device()
## @brief Give device from mount folder input
## @ingroup auxiliaryFunctions

get_device() {
    if [ -d "$1" ]
    then
        device=$(findmnt --raw --first -a -n -c "$1" | cut -f2 -d' ')
        echo ${device}
    else
        is_block_device "$1" && echo "$1" \
            || { logger -s "[ERR] $1 is neither a mountpoint nor a \
block device"; exit -1; }
    fi
}

## @fn test_cdrecord()
## @brief Test whether \b cdrecord is functional
## @details Try to scan the SCSI bus and exit on error
## @warning There may be a rights issue with versions of \b cdrecord
## built from original source as they sometimes request elevated
## rights to perform burning with some hardware configurations. @n
## In such an event, either run script with elevated rights or
## modify \b cdrecord rights using: @code
## chown root cdrecord && chgrp bin cdrecord && chmod 04755 cdrecord
## @endcode
## @retval 0 on success otherwise exits -1 on failure.
## @ingroup auxiliaryFunctions

test_cdrecord() {
    logger -s "[MSG] cdrecord scanbus: "
    ${CDRECORD} -scanbus
    [ $? != 0 ] \
        && { logger -s "[ERR] cdrecord version is not functional"
        logger -s "[MSG] Try reinstalling cdrecord"
        exit -1; }
    return 0
}

## @fn recreate_liveCD_ISO()
## @brief Create ISO of liveCD out of directory
## @param dir Directory containing all files
## @return 0 on success or exits -1 on failure.
## @note An alternative xorriso solution could be considered

recreate_liveCD_ISO() {

    "${VERBOSE}" \
         &&  mkisofs -v -J -R -o  "${ISO}" \
            -b ${ISOLINUX_DIR}/isolinux.bin \
            -c ${ISOLINUX_DIR}/boot.cat -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table "$1" \
         ||  mkisofs -J -R -o  "${ISO}" \
                         -b ${ISOLINUX_DIR}/isolinux.bin \
                         -c ${ISOLINUX_DIR}/boot.cat -no-emul-boot \
                         -boot-load-size 4 \
                         -boot-info-table "$1" 2>/dev/null 1>/dev/null

# mkisofs almost never fails but if it does, hard stop here.

    [ $? != 0 ] && {
        logger -s "[ERR] mkisofs could not recreate the ISO file to \
boot virtual machine ${VM} from directory $1"
        exit -1; }
}

## @fn burn_iso()
## @brief Burn Gentoo clonezilla installer to DVD using \b cdrecord
## @note \b cdrecord should have been installed beforehand
## @retval Return \b cdrecord return code
## @ingroup auxiliaryFunctions

burn_iso() {
    if [ -z "${CDRECORD}" ]
    then
        if $(which cdrecord)
        then
             logger -s "[ERR] Could not find cdrecord"
             logger -s "[ERR] Please install cdrtools in your PATH or \
 specify cdrecord full filepath on commandline:"
             logger -s "      burn=true \
cdrecord=/path/to/cdrecord/executable"
             return -1
         else
             CDRECORD=$(which cdrecord)
             test_cdrecord
         fi
    else
         test_cdrecord
    fi
    logger -s "[INF] Burning installation medium to optical disc..."
    [ -z "${SCSI_ADDRESS}" ] && ${CDRECORD} -eject  "${ISO_OUTPUT}" \
        || ${CDRECORD} -eject dev=${SCSI_ADDRESS} "${ISO_OUTPUT}"
}

## @fn create_install_usb_device()
## @brief Create USB-stick (or any external device) Gentoo clonezilla
##        installer
## @warning Use with care, check your USB_DEVICE variable.
## @ingroup createInstaller

create_install_usb_device() {
    res=0
    logger -s "[INF] Creating inetall device under /dev/${DEVICE_INSTALLER}"
    dd if="${ISO_OUTPUT}" of="/dev/${DEVICE_INSTALLER}" bs=4M status=progress
    res=$?
    sync
}
