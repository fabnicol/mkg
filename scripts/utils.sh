#!/bin/bash

##
# Copyright (c) 2020 Fabrice Nicol <fabrnicol@gmail.com>
#
# This file is part of mkg.
#
# mkg is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# mkg is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with FFmpeg; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301
##

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

## @var ARR
## @brief global string array of switches and default values
## @details Structure is as follows: @code
## {{"Commandline option", "Description", "Default value", "Type"}, {...},...}
## @endcode
## 'Type' is among the following values:
## @li @b b  Boolean, 'false' or 'true'
## @li @b d  An existing directory
## @li @b e  Email address: regexp "[a-z]+@[a-z]+\.[a-z]+"
## @li @b f  An existing file
## @li @b n  Numeric value
## @li @b o  'on' or 'off', a VBoxManage custom Boolean
## @li @b s  Non-empty string. Corresponding defaults may be empty however.
##           This is the notably case for passwords. For such options, explicit
##           commandline value after '=' is requested.
## @li @b u  Url
## @li @b x:y Conditional type x: one of the above, with [ -z "$x" ]
##            <=> { [ "$y" = "false" ] ||  [ -z "$y" ]; } && [ "$y" != "true" ]
## @li @b vm Restricted to the <tt>vm</tt> option:
##           can be set to @ code <tt>false</tt> to bypass OS building and only
##           perform burning/external device operations.
## A double-entry array will be simulated using indexes.
## @ingroup createInstaller
## @note `debug_mode` should be place up front in the array

declare -a ARR

## @var ARRAY_LENGTH
## @brief Number of switches (true length of array divided by 4)
## @ingroup createInstaller

declare -i ARRAY_LENGTH

create_options_array() {

    # language note: IFS is the bash array separator, not awk's

    IFS=';'
    read -r -a A <<< $(awk -F"\"" \
    '/^\s*$/ {next;}  {if ( ! match($1, "#"))  printf "%s;%s;%s;%s;",$2,$4,$6,$8}' \
       "$1")
    ARR=(${A[@]})
    ARRAY_LENGTH=$((${#ARR[*]}/4))
    export ARR
    export ARRAY_LENGTH
    unset A
    IFS=" "
}

## @fn test_numeric()
## @brief Test whether the input value is numeric
## @param number in string form
## @return grep value against input string
## @ingroup auxiliaryFunctions

test_numeric() {
  grep -q -E "^[+-]?[0-9]+([.][0-9]+)?$" <<< "$1"
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

## @fn send_mail()
## @brief Send an email to $EMAIL at $SMTP_URL to warn about end of processing.
## @warning Email password is entered in clear using $EMAIL_PASSWD which is not
##          safe if mkg is run on any other platform than the user's own.
##          Use with care in a private context.
## @return Return value of `curl' command.
## @ingroup auxiliaryFunctions

send_mail() {

    curl --url ${SMTP_URL} \
         --ssl-reqd \
         --mail-from ${EMAIL} \
         --mail-rcpt ${EMAIL} \
         --user ${EMAIL}:${EMAIL_PASSWD} -T \
         <(echo -e  "From: ${EMAIL}\nTo: ${EMAIL}\nSubject: ${VM} now ready!\n\
\n${VM} finished building at " $(date -Im))
}

## @fn list_block_devices()
## @brief List all non-loop block devices
## @note uses @code lsblk
## @ingroup auxiliaryFunctions

list_block_devices() {
    echo  "$(lsblk -a -n -o KNAME | grep -v loop | xargs)"
}

## @fn find_device_by_vendor()
## @brief Finds the device label sdX associated to a given vendor
## @note uses @code lsblk
## @ingroup auxiliaryFunctions

find_device_by_vendor() {

    echo "$(lsblk -a -n -o KNAME,VENDOR \
| grep -v loop | grep -i $1 | cut -f1 -d' ')"

}

## @fn is_block_device()
## @brief Test if argument is non-loop block device
## @param label  Label of potential block device (e.g. \b sdc) to be
##               tested.
## @retval Return 0 (true) if input is a block device otherwise 1.
## @ingroup auxiliaryFunctions

is_block_device() {
    local devices="$(list_block_devices)"
    grep -q "$1" <<< "${devices}"
    return $?
}

## @fn get_mountpoint()
## @param dev block device
## @brief Gives mount directory of block device, if any.
## @retval Path string. On error exit value is 1.
## @ingroup auxiliaryFunctions

get_mountpoint() {
    if ! is_block_device "$1"
    then
        logger -s "[ERR] $1  is not a block device!"
        logger -s "[MSG] Device labels should be in the following list:"
        logger -s "[MSG] $(list_block_devices)"
        exit 1
    fi
    local res=$(findmnt --raw -a -n -c /dev/"$1" \
                    | grep -v nodev | cut -f1 -d' ')
    echo "${res}"
}

## @fn get_device()
## @param Either a device KNAME (sdX), or a directory mountpoint
##        or enough letters of the VENDOR for grep to uniquely
##        identify it in @code lsblk ouput.
## @brief Give device from mount folder input.
## @ingroup auxiliaryFunctions

get_device() {
    if is_block_device "$1"
    then
        echo "$1"
    else
        local res
        if [ -d "$1" ]
        then
            res=$(findmnt --raw --first -a -n -c "$1" | cut -f2 -d' ')
            res=$(sed -r 's/\/dev\/([a-zA-Z]+)[0-9]+/\1/' <<< "${res}")
            echo "${res}"
        else
            res=$(find_device_by_vendor "$1")
            if [ -n "${res}" ]
            then
                if "${INTERACTIVE}"
                then
                    read -p "[WAR] Please confirm there is no error and you \
wish to create an installer with device /dev/${res}, vendor name $1. \
Reply with uppercase Y to continue: " reply
                    if [ "${reply}" = "Y" ]
                    then
                        get_device "${res}"
                    else
                        exit 0
                    fi
                else
                    get_device "${res}"
                fi
            else
                ${LOG[*]} "[ERR] $1 is neither a mountpoint nor a \
block device"
                exit 1
            fi
        fi
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
## @retval 0 on success otherwise -1 on failure.
## @ingroup auxiliaryFunctions

test_cdrecord() {
    ${LOG[*]} "[MSG] cdrecord scanbus test."
    if ! "${CDRECORD}" -scanbus >/dev/null 2>&1
    then
        ${LOG[*]} "[ERR] cdrecord version is not functional"
        ${LOG[*]} "[MSG] Try reinstalling cdrecord"
        exit 1
    fi
    return 0
}

## @fn recreate_liveCD_ISO()
## @brief Create ISO of liveCD out of directory
## @param dir Directory containing all files
## @return 0 on success or exits -1 on failure.
## @note An alternative xorriso solution could be considered
## @ingroup auxiliaryFunctions

recreate_liveCD_ISO() {

    check_tool "mkisofs"
    check_files "${ISO}"\
                "$1${ISOLINUX_DIR}/isolinux.bin" \
                "$1${ISOLINUX_DIR}/boot.cat"
    sleep 5
    check_dir "$1${ISOLINUX_DIR}"
#    if  "${DEBUG_MODE}"
#    then
#    fi

    if "${VERBOSE}"
    then
        mkisofs -v -J -R -o  "${ISO}" \
                -b ${ISOLINUX_DIR}/isolinux.bin \
                -c ${ISOLINUX_DIR}/boot.cat -no-emul-boot \
                -boot-load-size 4 \
                -boot-info-table "$1"
    else
        mkisofs -J -R -o  "${ISO}" \
                -b ${ISOLINUX_DIR}/isolinux.bin \
                -c ${ISOLINUX_DIR}/boot.cat -no-emul-boot \
                -boot-load-size 4 \
                -boot-info-table "$1" 2>/dev/null 1>/dev/null
    fi

# mkisofs almost never fails but if it does, hard stop here.

 if_fails $?  "[ERR] mkisofs could not recreate the ISO file to \
boot virtual machine ${VM} from directory $1"
}

## @fn burn_iso()
## @brief Burn Gentoo clonezilla installer to DVD using \b cdrecord
## @note \b cdrecord should have been installed beforehand
## @retval Return \b cdrecord return code
## @ingroup auxiliaryFunctions

burn_iso() {
    if [ -z "${CDRECORD}" ]
    then
        if ! which cdrecord
        then
             ${LOG[*]} "[ERR] Could not find cdrecord"
             ${LOG[*]} "[ERR] Please install cdrtools in your PATH or \
 specify cdrecord full filepath on commandline:"
             ${LOG[*]} "      burn=true \
cdrecord=/path/to/cdrecord/executable"
             exit 1
         else
             CDRECORD="$(which cdrecord)"
             test_cdrecord
         fi
    else
         test_cdrecord
    fi

    "${BLANK}" && BLANK='blank=fast' || BLANK=""

    if [ -z "${SCSI_ADDRESS}" ] || [ "${SCSI_ADDRESS}" = "dep" ]
    then
        OPT=("-eject" "${BLANK}")
    else
        OPT=("-eject" "${BLANK}" "dev=${SCSI_ADDRESS}")
    fi

    if [ ! -f "${ISO_OUTPUT}" ]
    then
        ${LOG[*]} "[ERR] No such files as ${ISO_OUTPUT}"
        exit 1
    fi
    ${LOG[*]} "[INF] Burning installation medium ${ISO_OUTPUT} \
to optical disc..."
    "${VERBOSE}" && ${LOG[*]} "[MSG] ${CDRECORD} ${OPT[*]} ${ISO_OUTPUT}"

    # do not quote OPT

    ${CDRECORD} ${OPT[*]} "${ISO_OUTPUT}"
    if_fails $? "[ERR] Could not burn ${ISO_OUTPUT}"
}

## @fn create_install_ext_device()
## @brief Create USB-stick (or any external device) Gentoo clonezilla
##        installer
## @warning Use with care, check your EXT_DEVICE variable.
## @retval  Return value of `sync`exit code
## @ingroup auxiliaryFunctions

create_install_ext_device() {
    res=0
    # Test whether EXT_DEVICE is a mountpoint or a block device label

    EXT_DEVICE=$(get_device ${EXT_DEVICE})

    if [ -z "${EXT_DEVICE}" ]
    then
        ${LOG[*]} "[ERR] ext_device=... must be specified."
        exit 1
    fi

    check_file "${ISO_OUTPUT}" "[ERR] Iso output \"${ISO_OUTPUT}\" was not found."
    is_block_device "/dev/${EXT_DEVICE}"
    ${LOG[*]} "[INF] Creating install device under \
/dev/${EXT_DEVICE}"
    dd if="${ISO_OUTPUT}" of="/dev/${EXT_DEVICE}" bs=4M status=progress && sync
    if_fails $? "[ERR] Could not install device ${EXT_DEVICE}"
}

## @fn check_dir()
## @brief   Checks existence of directories.
## @param   dirs Successive paths (relative or absolute) to directories.
## @warning Paths should be separated by spaces and quoted.
## @retval  Undefined or exit 2 if string is not a directory path
## @ingroup auxiliaryFunctions

check_dir() {
    while [ -n "$1" ]
    do
        if  ! [ -d "$1" ]
        then
            ${LOG[*]} "[ERR] Directory *$1* not found"
            exit 2
        fi
        shift
    done
}

## @fn check_file()
## @brief   Checks existence of file.
## @param   filepath Relative or absolute path to file to be checked
##          for existence.
## @param   msgs  Successive message strings to be echoed if file not found.
## @warning Paths should be separated by spaces and quoted.
## @retval  Undefined or exit 3 if string is not a file path
## @ingroup auxiliaryFunctions

check_file() {
    if ! [ -f "$1" ]
    then
        shift
        until [ -z "$1" ]
        do
            ${LOG[*]} "$1"
            shift
        done
        exit 3
    fi
}

## @fn check_files()
## @brief   Checks existence of files.
## @param   files Successive paths (relative or absolute) to files.
## @warning Paths should be separated by spaces and quoted.
## @retval  Undefined or exit 3 if any string is not a file path
## @ingroup auxiliaryFunctions

check_files() {
    while [ -n "$1" ]
    do
        if ! [ -f "$1" ]
        then
            ${LOG[*]} "[ERR] File *$1* not found"
            exit 3
        fi
        shift

    done
}

## @fn check_tool()
## @brief   Checks existence of auxiliary tools.
## @param   dirs Successive paths (relative or absolute) to helper binaries.
## @warning Paths should be separated by spaces and quoted.
## @retval  Undefined or exit 1 if binary not found.
## @ingroup auxiliaryFunctions

check_tool() {
    while [ -n "$1" ]
    do
        if ! which "$1" >/dev/null 2>&1
        then
            ${LOG[*]} "[ERR] You should first install $1, \
which is used by this program."
            exit 1;
        fi
        shift
    done
}

## @fn if_fails()
## @brief   Echoes a message and exit in case of previous command failure.
## @param   ret Return value of command to be tested.
## @param   msg ... Message(s) to be echoed inc case of a failure.
## @note    Command success is presumed to be identified by $? == 0.
## @retval  Undefined or exit 1 if $? != 0.
## @ingroup auxiliaryFunctions

if_fails() {
    if [ $1 != 0 ]
    then
        while [ -n "$2" ]
        do
            ${LOG[*]} "$2"
            shift
        done
        exit 1
    fi
}

## @fn cleanup()
## @brief Clean up all temporary files and directpries (except for VirtualBox
##        build)
## @details Needs @code CLEANUP=true @endcode.
##          If @code FULL_CLEANUP=true@endcode
##          then erase ISO files with names containing @b clonezilla, @b install
##          or @b downloaded names.
## @ingroup auxiliaryFunctions

cleanup() {

    ! "${CLEANUP}" && return 0
    local verb=""
    ${VERBOSE} && verb="-v"
    cd "${VMPATH}" || exit 2
    [ -d ISOFILES ] && chmod -R +w ISOFILES
    rm ${verb} -rf ISOFILES/ mnt2/
    [ -d mnt ]  && mountpoint mnt && umount -l mnt/
    [ -d mnt ]  && rm ${verb} -rf mnt
    [ -d mnt2 ] && rm ${verb} -rf mnt2
    [ -d "${VM}" ] && rm ${verb} -rf "${VM}"
    [ -d "${VM}_ISO" ] && rm ${verb} -rf "${VM}_ISO"
    if "${FULL_CLEANUP}"
    then
	[ -f "${VM}.vdi" ] && rm ${verb} -f "${VM}.vdi"
        rm ${verb} -f *.xz
        rm ${verb} -f *.txt
        rm ${verb} -f "${CLONEZILLACD}" "${CACHED_ISO} *clonezilla*iso *install*iso"
    fi
    return 0
}


## @fn bind_filesystem()
## @brief Bind-mounts the host live filesystem (proc/sys/dev/run) to a
##        future chrooted OS-like tree of similar nature.
## @param root Root directory of the subordinate filesystem.
## @ingroup auxiliaryFunctions

bind_filesystem() {

    # prepare chroot in clonezilla filesystem

    mount --types proc /proc "$1"/proc
    res0=$?
    mount --rbind /sys  "$1"/sys
    res1=$?
    mount --make-rslave "$1"/sys
    res2=$?
    mount --rbind /dev  "$1"/dev
    res3=$?
    mount --make-rslave "$1"/dev
    res4=$?
    local res=$((${res0} | ${res1} | ${res2} | ${res3} | ${res4}))
    if_fails ${res} "[ERR] Could not bind-mount $1"
}

unbind_filesystem() {

    # undo bind_filesystem
    if ! [ -d "$1" ]
    then
        return 0
    fi

    ${LOG[*]} "[INF] Unmounting host filesystem"
    if mountpoint -q "$1"/dev > /dev/null 2>&1
    then
        umount -l "$1"/dev{/shm,/pts,}
    fi
    if mountpoint -q "$1"/run > /dev/null 2>&1
    then
        umount "$1"/run
    fi
    if mountpoint -q "$1"/proc
    then
        mount --make-rslave "$1"/proc
        umount -l "$1"/proc
    fi
    if mountpoint -q "$1"/sys
    then
        mount --make-rslave "$1"/sys
        umount -l "$1"/sys
    fi
    if mountpoint -q "$1"
    then
        umount -R -l  "$1"
    fi
}

checksums() {

    if [ -f "${VMPATH}/${LIVECD}" ]
    then
        echo "[MSG] Workflow created file ${LIVECD}."
        echo "      with following checksums:"
        echo "      md5sum: $(md5sum ${LIVECD})"       | tee checksums.txt
        echo "      sha1sum: $(sha1sum ${LIVECD})"     | tee -a checksums.txt
        echo "      sha256sum: $(sha256sum ${LIVECD})" | tee -a checksums.txt
    else
        echo "[ERR] Workflow failed to create file ${VMPATH}/${LIVECD}."
    fi
}

need_root() {
    if [ "$(whoami)" != "root" ]
    then
        ${LOG[*]} "[ERR] must be root to continue."
        exit 1
    fi
}
