#!/bi/bash

##
# Copyright (c) 2020-2021 Fabrice Nicol <fabrnicol@gmail.com>
#
# This file is part of mkg.
#
# mkg is free software; you can redistribute it and/or
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301
##

# ------------------------------------------------------------------ #
# etags note
# ----------
#
# Owing to a bug in the Emacs etags program
# Use instead "Exuberant ctags" with option -e to create file TAGS
#
# ------------------------------------------------------------------ #

## @mainpage Usage
## @brief In a nutshell
## @n
## @code ./mkg [command=argument] ... [command=argument]  [file.iso]
## @endcode
## @n
## @details
## See
## <a href="https://github.com/fabnicol/gentoo-creator/wiki">
## <b>Wiki</b></a> for details.
## @n
## @author Fabrice Nicol 2020
## @copyright This software is licensed under the terms of the
## <a href="https://www.gnu.org/licenses/gpl-3.0.en.html">
## <b>GPL v3</b></a>

## @file mkgentoo.sh
## @author Fabrice Nicol <fabrnicol@gmail.com>
## @copyright GPL v.3
## @brief Process options, create Gentoo VirtualBox machine and optionally
##        create clonezilla install medium
## @note This file is not included into the clonezilla ISO liveCD.
## @par USAGE
## @code
## mkg  [[switch=argument]...]  filename.iso  [1]
## mkg  [[switch=argument]...]                [2]
## mkg  help[=md]                             [3]
## @endcode
## @par
## Usage [1] creates a bootable ISO output file with a current Gentoo
## distribution.   @n
## Usage [2] creates a VirtualBox VDI dynamic disk and a virtual machine with
## name Gentoo.   @n
## Usage [3] prints this help, in markdown form if argument 'md' is specified.
## @n
## @par
## Run: @code mkg help @endcode to print a list of possible switches and
## arguments.
## @warning you should have at least 55 GB of free disk space in the current
## directory or in vmpath
## if specified.
## Boolean values are either 'true' or 'false'. An option no followed by '='
## is equivalent to @b option=true, except for help and a possible ISO file.
## For example, to build a minimal:
## distribution,specify <tt>minimal</tt> or <tt> minimal=true</tt>
## on command line.
## @par \b Examples:
## @li Only create the VM and virtual disk, in debug mode,
## without R and set new passwords, for a French-language platform.
## Use 8 cores.
## @code mkg vm_language=fr_FR minimal debug_mode ncpus=8
## nonroot_user=ken passwd='util!Hx&32F' rootpasswd='Hk_32!_CD' cleanup=false
## @endcode
## @li Create ISO clonezilla image of Gentoo linux, burn it to DVD, create an
## installed OS
## on a USB stick whose model label starts with \e PNY and finally create a
## clonezilla installer
## on another USB stick mounted under <tt> /media/ken/AA45E </tt>
## @code mkgento burn hot_install ext_device="PNY" device_installer
## ext_device="Sams" my_gentoo_image.iso
## @endcode
## @defgroup createInstaller Create Gentoo linux image and installer.

# ---------------------------------------------------------------------------- #
# Global declarations
#

## @var ISO
## @brief Name of downloaded clonezilla ISO file
## @ingroup createInstaller

declare -x ISO="downloaded.iso"

## @var CREATE_ISO
## @brief Custom name of ISO output. Default value is false
##        Can be reversed by a name of type filename.iso on command line,
##        previously created and reused to burn or dd to device installer.
## @ingroup createInstaller

declare -x CREATE_ISO=false

## @var VBOX_VERSION
## @brief Version of VirtualBox
## @ingroup createInstaller

declare -r VBOX_VERSION="$(VBoxManage -v)"

declare -i -x VERSION_MAJOR=$(sed -E 's/([0-9]+)\..*/\1/' \
                               <<< ${VBOX_VERSION})
declare -i -x VERSION_MINOR=$(sed -E 's/[0-9]+\.([0-9]+)\..*/\1/' \
                               <<< ${VBOX_VERSION})
declare -i -x VERSION_INDEX=$(sed -E 's/[0-9]+\.[0-9]+\.([0-9][0-9]).*/\1/'\
                               <<< ${VBOX_VERSION})

# ---------------------------------------------------------------------------- #
# Helper functions
#

## @fn help_md()
## @brief Print usage in markdown format
## @note white space at end of echoes is there for markdown in post-processing
## @ingroup createInstaller

help_md() {

local count=$(($(nproc --all)/3))
echo "**USAGE:**  "
echo "**mkg**                                        [1]  "
echo "**mkg**  [[switch=argument]...]  filename.iso  [2]  "
echo "**mkg**  [[switch=argument]...]                [3]  "
echo "**mkg**  help[=md]                             [4]  "
echo "  "
echo "Usage [1] and [2] create a bootable ISO output file with a current  "
echo "Gentoo distribution.  "
echo "For [1], implicit ISO output name is **gentoo.iso**  "
echo "Usage [3] creates a VirtualBox VDI dynamic disk and a virtual machine  "
echo "with name Gentoo.  "
echo "Usage [4] prints this help, in markdown form if argument 'md' is  "
echo "specified.  "
echo "Warning: you should have at least 55 GB of free disk space in the  "
echo "current directory or in vmpath if specified.  "
echo "  "
echo "Arguments with white space (like \`cflags=\"-O2 -march=...\"\`) \
should be  "
echo "written in list form with commas and no spaces, enclosed within single  "
echo "quotes: \`cflags=\'[-O2,-march=...]\'\`  "
echo "The same holds for paths with white space.  "
echo "  "
echo "As of March, 2021, part of the build is performed  "
echo "by *Github Actions* automatically. An ISO file of CloneZilla  "
echo "supplemented with VirtualBox guest additions will be downloaded  "
echo "from the resulting automated Github release. To disable this behavior  "
echo "you can add \`use_clonezilla_workflow=false\` to command line, or \
build the  "
echo "custom ISO file beforehand using the companion project  "
echo "**clonezilla_with_virtualbox**. In this case, add:  "
echo "\`custom_clonezilla=your_build.iso\`  "
echo "to command line.  "
echo "Within containers, \`use_clonezilla_workflow\`, \`build_virtualbox\`  "
echo "and \`test_emerge\` are not (yet) supported and will fail.  "
echo "A similar procedure also applies to the minimal Gentoo install ISO.  "
echo "MKG scripts and the stage3 archive are added within its squashfs \
filesystem  "
echo "by the *Github Actions* workflow of the MKG Github site.  "
echo "An ISO file labelled **downloaded.iso** is automatically released  "
echo "by the workflow. It will be downloaded from the MKG Github release \
section.  "
echo "This preprocessed ISO has build parameter presets. It builds the full \
desktop.  "
echo "In particular, the following command line options will be ignored:  "
echo "\`bios, cflags, clonezilla_install, debug_mode, elist, emirrors, \`  "
echo "\`kernel_config, mem, minimal, minimal_size, nonroot_user, passwd,\`  "
echo "\`processor, rootpasswd, stage3_tag, vm_keymap, vm_language.\`  "
echo "You can however use \`ncpus\` with values 1 to 6 included.  "
echo "Memory will be automatically allocated depending on \`ncpus\` value.  "
echo "To disable this behavior you can add \`use_mkg_workflow=false\`  "
echo "to command line. You will need to do so if you do not use OS build \
presets.  "
echo "  "
echo "**GUI mode and background runs**  "
echo "  "
echo "To run in the background, either add \`gui=false &\` to your command line  "
echo "or, if you want to keep a VirtualBox GUI and not run in headless mode,  "
echo "first launch in the foreground then use \`bg %n\` (where n is the  "
echo "corresponding shell job shown in the output of the \`jobs\` command).  "
echo "  "
echo "**Options:**  "
echo "  "
echo "Boolean values are either \`true\` or \`false\`. For example, to build  "
echo "a minimal distribution, add to command line:   "
echo "\`minimal=true\`   "
echo "or simply: \`minimal\` as \`true\` can be omitted (unlike \`false\`).  "
echo "      "
echo "**Examples**   "
echo "  "
echo "\`$ ./mkg pdfpage\`  "
echo "\`$ ./mkg debug_mode verbose from_vm vm=Gentoo  gentoo_small.iso\` \  "
echo "    \`ext_device=sdc device_installer blank burn cleanup=false\`   "
echo "\`# ./mkg download_arch=false download=false \
download_clonezilla=false\` \  "
echo "    \`custom_clonezilla=clonezilla_cached.iso use_mkg_workflow=false \
nonroot_user=phil\`  "
echo "\`# nohup ./mkg plot plot_color="'red'" plot_period=10 plot_pause=7\` \  "
echo "      \`compact minimal minimal_size=false use_mkg_workflow=false \
gui=false elist=myebuilds\` \  "
echo "        \`email=my.name@gmail.com email_passwd='mypasswd' &\`  "
echo "\`# nohup ./mkg gui=false from_device=sdc gentoo_backup.iso &\`  "
echo "\`# ./mkg dockerize minimal use_mkg_workflow=false ncpus=5 mem=10000 \
gentoo.iso\`  "
echo "  "
echo "  "
echo "**Type Conventions:**  "
echo "b: true/false Boolean  "
echo "o: on/off Boolean  "
echo "n: Integer  "
echo "f: Filepath  "
echo "d: Directory path  "
echo "e: Email address  "
echo "s: String  "
echo "u: URL  "
echo
echo "When a field depends on another, a colon separates the type and  "
echo "the name of the dependency."
echo "dep is a reserved word for dummy defaults of dependencies i.e.  "
echo "optional strings that may remain unspecified.  "
echo "Some options are incompatible, e.g. \`test_only\` \
and \`use_mkg_workflow\`  "
echo "   "
echo "   "
echo " | Option | Description | Default value | Type |  "
echo " |:------:|:------------|:-------------:|:----:|  "
declare -i i
for ((i=0; i<ARRAY_LENGTH; i++)); do
    declare -i sw=i*4       # no spaces!
    declare -i desc=i*4+1
    declare -i def=i*4+2
    declare -i type=i*4+3
    echo -e "| ${ARR[sw]} \t| ${ARR[desc]} \t| [ ${ARR[def]} ] | ${ARR[type]}|"
done
echo "  "
echo "  "
echo "**path1** https://sourceforge.net/projects/clonezilla/files/clonezilla_live_alternative_testing/20210505-hirsute/clonezilla-live-20210505-hirsute-amd64.iso/download  "
echo "**path2:**  http://gentoo.mirrors.ovh.net/gentoo-distfiles/  "
echo "**path3:**  https://github.com/fabnicol/clonezilla_with_virtualbox  "
echo "**path4:**  https://github.com/fabnicol/mkg/releases/download  "
echo "**count:** nproc --all / 3  "
}

## @fn help_()
## @brief Print usage to stdout
## @private
## @ingroup createInstaller

help_() {
    help_md | sed 's/[\*\|\>]//g' | grep -v -E "(Option *Desc.*|:--.*)"
}

## @fn manpage()
## @brief Print help to man page
## @ingroup createInstaller

manpage() {
    check_tool pandoc
    rm -f mkg.1
    help_md | pandoc -o mkg.1 && sed -i -E 's/(.PP|.PD$)/\1\n.br/' mkg.1
}

## @fn htmlpage()
## @brief Print help to html page.
## @ingroup createInstaller

htmlpage() {
    check_tool pandoc
    rm -f mkg.html
    help_md | pandoc -o mkg.html
}

## @fn pdfpage()
## @brief Print help to pdf page.
## @ingroup createInstaller

pdfpage() {
    check_tool pandoc
    rm mkg.pdf
    help_md | pandoc -V margin-right=0.75cm -V margin-left=0.75cm -o mkg.pdf
}

## @fn allpages()
## @brief Print man page, html page and pdf page.
## @ingroup createInstaller

allpages() {
    manpage
    htmlpage
    pdfpage
}

# ---------------------------------------------------------------------------- #
# Option parsing
#

## @fn validate_option()
## @brief Check if argument is part of array #ARR as a legitimate commandline
##        option.
## @param option  String of option.
## @return true if legitimate option otherwise false.
## @ingroup createInstaller

validate_option() {

    for ((i=0; i<ARRAY_LENGTH; i++))
    do
        [ "$1" = "${ARR[i*4]}" ] && return 0
    done
    return 1
}

## @fn get_options()
## @brief Parse command line
## @ingroup createInstaller

get_options() {

    local LOGGING="true"
    local LOGGER0="$(which logger)"
    local ECHO="$(which echo)"
    [ -n "${LOGGER0}" ] && LOGGER_VERBOSE_OPTION="-s" || LOGGER0="${ECHO}"
    LOG=("${LOGGER0}" "${LOGGER_VERBOSE_OPTION}")
    export LOG

    if [ $# = 0 ]
    then
        ISO_OUTPUT="gentoo.iso"
        CREATE_ISO=true
        return 0
    fi

    while (( "$#" ))
    do
        if grep -q '=' <<< "$1"
        then
            left=$(sed -E 's/([^=]*)=(.*)/\1/'  <<< "$1")
            right=$(sed -E 's/([^=]*)=(.*)$/\2/' <<< "$1")
            if validate_option "${left}"
            then
                declare -u VAR=${left}
                eval "${VAR}"=\"${right}\"
                if [ "${VERBOSE}" = "true" ]
                then
                    ${LOG[*]} "[CLI] Assign: ${VAR}=${!VAR}"
                fi
            else
                if ! grep -q "\.iso$"  <<< "$1"
                then
                  ${LOG[*]} "[ERR] Option $1 is not valid"
                  exit 5
                fi
            fi
        else
            if  grep -q "\.iso$"  <<< "$1"
            then
                ISO_OUTPUT="$1"
                  CREATE_ISO=true
            else
                if validate_option "$1"
                then
                    declare -u VAR="$1"
                    eval "${VAR}"=true
                    [ "${VERBOSE}" = "true" ] \
                        && ${LOG[*]} "[CLI] Assign: ${VAR}=true"
                else
                    ${LOG[*]} "[ERR] Option $1 is not valid"
                    exit 5
                fi
            fi
        fi
        if [ "${LOGGING}" = "true" ]
        then
            LOGGER="${LOGGER0}"
        else
            LOGGER="${ECHO}"
            LOGGER_VERBOSE_OPTION=""
        fi

        # fallback

        [ -z "${LOGGER}" ] && LOGGER="${ECHO}"
        if [ "${QUIET_MODE}" = "true" ]
        then
            LOGGER_VERBOSE_OPTION=""
        fi

        LOG=("${LOGGER}" "${LOGGER_VERBOSE_OPTION}")
        shift
    done
}

## @fn test_cli_pre()
## @brief Check VirtualBox version and prepare commandline analysis
## @retval 0 otherwise exit 1 if VirtualBox is too old
## @ingroup createInstaller

test_cli_pre() {

    if [ "${VERBOSE}" = "true" ] || [ "${DEBUG_MODE}" = "true" ]
    then
        if  [ "${QUIET_MODE}" = "true" ]
        then
            ${LOG[*]} "[ERR] You cannot have 'quiet' and verbose modes at \
the same time"
            exit 1
        fi
    fi

    # Configuration tests

    local do_exit=false

    # Check VirtualBox version
    if [ "${BUILD_VIRTUALBOX}" = "false" ]
    then

        if [ $? = 0 ]
        then
            [ "${VERBOSE}" = "true" ] \
                && ${LOG[*]} "[MSG] VirtualBox version: ${VBOX_VERSION}"

            if [ ${VERSION_MAJOR} -lt 6 ] || [ ${VERSION_MINOR} -lt 1 ] \
                   || [ ${VERSION_INDEX} -lt 10 ]
            then
                ${LOG[*]} "[ERR] VirtualBox must be at least version 6.1.10"
                ${LOG[*]} "[ERR] Please update and reinstall"
                do_exit=true
            else
                ${LOG[*]} "[MSG] Found adequate VirtualBox version."
            fi
        else
            # Balking out of version control.
            ${LOG[*]} "[ERR] Could not check VirtualBox version with user rights."
            ${LOG[*]} "[ERR] It is the user's responsability to check that \
VirtualBox version is at least 6.1.10."
            ${LOG[*]} "[WAR] This may be caused by the fact that you are \
not an active"
            ${LOG[*]} "      member of group vboxusers.\
Run 'sudo usermod -a -G vboxusers'"
            ${LOG[*]} "      then log out and log in again."
        fi
    fi

    #--- do_exit:

    [ "$do_exit" = "true" ] && exit 1

    #--- ISO output

    export CREATE_ISO

    if [ "${FROM_ISO}" = "true" ]
    then

        # effectively correcting first pass assignment.
        # This can be done only when cl is entirely parsed.

        CREATE_ISO="false"
    fi
    if [ -n "${ISO_OUTPUT}" ]
    then
        if [ "${VERBOSE}" = "true" ]
        then
            ${LOG[*]} "[MSG] Bootable ISO output is: ${ISO_OUTPUT}"
            if [ "${CREATE_ISO}"  = "true" ]
            then
                ${LOG[*]} "[MSG] Build Gentoo to bootable ISO"
            else
                ${LOG[*]} "[MSG] Using previously built ISO"
            fi
        fi
    fi

    [ -n "${VM}" ] && [ "${VM}" != "false" ] && [ "${FROM_VM}" != "true" ] \
        && ${LOG[*]} "[MSG] A Virtual machine will be created with name ${VM}"

    return 0
}

## @fn test_cli()
## @brief Analyse commandline
## @param cli  Commandline
## @details @li Create globals of the form VAR=arg  when there is var=arg on
##              commandline
## @li Otherwise assign default values VAR=defaults (3rd argument in array #ARR)
## @li Also checks type of argument against types described for #ARR
## @ingroup createInstaller

test_cli() {

    declare -i i=$1
    local sw=${ARR[i*4]}
    local desc=${ARR[i*4+1]}
    local default0="${ARR[i*4+2]}"
    eval default=\""${default0}"\"
    local type=${ARR[i*4+3]}
    local cli_arg=false
    declare -u V=${sw}
    local y=$(sed 's/.*://' <<< "${type}")
    local cond0="${y^^}"
    local cond
    [ -n "${cond0}" ] && cond="${!cond0}"

    # Do not use ${} directly as true/false without [...] in
    # this function and the above.
    # as Boolean variables may not all be set yet.

    if [ -n "${!V}" ]
    then
        [ "${DEBUG_MODE}" = "true" ] \
            && ${LOG[*]} "[CLI] ${desc}=${!V}"

        # checking on types among values found on commandline

        case "${type}" in
            b)  if  [ "${!V}" != "true" ] && [ "${!V}" != "false" ]
                then
                    ${LOG[*]} "[ERR] ${sw} is Boolean: specify its value as \
either 'false' or 'true' on command line"
                    exit 1
                fi
                ;;
            d)  [ ! -d "${!V}" ] \
                    && { ${LOG[*]} "[ERR] ${sw}=... must be an existing \
directory."
                         exit 1; }
                ;;
            e)  if ! grep -q -E "[a-z]+@[a-z]+\.[a-z]+" <<< "${!V}"
                then
                    ${LOG[*]} "[ERR] ${sw}=... must be a valid email \
address"
                    exit 1
                fi
                ;;
            f)  [ ! -f "${!V}" ] \
                    && { ${LOG[*]} "[ERR] ${sw}=... must be an existing file."
                         exit 1;} ;;
            n)  if ! test_numeric "${!V}"
                then
                    ${LOG[*]} "[ERR] ${sw}=... is not numeric."
                    exit 1
                fi
                ;;
            o)  [ "${!V}" != "on" ] && [ "${!V}" != "off" ] \
                    && { ${LOG[*]} "[ERR] ${sw}=on or ${sw}=off are the only \
 two possible values."
                         exit 1; }
                ;;
            u)  if ! test_URL "${!V}"
		then
                     ${LOG[*]} "[ERR] ${sw}=... must be a valid URL"
                     exit 1
		fi
                ;;
            vm)  [ "${VM}" = "false" ] && VM=""
                 ;;

            # conditional types of the form e/f/s:...

            *:*)
                if [ "${cond}" != "true" ] \
		&& { [ "${cond}" = "false" ] || [ -z "${cond}" ]; }
                then
                    if [ -z "${cond}" ]
                    then
                        ${LOG[*]} "[ERR] Execution cannot proceed without \
specifying an explicit value for ${y}=..."
                    else
                        ${LOG[*]} "[ERR] Execution cannot proceed as option \
values for ${y}=false and ${sw}=${!V} are incompatible."
                    fi
                    ${LOG[*]} "[ERR] Fatal. Exiting..."
                    exit 1
                fi

                # [ -z "${!V}" ] <=> { [ "${cond}" = "false" ]
                # ||  [ -z "${cond}" ]; } && [ "${cond}" != "true" ]

        esac
    else
        if [ "${cond}" = "true" ] || { [ "${cond}" != "false" ] \
                                           &&  [ -n "${cond}" ]; }
        then
            local EXCEPT="FROM_${y^^}"
            if [ -z "${default}" ] && ! "${!EXCEPT}"
            then
                ${LOG[*]} "[ERR] Execution cannot proceed without an explicit \
 value for ${sw}=... as ${y}=${cond}"
                ${LOG[*]} "[ERR] Fatal. Exiting..."
                exit 1
            fi
        fi

        # not found on command line or erroneously empty
        # replacing by default in any case, except if type == "s"
        # and default empty. This is the case e.g. for passwds.

        if [ "${type}" = "s" ] && [ -z "${default}" ] && [ "${sw}" != "dep" ]
        then
            ${LOG[*]} "[ERR] Execution cannot proceed without explicit value \
for ${sw}"
            if [ "${INTERACTIVE}" = "true" ]
            then
                local reply=""
                while [ -z ${reply} ]
                do
                    ${LOG[*]} "[MSG] Please enter value: "
                    read reply
                    eval "${V}"=\"${reply}\"
                done
            else
                ${LOG[*]} "[ERR] Fatal. Exiting..."
                exit 1
            fi
        fi
        [ "${DEBUG_MODE}" = "true" ] \
            && ${LOG[*]} "[CLI] Desc/default: ${desc}=${default}"
        eval "${V}"=\""${default}"\"
    fi

    # Post processing of arguments in list form [a,b...]

   if [ "${!V::2}" = "'[" ]
   then
       local w="${!V}"
       local V1="${w:2:(${#w}-4)}"
       V1=$(sed 's/,/ /g' <<< ${V1})
       eval "${V}"=\"${V1}\"
   fi

   [ "${DEBUG_MODE}" = "true" ] && ${LOG[*]} "[MSG] Export: ${V}=\"${!V}\""

   # exporting is made necessary by usage in companion scripts.

    export "${V}"
}

## @fn test_cli_post()
## @brief Check commanline coherence and incompatibilities
## @retval 0 or exit 1 on incompatibilities
## @ingroup createInstaller

test_cli_post() {

    local vbox_version="${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_INDEX}"

    if [ -n "${CHECK_VBOX_VERSION}" ] && [ "${CHECK_VBOX_VERSION}" != "dep" ]
    then
        if [ "${CHECK_VBOX_VERSION}" != "${vbox_version}" ]
        then
            ${LOG[*]} "[ERR] Host VirtualBox version is ${vbox_version}"
            ${LOG[*]} "      which is different from guest platform version \
${CHECK_VBOX_VERSION}"
            ${LOG[*]} "[ERR] Please install version ${CHECK_VBOX_VERSION} on host."
            ${LOG[*]} "[ERR] Exiting..."
            exit 1
        fi
    fi

    # use FORCE on mounting VM with qemu
    # just to avoid time stamps

  if "${EXITCODE}"
    then
        SHARE_ROOT="r"
        FORCE=true
        mkdir -p "${SHARE_ROOT}"
        INTERACTIVE=false
        FROM_VM=false
        FROM_ISO=false
        PLOT=false
        CREATE_ISO=false
        DOWNLOAD=false
        DOWNLOAD_CLONEZILLA=false
        DEVICE_INSTALLER=false
        EXT_DEVICE=""
        HOT_INSTALL=false
        POSTPONE_QEMU=false
    elif [ -n "${SHARE_ROOT}" ]
    then
        [ "${SHARE_ROOT}" != "dep" ] && FORCE=true
        ([ "${SHARE_ROOT}" = "r" ] || [ "${SHARE_ROOT}" = "w" ]) && NO_RUN=true
    fi

    if "${DOCKERIZE}" && "${EXITCODE}"
    then
        ${LOG[*]} "[ERR] Dockerized build is not supported \
with exitcode set on."
        exit 1
    fi

    # Tests existence of GNUPlot on system

    if "${PLOT}"
    then
        check_tool "gnuplot"
        GNUPLOT_BINARY="$(which gnuplot)"
        if [ -z "${GNUPLOT_BINARY}" ] || [ -z "`"${GNUPLOT_BINARY}" --version`" ]
        then
	    ${LOG[*]} "[ERR] Did not find gnuplot."
	    ${LOG[*]} "[ERR] Install gnuplot and run again, or run without 'plot'."
	    do_exit=true
        else
 	    DO_GNU_PLOT=true
	    [ "${PLOT_PAUSE}" -gt 50 ] && PLOT_PAUSE=50
	fi
    else
        DO_GNU_PLOT=false
    fi

    unset PLOT

    "${DOWNLOAD}" && ! "${CREATE_SQUASHFS}" \
        && { ${LOG[*]} "[ERR][CLI] You cannot set \
create_squashfs=false with download=true"
             exit 1; }

    if { "${FROM_ISO}" && "${FROM_DEVICE}"; } \
           || { "${FROM_VM}" && "${FROM_DEVICE}"; } \
           || { "${FROM_ISO}" && "${FROM_VM}"; }
    then
        ${LOG[*]} "[ERR] Only one of the three options from_iso, \
from_device or from_vm may be specified on commandline."
        exit 1
    fi

    # align debug_mode and verbose

    "${DEBUG_MODE}" && VERBOSE=true && CLEANUP=false

    # there are two modes of install: with CloneZilla live CD
    # (Ubuntu-based) or official Gentoo install

    "${CLONEZILLA_INSTALL}" && OSTYPE=Ubuntu_64 || OSTYPE=Gentoo_64

    if [ -n "${CUSTOM_CLONEZILLA}" ] && [ "${CUSTOM_CLONEZILLA}" != "dep" ]
    then
	    DOWNLOAD_CLONEZILLA=false
	    CLONEZILLACD="${CUSTOM_CLONEZILLA}"
    fi

    # minimal CPU allocation

    [ "${NCPUS}" = "0" ] && NCPUS=1

    # VM name will be time-stamped to avoid registration issues,
    # unless 'force=true' is used on commandline

    ! "${FORCE}" && ! "${FROM_VM}" && VM="${VM}".$(date +%F-%H-%M-%S)

    "${CREATE_ISO}" && ISOVM="${VM}".$(date +%F-%H-%M-%S)"_ISO"

    "${FROM_VM}" && [ ! -f "${VMPATH}/${VM}.vdi" ] \
        && { ${LOG[*]} "[ERR] Virtual machine \
disk ${VMPATH}/${VM}.vdi was not found"
             exit 1; }

    # ruling out incompatible options

    # You should always reply to security requests unless you want the process
    # in the background or not associated with a console.

    # Is STDOUT associated with a terminal?
    # This deals with nohup and redirection cases in relation to whether
    # we can ask user about deciding on options.

    if "${GUI}"
    then
        if "${INTERACTIVE}"
        then
           ! [ -t 1 ] && INTERACTIVE=false
        elif [ -t 1 ]
        then
            ${LOG[*]} "[WAR] Unless you want the process to run \
in the background or without a console, user interaction is allowed by default.\
Resetting *interactive* to *true*."
            INTERACTIVE=true
        fi
    else
        # forcing INTERACTIVE as false only for background jobs.

        case $(ps -o stat= -p $$) in
            *+*) echo "[MSG] Running in foreground with interactive=${INTERACTIVE}."
               ;;
            *) echo "[MSG] Running in background in non-interactive mode."
               INTERACTIVE=false
               ;;
        esac

        # or when not attached to console (nohup, redirection)
        ! [ -t 1 ] && INTERACTIVE=false
    fi

    if [ -n "${EMAIL}" ] && [ -z "${EMAIL_PASSWD}" ]
    then
        "${INTERACTIVE}" && read -p "[MSG] Enter email password: " EMAIL_PASSWD
        [ -z "${EMAIL_PASSWD}" ] \
            && ${LOG[*]} "[WAR] No email password, aborting sendmail."
        ${LOG[*]} "[INF] Sending warning email to ${EMAIL}"
        ${LOG[*]} "[WAR] Gmail and other providers request user to activate \
third-party applications for this mail to be sent."
        ${LOG[*]} "[WAR] You will not receive any mail otherwise."
    fi

    "${GUI}" && VMTYPE="gui" || VMTYPE="headless"
    "${BIOS}" && FIRMWARE="bios" || FIRMWARE="efi"

    # note: vm=false is now vm empty

    if [ -z "${VM}" ] && ! "${BUILD_VIRTUALBOX}"
    then
        CLEANUP=false
        ${LOG[*]} "[MSG] Deactivated cleanup"
    fi

    "${BUILD_VIRTUALBOX}" \
        && USE_MKG_WORKFLOW=false \
        && USE_CLONEZILLA_WORKFLOW=false \
        && DOWNLOAD_ARCH=false \
        && CLONEZILLA_INSTALL=true

    if "${HOT_INSTALL}" && "${DEVICE_INSTALLER}"
    then
        ${LOG[*]} "[ERR] Either use hot_install or device_installer \
for a given ext_device"
        exit 1
    fi

    if  ("${HOT_INSTALL}" || "${DEVICE_INSTALLER}") \
        &&  [ -n "${EXT_DEVICE}" ]  && [ "${EXT_DEVICE}" != "dep" ]
    then
        if "${INTERACTIVE}"
        then
            echo "[WAR] All data will be wiped out on device(s): ${EXT_DEVICE}."
            read -p "Please confirm by entering uppercase Y: " rep
            [ "${rep}" != "Y" ] && exit 0
            echo "[WAR] Once again."
            echo "      All data will be wiped out on device(s): ${EXT_DEVICE}."
            read -p "      Please confirm by entering uppercase Y: " rep
            [ "${rep}" != "Y" ] && exit 0
        else
            echo "[WAR] CAUTION: non-interactive mode is on. Device \
${EXT_DEVICE} will be erased and written to upon completion. \
You may want to abort this process just now (it should be time). \
Allowing a 10 second break for second thoughts."
            echo sleep 10
        fi
    fi

    if ("${TEST_ONLY}" || "${TEST_EMERGE}") && "${USE_MKG_WORKFLOW}"
    then
        ${LOG[*]} "Options use_mkg_workflow and test_... are incompatible."
        ${LOG[*]} "Run again with use_mkg_workflow=false test_only test_emerge"
        exit 1
    fi

    ###########################################################################
    #  Elevated rights                                                        #
    #                                                                         #
    #  root is necessary for mksquashfs/unsquashfs and mount.                 #
    #  bsdtar, when used, makes it possible to avoid mounts                   #
    #  hence elevated rights but this works only is 3rd-party workflows are   #
    #  used or if a custom CloneZilla CD has been previously obtained.        #
    #                                                                         #
    #  root is also necxessary when chroot is used (TEST_EMERGE) and/or using #
    #  another block device with dd or ocs-sr                                 #
    ###########################################################################

    "${USE_CLONEZILLA_WORKFLOW}" && DOWNLOAD_CLONEZILLA=false

    if ! "${USE_MKG_WORKFLOW}" \
            || (! "${USE_CLONEZILLA_WORKFLOW}" \
                && ([ -z "${CUSTOM_CLONEZILLA}" ] \
                    || [ "${CUSTOM_CLONEZILLA}" = "dep" ])) \
            || ! "${USE_BSDTAR}" \
            || "${TEST_EMERGE}" \
            || "${HOT_INSTALL}" \
            || "${FROM_DEVICE}"
    then
        need_root
    fi

    "${TEST_ONLY}" && TEST_EMERGE=true && USE_MKG_WORKFLOW=false

    "${USE_BSDTAR}" && check_tool "bsdtar"

    # This must come at the end of this function as there are absolute overrides
    if  "${DOCKERIZE}" && ( "${TEST_EMERGE}" \
                    || "${HOT_INSTALL}" \
                    || ! "${USE_CLONEZILLA_WORKFLOW}" \
                    || "${BUILD_VIRTUALBOX}" \
                    || [ "${SHARE_ROOT}" != "dep" ] \
                    || "${DO_GNU_PLOT}")
    then
        ${LOG[*]} "[ERR] Cannot dockerize with X11 display or mounts within \
container: "
        ${LOG[*]} "      The following options cannot be used:"
        ${LOG[*]} "      build_virtualbox, disconnect, gui, hot_install, plot, \
share_root, test_emerge, use_clonezilla_workflow=false"
        exit 1
    else
        GUI=false
        INTERACTIVE=false
    fi

    grep -q -E '[a-z]{2}_[A-Z]{2}\.?[@_.a-zA-Z0-9]*' <<< "${VM_LANGUAGE}"

    if_fails $? "[ERR] vm_language must have at least 5 characters and follow \
this regular expression: [a-z]{2}_[A-Z]{2}\.?[@_.a-zA-Z0-9]*"

    grep -q -E '(openrc|hardened|systemd)' <<< "${STAGE3_TAG}"
    if_fails $? "[ERR] stage3_tag must be: openrc [default], hardened or \
systemd."

    "${CUT_ISO}" && SUMS=true
}

check_docker_container_vbox_version() {

   VBoxManage --version | tail -1 | grep -o -E '[0-9]+\.[0-9]+\.[0-9]{1,2}'
}

## @fn run_docker_container()
## @brief Run the downloaded Docker image.
## @details
## @li Run the MKG command line within the container.
## @warning Needs administrative rights to load the image.
## @retval The Docker ID of the container started by @code docker run @endcode
## @ingroup createInstaller

run_docker_container() {

    check_tool docker

    need_root
    local cli=$(sed -r \
       "s/(.*)dockerize(.*)/\1 \2 \
check_vbox_version=$(check_docker_container_vbox_version)/" <<< "$@")
    ${LOG[*]} "[INF] Starting container with command line: "
    ${LOG[*]} "[MSG] ${cli}"

    # Experimental, undocumented environment variable
    # DOCKER_RUN_OPTS

    local DOCKER_ID=$(docker run  ${DOCKER_RUN_OPTS} -dit --privileged \
           -v /dev/cdrom:/dev/cdrom -v /dev/sr0:/dev/sr0  -v /dev/log:/dev/log \
                  --device /dev/vboxdrv:/dev/vboxdrv mygentoo:${WORKFLOW_TAG2} \
		  ${cli})

    if_fails $? "[ERR] Could not start container mygentoo:${WORKFLOW_TAG2}"
    if [ -z "${DOCKER_ID}" ]
    then
        ${LOG[*]} "[ERR] Docker crashed on launch."
        exit 1
    else
        ${LOG[*]} "[MSG] Started Docker container for tag ${WORKFLOW_TAG2}."
    fi

    # Every minute, check if the above container is still running.
    sleep 300
    while docker inspect ${DOCKER_ID} | grep -q '"Running": true'
    do
        sleep 60
	${LOG[*]} "[MSG] Container running."
    done

    ! "${CREATE_ISO}" && return 0

    # Once stopped, check if ISO was created and fetch it back.
    # For this it is necessary to restart.

    if docker start ${DOCKER_ID}
    then
        if  docker exec ${DOCKER_ID} test -f "${ISO_OUTPUT}"
        then
            if docker cp ${DOCKER_ID}:/mkg/"${ISO_OUTPUT}" .
            then
                ${LOG[*]} "[MSG] CloneZilla installer ${ISO_OUTPUT} was retrieved \
from Docker image."
                docker stop ${DOCKER_ID}
                exit 0
            else
                ${LOG[*]} "[MSG] CloneZilla installer ${ISO_OUTPUT} could not \
be retrieved from Docker image. Check manually."
                docker stop ${DOCKER_ID}
                exit 3
            fi
        else
            ${LOG[*]} "[ERR] Could not find file ${ISO_OUTPUT}"
            docker stop ${DOCKER_ID}
            exit 2
        fi
    else
        ${LOG[*]} "[ERR] Dockerized process failed to create ISO installer (startup)."
        exit 1
    fi
}

# ---------------------------------------------------------------------------- #
# SQUASHFS/UNSQUASHFS operations
#

## @fn mount_live_cd()
## @brief Mount Gentoo/Clonezilla live CD and unsquashfs the GNU/linux system.
## @note  live CD is mounted under $VMPATH/mnt and rsync'd to $VMPATH/mnt2
## @ingroup createInstaller

mount_live_cd() {

    prepare_chroot

    # ISOLINUX config adjustments to automate the boot and reduce user input
    echo $PWD
    check_dir "mnt2/${ISOLINUX_DIR}"
    cd "mnt2/${ISOLINUX_DIR}"
    if "${CLONEZILLA_INSTALL}"
    then
        cp ${verb} -f "${VMPATH}/clonezilla/syslinux/isolinux.cfg" .
    else
        check_files isolinux.cfg
        sed -i 's/timeout.*/timeout 1/' isolinux.cfg
        sed -i 's/ontimeout.*/ontimeout gentoo/' isolinux.cfg
    fi
    cd "${ROOT_LIVE}"
}

## @fn prepare_chroot()
## @brief Mount the minimal install under mnt, rsync to mnt2.
## @note  live CD is mounted under $VMPATH/mnt and rsync'd to $VMPATH/mnt2
## @ingroup createInstaller

prepare_chroot() {

    check_file "${ISO}" "[ERR] No active ISO file in current directory!"
    if ! "${CREATE_SQUASHFS}"
    then
        ${LOG[*]} "[MSG] Reusing ${ISO} which was previously created... \
use this option with care if only you have run mkg before."
        ${LOG[*]} "[MSG] create_squashfs should be left at 'true' (default) \
if mkvm.sh or mkvm_chroot.sh have been altered"
        ${LOG[*]} "[MSG] or the kernel config file, the global variables, \
the boot config files, the stage3 archive or the ebuild list."
        ${LOG[*]} "[MSG] It can be set at 'false' if the install ISO file and \
stage3 archive are cached in the directory after prior downloads"
        ${LOG[*]} "[MSG] with no other changes in the above set of files."
        return 0
    fi

    # mount ISO install file

    local verb=""
    "${VERBOSE}" && verb="-v"
    mountpoint -q mnt && umount -l mnt
    [ -d mnt ] && rm -rf mnt

    if ! "${USE_BSDTAR}"
    then
        mkdir mnt
        check_dir mnt
        mount -oloop "${ISO}" mnt/  2>/dev/null
        ! mountpoint -q mnt && ${LOG[*]} "[ERR] ISO not mounted!" && exit 1
    fi

    #parameter adjustment to account for Gentoo/CloneZilla differences

    ROOT_LIVE="${VMPATH}/mnt2"
    SQUASHFS_FILESYSTEM=image.squashfs
    export ISOLINUX_DIR=isolinux
    if "${CLONEZILLA_INSTALL}"
    then
        ISOLINUX_DIR=syslinux
        ROOT_LIVE="${VMPATH}/mnt2/live"
        SQUASHFS_FILESYSTEM=filesystem.squashfs
    fi

    remove_chroot

    mkdir mnt2/
    check_dir mnt2

    if "${USE_BSDTAR}"
    then
        cd mnt2
        BSDTAR_BINARY="$(which bsdtar)" >/dev/null 2>&1
        if_fails $? "[ERR] Could not find bsdtar."
        "${BSDTAR_BINARY}" xpf ../"${ISO}"
        if_fails $? "[ERR] bsdtar failed to extract ${ISO}."
        "${VERBOSE}" && ${LOG[*]} "[MSG] ${ISO} was extracted under mnt2."
        cd -
    else
        # get a copy with write access

        "${VERBOSE}" && ${LOG[*]} "[INF] Syncing mnt2 with ISO mountpoint..."
        rsync -a mnt/ mnt2
    fi

    # now unsquashfs the liveCD filesystem

    cd "${ROOT_LIVE}"

    "${VERBOSE}" && ${LOG[*]} "[INF] Unsquashing filesystem..." \
        && unsquashfs "${SQUASHFS_FILESYSTEM}"  \
             ||  unsquashfs -q  "${SQUASHFS_FILESYSTEM}" 2>&1 >/dev/null

    if_fails $? "[ERR] unsquashfs failed!"
    cd "${VMPATH}"
    if_fails $? "[ERR] Could not cd to root directory"
}

remove_chroot() {

    cd "${VMPATH}"
    if_fails $? "[ERR] Could not cd to root directory."

    ! [ -d mnt2 ] && return 0
    if [ -d "${ROOT_LIVE}/squashfs-root" ]
    then
	    if mountpoint -q "${ROOT_LIVE}/squashfs-root/dev" \
                || mountpoint -q "${ROOT_LIVE}/squashfs-root/sys"
	    then
            unbind_filesystem "${ROOT_LIVE}/squashfs-root"
            if_fails $? "[ERR] Failed to unmount and wipe out \
${ROOT_LIVE}/squashfs-root\      Please see to this manually.\
      You may have to reboot."
	    fi
    else
        "${VERBOSE}" && echo "No directory: ${ROOT_LIVE}/squashfs-root"
    fi

    ${LOG[*]} <<< $(rm -rf mnt2 2>&1 \
                        | xargs echo "[INF] Removing mount directory")
}

# ----------------------------------------------------------------------------
# TESTS
#

## @fn test_emerge_step()
## @brief Test whether portage operations in mkvm_chroot.sh will succeed.
## @note  In rare cases, latest pointer from Gentoo mirror may be obsolete
##        and trigger very long runs. Extra checks have been added to face
##        such cases which may look redundant or useless but are not in these
##        cases (Aug. 2021).
## @ingroup createInstaller

test_emerge_step() {

    if "${CLONEZILLA_INSTALL}"
    then
        echo "[ERR] Clonezilla install does not support \
pre-test of package merging"
        return 0
    fi

    prepare_chroot

    cd "${VMPATH}"
    if_fails $? "[ERR] Could not cd to root directory."

    move_auxiliary_files "mnt2/squashfs-root"
    chown root ${ELIST}
    chmod +rw ${ELIST}
    dos2unix -q ${ELIST}

    cd mnt2/squashfs-root
    if_fails $? "[ERR] Could not cd to squashfs-root"

    tar xpJf "${STAGE3}" --xattrs-include='*.*' --numeric-owner

    prepare_bash_rc

    mkdir --parents etc/portage/repos.conf
    cp usr/share/portage/config/repos.conf etc/portage/repos.conf/gentoo.conf
    cp ${verb} --dereference /etc/resolv.conf etc/
    m_conf="etc/portage/make.conf"
    ${LOG[*]} "[MSG] Using CFLAGS=${CFLAGS}"
    sed  -i "s/COMMON_FLAGS=.*/COMMON_FLAGS=\"${CFLAGS} -pipe\"/g"  ${m_conf}
    echo MAKEOPTS=-j${NCPUS}  >> ${m_conf}
    echo "L10N=\"${VM_LANGUAGE} en\""    >> ${m_conf}
    sed  -i 's/USE=".*"//g'    ${m_conf}
    echo "USE=\"-gtk -gnome qt4 qt5 kde dvd alsa cdr bindist networkmanager  \
elogind -consolekit -systemd mpi dbus X nls\"" >>  ${m_conf}
    echo "GENTOO_MIRRORS=\"${EMIRRORS}\""  >> ${m_conf}
    echo "ACCEPT_LICENSE=\"-* @FREE MPEG-4 linux-fw-redistributable \
no-source-code bh-luxi\"" >> ${m_conf}
    if [ "${BIOS}" = "true" ]
    then
        echo 'GRUB_PLATFORMS="i386-pc"' >> ${m_conf}
    else
        echo 'GRUB_PLATFORMS="efi-64"' >> ${m_conf}
    fi
    echo 'VIDEO_CARDS="nouveau intel"'   >> ${m_conf}
    echo 'INPUT_DEVICES="evdev synaptics"' >> ${m_conf}
    mkdir -p etc/portage/package.accept_keywords
    mkdir -p etc/portage/package.use
    cp -f "${ELIST}.accept_keywords" \
       etc/portage/package.accept_keywords/
    cp -f "${ELIST}.use"  etc/portage/package.use/
    cp -f "${ELIST}.accept_keywords" \
       etc/portage/package.accept_keywords/

    bind_filesystem "."

    cat > portage_test.sh << EOF
#!/bin/bash
# Note: escaped \${...} are variables
# in the subordinate environment. Non-escaped dollar
# variables are host variables.
# Note2: Things would be simpler if stage3 packages
# tagged as latest were always in sync with the portage
# tree. As this occasionally falls short of reality, we
# had to add (in August 2O21) extra package merges wrt
# the official guide procedure.

echo "[INF] Merging portage tree..."
if ! emerge-webrsync >/dev/null 2>&1
then
    echo "[ERR] Could not sync portage tree."
    exit 6
fi

# The following are for occasional cases
# in which stage3 packages have diverged from sync
# force-rebuild of pcre is necessary (case of version bump)
# because otherwise wget/curl have a pcre linking issue
# out of the box, so portage no longer works.
# Same with nghttp2. Perl then has to be updated and cleaned
# otherwise world update conflicts ensue.

emerge dev-libs/libpcre dev-libs/libpcre2
emerge net-libs/nghttp2
emerge net-misc/curl
emerge -u net/misc/wget
emerge -u dev-lang/perl

emerge app-portage/gentoolkit
revdep-rebuild -i
echo "[INF] Cleaning up perl..."
perl-cleaner --reallyall

# One needs to build cmake without the qt5 USE value first,
# otherwise dependencies cannot be resolved.

USE='-qt5' emerge -1 cmake
if [ \$? != 0 ]
then
    echo "emerge cmake failed!" | tee -a emerge.build
    return 1
fi

# There is an intractable circular dependency that
# can be broken by pre-emerging python

USE="-sqlite -bluetooth" emerge -1 dev-lang/python | tee -a emerge.build
if [ \$? != 0 ]
then
    echo "emerge python failed!" | tee -a emerge.build
    return 1
fi

emerge -1 -u sys-apps/portage

# select profile (most recent plasma desktop)

local profile=\$(eselect --color=no --brief profile list \
                    | grep desktop \
                    | grep plasma \
                    | grep \${PROCESSOR} \
                    | grep -v systemd \
                    | head -n 1)

eselect profile set \${profile}

emerge -uD app-admin/sysklogd
# other core sysapps to be merged first. LZ4 is a kernel
# dependency for newer linux kernels.

emerge -u app-arch/lz4 net-misc/netifrc sys-apps/pcmciautils

if [ \$? != 0 ]
then
   echo "[ERR] emerge netifrs/pcmiautils failed!" | tee -a emerge.build
   return 1
fi

# Force rebuild glibc
# so that gcc updates can be built (stub-32.h dep).
emerge sys-libs/glibc

# These two are needed for freetype/harfbuzz builds
emerge sys-libs/libcap-ng
emerge media-libs/libpng

# Solve circular dep between freetype and harfbuzz

USE="-harfbuzz" emerge media-libs/freetype

# Force rebuilds also needed further down
emerge dev-libs/elfutils
emerge app-arch/zstd

# There is one perl module that needs glibc, so retry cleaning
# after rebuild of glibc
perl-cleaner --all

## ---- PATCH ----
#
# This is temporarily necessary while display-manager is not
# stabilized in the portage tree (March 2021)
# NOTE: should be retrieved later on

emerge -q --unmerge sys-apps/sysvinit

## ---- End of patch ----

#emerge -uDN --with-bdeps=y --keep-going @world
emerge --pretend -uDN --with-bdeps=y @world

#[ $? != 0 ] && {
#    echo "[ERR] emerge @world failed!"
#    return 1; }

emerge -q -u --keep-going sys-apps/sysvinit

# Note: gcc update is part of @world build

emerge -u --config sys-libs/timezone-data
emerge sys-kernel/linux-firmware
emerge -u dos2unix

# There is a elusive, occasional block betwen
# shadow and man-pages. Making sure that this
# does not arise here.
emerge -1 -u sys-apps/shadow

chown root \${ELIST}
chmod +rw \${ELIST}
dos2unix \${ELIST}

emerge --pretend -uDN --keep-going --with-bdeps=y \$(grep -v '#' "${ELIST}" | xargs)
if [ \$? != 0 ]
then
    emerge --pretend -uDN --with-bdeps=y \$(grep -v '#' "${ELIST}" | xargs)
fi

if [ \$? != 0 ]
then
    echo "[ERR] Could not emerge packages"
    exit 3
fi
exit 0
EOF

    chmod +x portage_test.sh
    chroot . /bin/bash portage_test.sh
    if [ $? != 0 ]
    then
        ${LOG[*]} "[ERR] Virtual machine should not be able to merge packages." \
             "[ERR] Check files ebuilds.list.accept_keywords, ebuilds.list.use" \
             "      and ebuilds.list.complete or minimal using messages from" \
             "      calls to emerge."
        remove_chroot
        exit 1
    fi
    ${LOG[*]} "[MSG] Portage tests were passed."
    remove_chroot
    return 0
}

## @fn move_auxiliary_files()
## @private

move_auxiliary_files() {

    cd "${VMPATH}"
    if_fails $? "[ERR] Could not cd to root directory."

    if "${MINIMAL}"
    then
        cp  "${ELIST}.minimal"  "${ELIST}"
    else
        cp  "${ELIST}.complete" "${ELIST}"
    fi

    check_file scripts/mkvm.sh  "[ERR] No mkvm.sh script!"
    check_file scripts/mkvm_chroot.sh "[ERR] No mkvm_chroot.sh script!"
    check_file "${ELIST}"     "[ERR] No ebuild list!"
    check_file "${ELIST}.use" "[ERR] No ebuild list!"
    check_file "${ELIST}.accept_keywords" "[ERR] No ebuild list!"
    check_file "${STAGE3}"  "[ERR] No stage3 archive!"
    check_file "${KERNEL_CONFIG}" "[ERR] No kernel configuration file!"

    ${LOG[*]} <<< $(cp -f "${STAGE3}" "$1" 2>&1 \
                        | xargs echo "[INF] Moving ${STAGE3} to $1")
    if_fails $? "[ERR] Could not move ${STAGE3}"

    ${LOG[*]} <<< $(cp -f scripts/mkvm.sh "$1"  2>&1 \
                        | xargs echo "[INF] Moving mkvm.sh")
    if_fails $? "[ERR] Could not move ${STAGE3}"

    ${LOG[*]} <<< $(chmod +x "$1"/mkvm.sh 2>&1 \
                        | xargs echo "[INF] Changing permissions")
    if_fails $? "[ERR] Could not move mkvm.sh"

    ${LOG[*]} <<< $(cp -f scripts/mkvm_chroot.sh "$1" 2>&1 \
                        | xargs echo "[INF] Moving mkvm_chroot.sh")
    if_fails $? "[ERR] Could not move mkvm_chroot.sh"

    ${LOG[*]} <<< $(chmod +x "$1"/mkvm_chroot.sh \
                        | xargs echo "[INF] changing permissions")
    if_fails $? "[ERR] Could not change permissions"

    ${LOG[*]} <<< $(cp -f "${ELIST}" "${ELIST}.use" \
                       "${ELIST}.accept_keywords" "$1" 2>&1 \
                        | xargs echo "[INF] Moving ebuild lists")
    if_fails $? "[ERR] Could not move ebuild lists"

    ${LOG[*]} <<< $(cp -f "${KERNEL_CONFIG}" "$1" 2>&1 \
                        | xargs echo "[INF] Moving kernel config")
    if_fails $? "[ERR] Could not move kernel config file"

}

## @fn make_boot_from_livecd()
## @brief Tweak the Gentoo minimal install CD so that the custom-
## made shell scripts and stage3 archive  are included into the squashfs
## filesystem.
## @details This function is returned from early if @code create_squashfs=false
## @endcode is given on commandline.
## @note Will be run in the ${VM} virtual machine
## @retval Returns 0 on success or -1 on failure.
## @ingroup createInstaller

make_boot_from_livecd() {

    # ------------------------------------- #
    # Mounting live CD and requirement checks
    #

    mount_live_cd

    # we stick to the official mount point /mnt/gentoo

    if "${CLONEZILLA_INSTALL}"
    then
        mkdir -p ../mnt/gentoo
        check_dir  ../mnt/gentoo
    fi

    # copy the scripts, kernel config, ebuild list and stage3 archive to the
    # /root directory of the unsquashed filesystem
    # note: environment variables are passed along using a "physical" copy to
    # /root/.bashrc

    check_dir "${VMPATH}"
    cd "${VMPATH}"

    # ------------------------------------------------------ #
    # Moving platform building scripts to unsquashed live CD
    #

    local sqrt="${ROOT_LIVE}/squashfs-root/root/"
    check_dir  "${sqrt}"

    move_auxiliary_files "${sqrt}"
    cd "${sqrt}" || exit 2

    prepare_bash_rc

    # the whole platform-making process will be launched by mkvm.sh under /root/
    # and fired on by .bashrc sourcing once the liveCD exits the boot process
    # into root shell

    echo  "/bin/bash mkvm.sh"  >> ${rc}

    # -------------------------------------------------------------- #
    #  Now restore the squashfs filesystem to recreate a new live CD
    #

    cd ../.. || exit 2
    ${LOG[*]} <<< $(rm  -f "${SQUASHFS_FILESYSTEM}" 2>&1 \
                        | xargs echo "[INF] Removing ${SQUASHFS_FILESYSTEM}")
    local verb2="-quiet"
    ${LOG[*]} <<< $(mksquashfs squashfs-root/ ${SQUASHFS_FILESYSTEM}  2>&1 \
                        | xargs echo "[INF] Created ${SQUASHFS_FILESYSTEM}")
    ${LOG[*]} <<< $(rm -rf squashfs-root/ 2>&1 \
                        | xargs echo "[INF] Removing squashfs-root")

    # restore the ISO in bootable format

    cd "${VMPATH}" || exit 2

    ${LOG[*]} <<< $(recreate_liveCD_ISO "${VMPATH}/mnt2/" | \
                        xargs echo "[INF] Recreating ISO")

    mountpoint -q mnt && umount -l mnt
    ${LOG[*]} <<< $(rm -rf mnt | xargs echo "[INF] Removing mnt")

    "${CLEANUP}" && remove_chroot
    return 0
}

## @fn prepare_bash_rc()
## Prepare the .bashrc file by exporting the environment
## this will be placed under /root in the VM

prepare_bash_rc() {

    rc=".bashrc"
    local BASHRC=/etc/bash/bashrc
    ! [ -f "${BASHRC}" ] && BASHRC=/etc/bash.bashrc # Ubuntu
    if ! [ -f "${BASHRC}" ]
    then
        ${LOG[*]} "[ERR] Could not locate a bashrc skeleton"
        exit 1
    fi

    ${LOG[*]} <<< $(cp -f ${BASHRC} ${rc})
    declare -i i
    for ((i=0; i<ARRAY_LENGTH; i++))
    do
        local  capname=${ARR[i*4]^^}
        local  expstring="export ${capname}=\"${!capname}\""
        "${VERBOSE}" && ${LOG[*]} "${expstring}"
        echo "${expstring}" >> ${rc}
    done
    chmod +x ${rc}
}

# ---------------------------------------------------------------------------- #
# Virtual machine processing
#

## @fn test_vm_running()
## @brief Check if VM as first named argument exists and is running
## @param vm VM name or UUID
## @retval  Returns 0 on success and 1 is VM is not listed or not running
## @ingroup createInstaller

test_vm_running() {
    [ -n "$(VBoxManage list vms | grep \"$1\")" ] \
        && [ -n "$(VBoxManage list runningvms | grep \"$1\")" ]
}

## @fn deep_clean()
## @private
## @brief Force-clean root VirtualBox registry
## @ingroup createInstaller

deep_clean() {

    # no deep clean with 'force=false'

    ! "${FORCE}" && return 0

    ${LOG[*]} "[INF] Cleaning up hard disks in config file because of \
inconsistencies in VM settings"
    local registry="/root/.config/VirtualBox/VirtualBox.xml"
    if grep -q "${VM}.vdi" ${registry}
    then
        ${LOG[*]} "[MSG] Disk \"${VM}.vdi\" is already registered and needs \
 to be wiped out of the registry"
        ${LOG[*]} "[MSG] Otherwise issues may arise with UUIDS and data \
integrity"
        ${LOG[*]} "[WAR] Stopping VirtualBox server. You need to stop/snapshot \
your running VMs."
        ${LOG[*]} "[WAR] Enter Y when this is done or another key to exit."
        ${LOG[*]} "[WAR] In which case \"${VM}.vdi\" might not be properly \
attached to virtual machine ${VM}"
        if "${INTERACTIVE}"
        then
            [ "$1" != "ISO_STAGE" ] \
                &&   read -p "Enter Y to continue or another key to skip deep \
clean: " reply || reply="Y"
            [ "${reply}" != "Y" ] && [ "${reply}" != "y" ] && return 0
        fi
    fi
    /etc/init.d/virtualbox stop
    sleep 5
    sed -i  '/^.*HardDisk.*$/d' ${registry}
    sed -i -E  's/^(.*)<MediaRegistry>.*$/\1<MediaRegisty\/>/g' ${registry}
    sed -i '/^.*<\/MediaRegistry>.*$/d' ${registry}
    sed -i  '/^[[:space:]]*$/d' ${registry}
    "${DEBUG_MODE}" && cat  ${registry}

    # it is necessary to sleep a bit otherwise doaemons will wake up
    # with inconstitencies

    sleep 5
    /etc/init.d/virtualbox start
}

## @fn delete_vm()
## @param vm VM name
## @param ext virtual disk extension, without dot (defaults to "vdi").
## @param mode "" for standard VM or "ISO_STAGE" for ISO-creating VM.
## @brief Powers off, possibly with emergency stop,
##        the VM names as first argument.
## @details @li Unregisters it
## @li Deletes its folder structure and hard drive
##     (default is "vdi" as a second argument)
## @retval Returns 0 if Directory and hard drive could be erased,
##         otherwise the OR value of both
## erasing commands
## @ingroup createInstaller

delete_vm() {

    if test_vm_running "$1"
    then
        ${LOG[*]} "[INF] Powering off $1"
        ${LOG[*]} <<< $(VBoxManage controlvm "$1" poweroff 2>&1 \
                            | xargs echo "[INF]")
    fi
    if test_vm_running "$1"
    then
        ${LOG[*]} "[INF] Emergency stop for $1"
        ${LOG[*]} <<< $(VBoxManage startvm $1 --type emergencystop 2>&1 \
                            | xargs echo "[INF]")
    fi

    if [ -f "${VMPATH}/$1.$2" ]
    then
        ${LOG[*]} "[INF] Closing medium $1.$2"
        if VBoxManage showmediuminfo "${VMPATH}/$1.$2" 2>/dev/null 1>/dev/null
        then
            ${LOG[*]} <<< $(VBoxManage storageattach "$1" \
                                       --storagectl "SATA Controller" \
                                       --port 0 \
                                       --medium none 2>&1 \
                                | xargs echo "[INF]")
            ${LOG[*]} <<< $(VBoxManage closemedium  disk "${VMPATH}/$1.$2" \
                                       --delete 2>&1 \
                                | xargs echo "[INF]")
        fi
    fi

    local res=$?

    if [ ${res} != 0 ] || "${FORCE}"
    then

        # last resort.
        # Happens when debugging with successive VMS with
        # same names or disk names and not enough wait time for
        # daemons to clean up the mess one needs to deep-clean
        # twice.
        # deep_clean will peek and clean the registry altering
        # it only if requested for security. This may cause other VMs
        # to crash.

        deep_clean "$3"
    fi
    if [ -n "$(VBoxManage list vms | grep \"$1\")" ]
    then
        ${LOG[*]} "[MSF] Current virtual machine: $(VBoxManage list vms \
| grep \"$1\"))"
        ${LOG[*]} "[INF] Removing SATA controller"
        VBoxManage storagectl "$1" \
                   --name "SATA Controller" \
                   --remove 2>&1 | ${LOG[*]}
        ${LOG[*]} "[INF] Removing IDE controller"
        VBoxManage storagectl "$1" \
                   --name "IDE Controller" \
                   --remove  2>&1 | ${LOG[*]}
        ${LOG[*]} "[INF] Unregistering $1"
        VBoxManage unregistervm "$1" \
                   --delete 2>&1 | ${LOG[*]}
    fi

    # the following is overall unnecessary except for issues with
    # VBoxManage unregistervm

    if [ "$3" != "ISO_STAGE" ]
    then
        [ -d "${VMPATH}/$1" ] \
            && ${LOG[*]} "Force removing $1" \
            && rm -rf  "${VMPATH}/$1"

        # same for disk registration

        [ -n "$2" ] && [ -f "${VMPATH}/$1.$2" ] \
            && ${LOG[*]} "Force removing $1.$2" \
            && rm -f   "${VMPATH}/$1.$2"
    fi

    # deep clean again!

    { [ ${res} != 0 ] || "${FORCE}"; } && deep_clean "$3"
    return ${res}
}

## @fn create_vm()
## @brief Create main VirtualBox machine using VBoxManage commandline
## @details @li Register machine, create VDI drive, create IDE
##              drive attach disks
##          to controlers
## @li Attach augmented clonezilla LiveCD to IDE controller.
## @li Wait for the VM to complete its task. Check that it is still running
## every minute.
## @li Finally compact it.
## @param VM Name of the virtual machine.
## @note VM may be visible (vm type=gui) or without GUI (vm type=headless,
## currently to be fixed)
## @bug     VB bug note
## Unfortunately @code VBoxManage modifyvm --cpu-profile host @encode
## is not fail-safe.
## For example, this option detects my CPU (Intel core-i7 5820K) vendor,
## model name, number of cpus etc. yet the list of flags is erroneous
## and does not contain flags **fma, bmi, bmi2** necessary to compile with
## @code -march=haswell @endcode.
## The guest **/proc/cpuinfo** lacks these flags, which are listed in the host
## /proc/cpuinfo, so the VB flag import capability is buggy or incomplete.
## Borrowing partial solution from: https://superuser.com/questions/625648/
## virtualbox-how-to-force-a-specific-cpu-to-the-guest
## This added code does not unfortunately enables -march=haswell (+)
## @todo Find a way to only compact on success and never on failure of VM.
## @ingroup createInstaller

create_vm() {

    export PATH="${PATH}":"${VBPATH}"
    check_dir "${VMPATH}"
    cd "${VMPATH}"
    if [ -z "$1" ]
    then
        ${LOG[*]} "[ERR] virtual machine name vm=${VM} must not be empty."
        cleanup
    fi
    delete_vm "${1}" "vdi"

    # create and register VM

    ${LOG[*]} <<< $(VBoxManage createvm --name "${1}" \
                               --ostype ${OSTYPE}  \
                               --register \
                               --basefolder "${VMPATH}"  2>&1 \
                        | xargs echo "[INF] Creating VM.")

    # add reasonably optimal options. Note: without --cpu-profile host,
    # building issues have arisen for qtsensors
    # owing to the need of haswell+ processors to build it.
    # By default the VB processor configuration is lower-grade
    # all other parameters are listed on commandline options with default values

    ${LOG[*]} <<< $(VBoxManage modifyvm "${1}" \
                               --cpus ${NCPUS} \
                               --memory ${MEM} \
                               --vram 128 \
                               --ioapic ${IOAPIC} \
                               --usbxhci ${USBXHCI} \
                               --usbehci ${USBEHCI} \
                               --hwvirtex ${HWVIRTEX} \
                               --pae ${PAE} \
                               --cpuexecutioncap ${CPUEXECUTIONCAP} \
                               --ostype ${OSTYPE} \
                               --vtxvpid ${VTXVPID} \
                               --paravirtprovider ${PARAVIRTPROVIDER} \
                               --rtcuseutc ${RTCUSEUTC} \
                               --firmware "bios" 2>&1 \
                        | xargs echo "[INF] Adding VM parameters.")

    grep -E '^[[:digit:]abcdef]{8} ' <<< $(VBoxManage list hostcpuids) |\
	while read -r line
	do
	    leaf="0x$(echo ${line} | cut -f1 -d' ')"
            if [[ $leaf -lt 0x0b || $leaf -gt 0x17 ]]
            then
                ${LOG[*]} <<< $(VBoxManage modifyvm "${1}" --cpuidset ${line} \
				| xargs echo "[INF] Exporting host CPUID values")
	    fi
	done

    vendor='GenuineIntel'
    ascii2hex() { echo -n 0x; od -A n --endian little -t x4 | sed 's/ //g'; }

    registers=(ebx edx ecx)
    for (( i=0; i<${#vendor}; i+=4 )); do
    register=${registers[$(($i/4))]}
    value=`echo -n "${vendor:$i:4}" | ascii2hex`
    # set value to an empty string to reset the CPUID, i.e.
    # value=""
        for eax in 00000000 80000000
        do
            key=VBoxInternal/CPUM/HostCPUID/${eax}/${register}
            VBoxManage setextradata "${1}" $key $value
        done
    done

    # create virtual VDI disk, if it does not exist

    if [ ! -f  "${1}.vdi" ] || "${FORCE}"
    then
        [ -f "${1}.vdi" ] && rm -f "${1}.vdi"
        ${LOG[*]} <<< $(VBoxManage createmedium --filename "${1}.vdi" \
                                   --size ${SIZE} \
                                   --variant Standard 2>&1 \
                             | xargs echo "[INF] Adding virtual disk.")
    else
        ${LOG[*]} "[MSG] Using again old VDI disk: ${1}.vdi, \
UUID: ${MEDIUM_UUID}"
        ${LOG[*]} "[WAR] Hopefully size and caracteristics are correct."
    fi

    MEDIUM_UUID=$(VBoxManage showmediuminfo "${1}.vdi"  | head -n1 \
                      | sed -E 's/UUID: *([0-9a-z\-]+)$/\1/')

    if [ -z "${MEDIUM_UUID}" ]
    then
        if which uuid >/dev/null 2>&1
        then
            MEDIUM_UUID=$(uuid)
        else
            MEDIUM_UUID=$(uuidgen)
        fi
    fi

    [ -z "${MEDIUM_UUID}" ] \
        && ${LOG[*]} "[ERR] Could not set uuid of ${1}" && exit 1

    # set disk UUID once and for all to avoid serious debugging issues
    # whilst several VMS are around, some in zombie state, with
    # same-name disks floating around with different UUIDs and
    # registration issues

    ${LOG[*]} <<< $(VBoxManage internalcommands sethduuid "${1}.vdi" \
                               ${MEDIUM_UUID} 2>&1 \
                        | xargs echo "[INF] Setting UUID to ${MEDIUM_UUID}" )

    # add storage controllers

    ${LOG[*]} <<< $(VBoxManage storagectl "${1}" \
                               --name 'IDE Controller'  \
                               --add ide 2>&1 \
                        | xargs echo "[INF] Enabling live CD IDE controller.")
    ${LOG[*]} <<< $(VBoxManage storagectl "${1}" \
                               --name 'SATA Controller' \
                               --add sata \
                               --bootable on 2>&1 \
                        | xargs echo "[INF] Enabling storage controller.")

    # attach media to controllers and double check that the attached
    # UUID is the right one as there have been occasional issues of
    # UUID switching on attachment.
    # Only one port/device is necessary
    # use --tempeject on for live CD

    ${LOG[*]} <<< $(VBoxManage storageattach "${1}" \
                               --storagectl 'IDE Controller'  \
                               --port 0 \
                               --device 0  \
                               --type dvddrive \
                               --medium ${LIVECD} \
                               --tempeject on  2>&1 \
                        | xargs echo "[INF] Attaching IDE controller.")

    ${LOG[*]} <<< $(VBoxManage storageattach "${1}" \
                               --storagectl 'SATA Controller' \
                               --medium "${1}.vdi" \
                               --port 0 \
                               --device 0 \
                               --type hdd \
                               --setuuid ${MEDIUM_UUID} 2>&1 \
                        | xargs echo "[MSG] Attaching SATA controller.")

    # note: forcing UUID will potentially cause issues with
    # registration if a prior run with the same disk has set a prior
    # UUID in the register
    # (/root/.config/VirtualBox/VirtualBox.xml). So in the case a deep
    # clean is in order (see below).  Attaching empty drives may
    # potentially be useful (e.g. when installing guest additions)

    ${LOG[*]} <<< $(VBoxManage storageattach "${1}" \
                               --storagectl 'IDE Controller' \
                               --port 0 \
                               --device 1 \
                               --type dvddrive \
                               --medium emptydrive  2>&1 \
                        | xargs echo "[INF] Attaching empty drive.")

    # Starting VM

    ${LOG[*]} <<< $(VBoxManage startvm "${1}" \
                               --type ${VMTYPE} 2>&1 \
                        | xargs echo "[INF] Starting VM ${1}")

    # Sync with VM: this is a VBox bug workaround

    "${CLONEZILLA_INSTALL}" || ! "${GUI}" && sleep 90 \
            && ${LOG[*]} <<< $(VBoxManage controlvm "${1}" \
                                   keyboardputscancode 1c 2>&1 \
                                   | xargs echo "[INF] Working around VB bug \
sending keyboard scancode")

    log_loop "$1"

    ${LOG[*]} "[MSG] ${1} has stopped"
    if "${COMPACT}"
    then
        ${LOG[*]} "[INF] Compacting VM..."
        ${LOG[*]} <<< $(VBoxManage modifymedium "${1}.vdi" --compact 2>&1 \
                            | xargs echo "[MSG] Compacting disk ${1}.vdi ...")
    fi
}

## @fn log_loop()
## @brief Loop log tags every minute and optionally plot
##        virtual disk size
## @details Customizable suing options:
##          plot_color, plot_period, plot_position, plot_pause, plot_span
## @ingroup createInstaller

log_loop() {

    # VM is created in a separate process
    # Wait for it to come to end
    # Test if still running every minute

    declare -i loop_count=0

    while test_vm_running "$1"
    do
        ${LOG[*]} "[MSG] $1 running. Disk size: " \
                  $(du -hal "${1}.vdi")

        if "${DO_GNU_PLOT}"
        then
	    if [ "${loop_count}" = "${PLOT_PERIOD}" ]
	    then
		if ls /var/log/syslog*gz > /dev/null 2>&1
		then
		    gunzip -f /var/log/syslog*gz 2>/dev/null
		fi
		loop_count=0
		cat /var/log/syslog* 2>/dev/null  \
		    | awk '/\[[A-Z]{3}\]/ {print $11}' \
		    | grep -E '[,.]?[0-9]+G' | sed 's/G//g' \
		    | sort -g \
		    | tail -n "${PLOT_SPAN}" > datafile

		if [ -s datafile ]
		then
		    "${GNUPLOT_BINARY}" \
			-e "set terminal x11 position ${PLOT_POSITION};\
set title 'Gentoo VDI disk size';\
set style line 5 lt rgb ${PLOT_COLOR} lw 3 pt 3;\
plot 'datafile'  with linespoints ls 5;pause ${PLOT_PAUSE}"

		    # by default allow for 7 (2 for gunzip + pipes
		    # and 5 for pause) sec of lost job time (to be tested)

		    sleep $((60-${PLOT_PAUSE}-2))
		    rm -f datafile
		else
		    sleep 58
		fi
	    else
		loop_count=loop_count+1
		sleep 60
	    fi
        else
	    sleep 60
	fi
    done
}

## @fn create_iso_vm()
## @brief Create the new VirtualBox machine aimed at converting the VDI
## virtualdisk containing the Gentoo Linux distribution into an XZ-compressed
## clonezilla image uneder \b ISOFILES/home/partimag/image
## @details
## @details Register machine, create VDI drive, create IDE drive attach disks
## to controlers @n
## Attach newly augmented clonezilla LiveCD to IDE controller. @n
## Wait for the VM to complete its task. Check that it is still running every
## minute. @n
## @note VM may be visible (vm type=gui) or silent (vm type=headless,
## currently to be fixed).
## Wait for the VM to complete task. @n
## A new VM is necessary as the first VM used to build the Gentoo filesystem
## does not contain clonezilla or the VirtualBox guest additions (requested for
## sharing folders with host).
## Calls #add_guest_additions_to_clonezilla_iso to satisfy these requirements.
## @warning the \b sharedfolder command may fail vith older version of
## VirtualBox or not be implemented. It is transient, so it disappears on
## shutdown and requests prior startup of VM to be activated.
## @ingroup createInstaller

create_iso_vm() {

    cd "${VMPATH}"
    if_fails $? "[ERR] Could not cd to ${VMPATH}"

    check_file "${VM}.vdi" \
               "[ERR] A VDI disk with a Gentoo system was not found."

    # adding user to group vboxusers is recommended although not strictly
    # necessary here

    gpasswd -a "${USER}" -g vboxusers
    chgrp vboxusers "ISOFILES/home/partimag"

    # cleaning up

    delete_vm "${ISOVM}" "vdi" "ISO_STAGE"

    # creating ISO VM

    ${LOG[*]} <<< $(VBoxManage createvm \
                               --name "${ISOVM}" \
                               --ostype Ubuntu_64 \
                               --register \
                               --basefolder "${VMPATH}"  2>&1 \
                        | xargs echo "[MSG] Creating ISOVM.")

    if_fails $? "[ERR] Failed to create VM *${ISOVM}*"

    ${LOG[*]} <<< $(VBoxManage modifyvm "${ISOVM}" \
                               --cpus ${NCPUS} \
                               --cpu-profile host \
                               --memory ${MEM} \
                               --vram 128 \
                               --ioapic ${IOAPIC} \
                               --usbxhci ${USBXHCI} \
                               --usbehci ${USBEHCI} \
                               --hwvirtex ${HWVIRTEX} \
                               --pae ${PAE} \
                               --cpuexecutioncap ${CPUEXECUTIONCAP} \
                               --vtxvpid ${VTXVPID} \
                               --paravirtprovider ${PARAVIRTPROVIDER} \
                               --rtcuseutc ${RTCUSEUTC} \
                               --firmware "bios" 2>&1 \
                        | xargs echo "[MSG] Setting ISOVM parameters.")

    if_fails $? "[ERR] Failed to set parameters of VM *${ISOVM}*"

    ${LOG[*]} <<< $(VBoxManage storagectl "${ISOVM}" \
                               --name 'SATA Controller' \
                               --add sata \
                               --bootable on 2>&1 \
                        | xargs echo "[MSG] Creating ISOVM SATA controller.")

    if_fails $? \
             "[ERR] Failed to attach storage SATA controller to VM *${ISOVM}*"

    # set disk UUID once and for all to avoid serious debugging issues
    # whilst several VMS are around, some in zombie state, with
    # same-name disks floating around with different UUIDs and
    # registration issues

    if [ -z ${MEDIUM_UUID} ]
    then
        "${FROM_VM}" && ${LOG[*]} "[MSG] Setting new UUID for VDI disk." \
          || ${LOG[*]} "[WAR] Could not use again VDI uuid. Setting a new one."

        local MEDIUM_UUID=$(VBoxManage showmediuminfo "${VM}.vdi"  \
                                | head -n1 \
                                | sed -E 's/UUID: *([0-9a-z\-]+)$/\1/')
    else
        ${LOG[*]} "[MSG] UUID of ${VM}.vdi will be used again: ${MEDIUM_UUID}"
    fi

    ${LOG[*]} <<< $(VBoxManage storageattach "${ISOVM}" \
                               --storagectl 'SATA Controller' \
                               --medium "${VM}.vdi" \
                               --port 0 \
                               --device 0 \
                               --type hdd 2>&1 \
                        | xargs echo "[MSG] Attaching ISOVM")

    if_fails $? "[ERR] Failed to attach storage ${VM}.vdi to VM *${ISOVM}*"

    ${LOG[*]} <<< $(VBoxManage storagectl "${ISOVM}" \
                               --name "IDE Controller" \
                               --add ide 2>&1 \
                        | xargs echo "[MSG] Creating ISOVM IDE controller.")

    if_fails $? "[ERR] Failed to attach IDE storage controller to VM *${ISOVM}*"

    ${LOG[*]} <<< $(VBoxManage storageattach "${ISOVM}" \
                               --storagectl 'IDE Controller' \
                               --port 0 \
                               --device 0 \
                               --type dvddrive \
                               --medium "${CLONEZILLACD}" \
                               --tempeject on 2>&1 \
                        | xargs echo "[MSG] Attaching IDE controller.")

    if_fails $? "[ERR] Failed to attach clonezilla live CD to VM *${ISOVM}*"

    ${LOG[*]} <<< $(VBoxManage storageattach "${ISOVM}" \
                               --storagectl 'IDE Controller' \
                               --port 0 \
                               --device 1 \
                               --type dvddrive \
                               --medium emptydrive 2>&1 \
                        | xargs echo "[MSG] Attaching empty drive.")

    if_fails $? "[ERR] Failed to attach IDE storage controller to VM *${ISOVM}*"

    ${LOG[*]} <<< $(VBoxManage sharedfolder add "${ISOVM}" \
                               --name shared \
                               --hostpath "${VMPATH}/ISOFILES/home/partimag" \
                               --automount \
                               --auto-mount-point '/home/partimag'  2>&1 \
                        | xargs echo "[MSG] Adding shared folder to ISOVM.")

    if_fails $? "[ERR] Failed to attach shared folder \
${VMPATH}/ISOFILES/home/partimag"

    ${LOG[*]} <<< $(VBoxManage startvm "${ISOVM}" \
                               --type ${VMTYPE} 2>&1 | xargs echo [MSG])

    while test_vm_running "${ISOVM}"
    do
        ${LOG[*]} "[MSG] ${ISOVM} running..."
        sleep 60
    done
}

# -----------------------------------------------------------------------------#
# Accessing or cloning virrual machines using guestfish or qemu
#

## @fn mount_vdi()
## @brief Use qemu to mount VDI file to host folder
## @param "w" for enabling read-write mode, otherwise read-only.
## @warning May involve security issues, especially if "w" is enabled.
## @note Uses global variable ${SHARED_ROOT_DIR}
## @see Guestfish and qemu websites for security issues.

mount_vdi() {

    cd "${VMPATH}" || exit 2
    if ! [ -d "${SHARED_ROOT_DIR}" ]
    then
        ${LOG[*]}  "[ERR] \"${SHARED_ROOT_DIR}\" is not a directory."
        exit 1
    fi

    if [ "$1" = "w" ]
    then
        ${LOG[*]} "[WAR] Enabling write mode for VDI mount."
        ${LOG[*]} "[WAR] This may cause security issues: take care of I/O and"
        ${LOG[*]} "[WAR] networking security."
    fi

    check_tool qemu-nbd
    QEMU_NBD_BINARY=$(which qemu-nbd)
    modprobe nbd
    if_fails $? \
             "[ERR] Your linux kernel does not support the NBD protocol." \
             "[ERR] Please revise and rebuild your kernel configuration \
so that **modprobe nbd** succeeds."

    declare -i j=1

    while [ $j -le 50 ]
    do
        if [ "$1" = "w" ]
        then
            "${QEMU_NBD_BINARY}" -c /dev/nbd${j} -f vdi "${VM}.vdi" \
                                 >/dev/null 2>&1
        else
            "${QEMU_NBD_BINARY}" --read-only -c /dev/nbd${j} -f vdi "${VM}.vdi" \
                                 >/dev/null 2>&1
        fi
        local res=$?
        if [ $res = 0 ]
        then
            ${LOG[*]} "[MSG] Connected /dev/nbd${j}"
        else
            if [ "${VERBOSE}" = "true" ]
            then
                 ${LOG[*]} "[WAR] Could not connect VDI disk, qemu exit code: \
$res"
                 ${LOG[*]} "[WAR] Looping nbd${j}..."
            fi
            j=j+1
            continue
        fi

        sync
        sleep 2
        if [ "$1" = "w" ]
        then
            mount /dev/nbd${j}p4 "${SHARED_ROOT_DIR}" >/dev/null 2>&1
        else
            mount -o ro,norecovery /dev/nbd${j}p4 "${SHARED_ROOT_DIR}" \
                  >/dev/null 2>&1
        fi

        if [ $? != 0 ]
        then
            if [ "${VERBOSE}" = "true" ]
            then
                ${LOG[*]} "[WAR] Failed to mount virtual disk ${VM}.vdi root \
to ${SHARED_ROOT_DIR}."
                ${LOG[*]} "[WAR] Looping nbd${j}..."
            fi

            j=j+1
            "${QEMU_NBD_BINARY}" -d /dev/nbd${j}
            continue
        fi

        mount /dev/nbd${j}p2 "${SHARED_ROOT_DIR}/boot" >/dev/null 2>&1

        if [ $? != 0 ]
        then
            if [ "${VERBOSE}" = "true" ]
            then
                ${LOG[*]} "[WAR] Failed to mount virtual disk ${VM}.vdi kernel \
to ${SHARED_ROOT_DIR} boot directory."
                ${LOG[*]} "[WAR] Looping nbd${j}..."
            fi

            j=j+1
            "${QEMU_NBD_BINARY}" -d /dev/nbd${j}
            continue
        fi

        if "${EXITCODE}"
        then
           cat "${SHARED_ROOT_DIR}/res.log" | ${LOG[*]}
           unmount_vdi
           return $?
        else
           exit 0
        fi

    done

    "[ERR] Failed to connect virtual disk ${VM}.vdi to loop device \
/dev/nbd${j}. Check that the VM is not running."

    exit 1
}

## @fn unmount_vdi()
## @brief Unmount connection to virtual disk (using qemu) to host folder.
## @param mountpoint Optional mountpoint path parameter.
## @note Uses global variable ${SHARED_ROOT_DIR}
## @see Guestfish and qemu websites for security issues.

unmount_vdi() {

    local res=""
    if [ -n "$1" ] && ! [ -d "$1" ]
    then
        read -p "[MSG] Which mountpoint \
do you want to disconnect?" res || res="$1"
        if ! [ -n "${res}" ]
        then
            ${LOG[*]} "[ERR] Enter an explicit value for \
mountpoint."
            exit 1
        fi
    fi

    if [ -d "${res}" ]
    then
        SHARED_ROOT_DIR="${res}"
    else
        declare -i j=1
        while [ $j -le 50 ]
        do
            SHARED_ROOT_DIR="$(get_mountpoint nbd${j}p4)"
            if [ -z "${SHARED_ROOT_DIR}" ] || ! [ -d "${SHARED_ROOT_DIR}" ]
            then
                if [ "${VERBOSE}" = "true" ]
                then
                    ${LOG[*]} "[WAR] Could not find mountpoint \
directory for /dev/nbd${j}p4"
                fi
            else
                if [ "${VERBOSE}" = "true" ]
                then
                    ${LOG[*]} "[MSG] Found mountpoint \
${SHARED_ROOT_DIR} for /dev/nbd${j}p4"
                fi
                break
            fi
            j=j+1
        done
    fi

    if [ -n "${SHARED_ROOT_DIR}" ] && [ -d "${SHARED_ROOT_DIR}" ] \
                                          >/dev/null 2>&1
    then
        if mountpoint -q "${SHARED_ROOT_DIR}/boot"
        then
            umount -l "${SHARED_ROOT_DIR}/boot"
        fi
        if mountpoint -q "${SHARED_ROOT_DIR}"
        then
            umount -l  "${SHARED_ROOT_DIR}"
        fi

        if_fails $? "[ERR] Failed to unmount ${res}. \
Proceed manually."
        sync
        [ -z "${QEMU_NBD_BINARY}" ] && QEMU_NBD_BINARY="$(which qemu-nbd)"

        "${QEMU_NBD_BINARY}" -d /dev/nbd${j} 2>&1 | xargs logger -s "[MSG] "

        if_fails $? "[ERR] Failed to disconnect loop device /dev/nbd${j}. \
Proceed manually."

        # double check in /proc/mounts
        # experience shows that "/proc/mounts pollution" may happen
        declare -i j=1
        while [ $j -le 50 ]
        do
            if findmnt  /dev/nbd${j}p4 >/dev/null 2>&1
            then
                umount -l /dev/nbd${j}p4 >/dev/null 2>&1
            fi
            j=j+1
        done

        sync
        sleep 2
        exit 0
    fi
    sync
    exit 1
}

## @fn clone_vm_to_device()
## @brief Directly clone Gentoo VM to USB stick (or any using block device)
## @param mode Either "qemu" or "guestfish"
## @ingroup createInstaller

clone_vm_to_device() {

    cd "${VMPATH}"

    # Test whether EXT_DEVICE is a mountpoint or a block device label

    EXT_DEVICE=$(get_device ${EXT_DEVICE})

    # Should not occur, only for paranoia

    [ -z "${EXT_DEVICE}" ] \
        && { ${LOG[*]} "[ERR] Could not find external device ${EXT_DEVICE}"
             exit 1; }

    if [ "$1" = "qemu" ]
    then
        echo "[MSG] Using ${QEMU_IMG_BINARY} convert"
        check_tool qemu-img
        QEMU_IMG_BINARY=$(which qemu-img)
        ${QEMU_IMG_BINARY} convert -m $(($(nproc)/2+1)) -p -f vdi "${VM}.vdi" \
                          /dev/${EXT_DEVICE}
    else
        if [ "$1" = "guestfish" ]
        then
            echo "[MSG] Using guestfish"
            check_tool guestfish
            GUESTFISH_BINARY=$(which guestfish)
            ${GUESTFISH_BINARY} --progress-bars  --ro -a  "${VM}.vdi" run : \
                      download /dev/sda /dev/${EXT_DEVICE}
	        sync
        else
            echo "[ERR] Mode is either qemu-img or guestfish."
            exit 1
        fi
    fi

    sync
    if_fails $? "[ERR] Could not convert dynamic virtual disk to external \
block device!"
    return 0
}

## @fn create_device_system()
## @brief Clone VDI virtual disk to external device (USB device or hard drive)
## @details Two options are available, qemu or guestfish.
## @param Mode Mode must be qemu or guestfish.
## @retval 0 on success, 1 on error.
## @note Requires @b hot_install on command line to be activated as a security
##       confirmation.
##       This function performs what a live CD does to a target disk, yet using
##       the currently running operating system.
## @ingroup createInstaller

create_device_system() {

    if  [ "$1" = "guestfish" ] || [ "$1" = "qemu" ]
    then
        ${LOG[*]} "[INF] Cloning virtual disk to ${EXT_DEVICE} ..."
        if ! clone_vm_to_device "$1"
        then
            ${LOG[*]} "[ERR] Cloning VDI disk to external device failed !"
            return 1
        fi
    else
            echo "[ERR] Mode must be qemu or guestfish"
            exit 1
    fi
    return 0
}

# ---------------------------------------------------------------------------- #
# CloneZilla processing

## @fn clonezilla_to_iso()
## @brief Create Gentoo linux clonezilla ISO installer out of a clonezilla
## directory structure and an clonezilla image.
## @param iso ISO output
## @param dir Directory to be transformed into ISO output
## @note ISO can be burned to DVD or used to create a bootable USB stick
## using dd on *nix platforms or Rufus (on Windows).
## @ingroup createInstaller

clonezilla_to_iso() {

    check_dir "${VMPATH}"
    check_dir "$2"

    cd "${VMPATH}"

    local verb=""

    "${VERBOSE}" && ${LOG[*]} "[INF] Removing $2/live/squashfs-root ..."

    rm  -rf "$2/live/squashfs-root/"

    [ ! -f "$2/syslinux/isohdpfx.bin" ] \
        && cp ${verb} -f "clonezilla/syslinux/isohdpfx.bin" "$2/syslinux"

    xorriso -split_size 4096m -as mkisofs  \
	    -isohybrid-mbr "$2/syslinux/isohdpfx.bin"  \
            -c syslinux/boot.cat   -b syslinux/isolinux.bin   -no-emul-boot \
            -boot-load-size 4   -boot-info-table   -eltorito-alt-boot  \
            -e boot/grub/efi.img \
            -no-emul-boot   -isohybrid-gpt-basdat   -o "$1"  "$2"

    if_fails $? "[ERR] Could not create ISO image from ISO package \
creation directory"
   
    return 0
}

## @fn add_guest_additions_to_clonezilla_iso()
## @brief Download clonezilla ISO or recover it from cache calling
## #fetch_process_clonezilla_iso. @n
## Upgrade it with virtualbox guest additions.
## @details Chroot into the clonezilla Ubuntu GNU/Linux distribution and runs
## apt to build
## kernel modules
## and install the VirtualBox guest additions ISO image. @n
## Upgrade clonezilla kernel consequently
## Recreates the quashfs system after exiting chroot.
## Copy the new \b isolinux.cfg parameter file: automates and silences
## clonezilla behaviour
## on disk recovery.
## Calls #clonezilla_to_iso
## @note Installing the guest additions is a prerequisite to folder sharing
## between the ISO VM
## and the host.
## Folder sharing is necessary to recover a compressed clonezilla image of
## the VDI virtual disk
## into the directory ISOFILES/home/partimag/image
## @ingroup createInstaller

add_guest_additions_to_clonezilla_iso() {

    bind_mount_clonezilla_iso

    cat > squashfs-root/update_clonezilla.sh << EOF
#!/bin/bash
mkdir -p  /boot
apt update -yq
apt upgrade -yq <<< 'N'

# We take the oldest supported 5.x linux headers, modules and images
# Sometimes the most recent ones are not aligned with VB wrt. building.
# Sometimes current CloneZilla kernel has no corresponding apt headers
# So replacing with common base for which headers are available and
# compilation issues probably lesser

headers="\$(apt-cache search ^linux-headers-[5-9]\.[0-9]+.*generic \
| head -n1 | grep -v unsigned |  cut -f 1 -d' ')"
kernel="\$(apt-cache  search ^linux-image-[5-9]\.[0-9]+.*generic   \
| head -n1 | grep -v unsigned |  cut -f 1 -d' ')"
modules="\$(apt-cache search ^linux-modules-[5-9]\.[0-9]+.*generic \
| head -n1 | grep -v unsigned |  cut -f 1 -d' ')"
apt install --reinstall -qy "\${headers}"
apt install --reinstall -qy "\${kernel}"
apt install --reinstall -qy "\${modules}"
apt install -qy build-essential gcc <<< "N"
apt install -qy virtualbox virtualbox-modules virtualbox-dkms
apt install -qy virtualbox-guest-additions-iso
mount -oloop /usr/share/virtualbox/VBoxGuestAdditions.iso /mnt
cd /mnt || exit 2
/bin/bash VBoxLinuxAdditions.run
/sbin/rcvboxadd quicksetup all
cd / || exit 2
mkdir -p /home/partimag/image
umount /mnt
apt autoremove -y -q
exit
EOF

    chmod +x squashfs-root/update_clonezilla.sh

    # now chroot and run update script

    chroot squashfs-root /bin/bash update_clonezilla.sh

    # after exit now back under live/. Update linux kernel:

    check_files squashfs-root/boot/vmlinuz squashfs-root/boot/initrd.img
    cp -vf --dereference squashfs-root/boot/vmlinuz vmlinuz
    cp -vf --dereference squashfs-root/boot/initrd.img  initrd.img

    unmount_clonezilla_iso

    [ -f "${CLONEZILLACD}" ] && rm -vf "${CLONEZILLACD}"

    # this first ISO image is a "save" one: from virtual disk to clonezilla
    # image

    clonezilla_to_iso "${CLONEZILLACD}" "mnt2"
}

## @fn bind_mount_clonezilla_iso()
## @brief Fetches the clonezilla ISO.
##        mount it to mnt, rsync it to mnt2 and ISOFILES
##        bind-mount mnt2 live filesystem after unsquashfs
## @private
## @ingroup createInstaller

bind_mount_clonezilla_iso() {

    if ! "${CREATE_ISO}" && ! "${FROM_DEVICE}" && ! "${FROM_VM}"
    then
        ${LOG[*]} <<< "[ERR] CloneZilla ISO should only be mounted to create \
an ISO installer or to back up a device"
        exit 4
    fi

    cd ${VMPATH}
    if_fails $? "[ERR] Could not cd to ${VMPATH}"

    fetch_process_clonezilla_iso

    if_fails $? "[ERR] Could not fetch CloneZilla ISO file"

    local verb=""
    "${VERBOSE}" && verb="-v"

    # copy to ISOFILES as a skeletteon for ISO recovery image authoring

    [ -d ISOFILES ] && rm -rf ISOFILES
    mkdir -p ISOFILES/home/partimag
    check_dir ISOFILES/home/partimag
    check_dir mnt2
    "${VERBOSE}" \
        && ${LOG[*]} "[INF] Now copying CloneZilla files to temporary \
folder ISOFILES"
    rsync -a mnt2/ ISOFILES
    check_dir mnt2/syslinux
    if "${CREATE_ISO}"
    then
        check_file clonezilla/savedisk/isolinux.cfg
        cp ${verb} -f clonezilla/savedisk/isolinux.cfg mnt2/syslinux/
    fi
    check_dir mnt2/live

    cd mnt2/live

    bind_filesystem squashfs-root

}

## @fn unmount_clonezilla_iso()
## @brief Unmount the clonezilla filesystem after exiting chroot.
##        Restore the squashfs filesystem.
## @private
## @ingroup createInstaller

unmount_clonezilla_iso() {

    # clean up and restore squashfs back

    rm -vf filesystem.squashfs
    unbind_filesystem squashfs-root
    if_fails $? "[ERR] Could not unmount squashfs-root"

    mksquashfs squashfs-root filesystem.squashfs
    if_fails $? "[ERR] Could not recreate squashfs filesystem"

    cd "${VMPATH}"
    if_fails $? "[ERR] Could not cd to ${VMPATH}"
}

## @fn clonezilla_device_to_image()
## @brief Create CloneZilla xz-compressed image out of an external block device
##        (like a USB stick)
## @details Image is created under ISOFILES/home/partimag/image under VMPATH
## @retval 0 on success otherwise exits -1 on failure
## @ingroup createInstaller

clonezilla_device_to_image() {

    # do not use ${}  as true/false in this function as vars. are not all set

    [ -L /home/partimag ] && rm     /home/partimag
    [ -d /home/partimag ] && rm -rf /home/partimag

    mkdir -p /home/partimag
    if_fails $? "[ERR] Could not create partimag directory under /home"

    # At this stage EXT_DEVICE can no longer be a mountpoint as it has
    # been previously converted to device label

    if findmnt "/dev/${EXT_DEVICE}"
    then
        ${LOG[*]} "[MSG] Device /dev/${EXT_DEVICE} is mounted to: \
$(get_mountpoint ${EXT_DEVICE})"
        ${LOG[*]} "[WAR] The external USB device should not be mounted"
        ${LOG[*]} "[INF] Trying to unmount..."
        if umount -l "/dev/${EXT_DEVICE}"
        then
            ${LOG[*]} "[MSG] Managed to unmount /dev/${EXT_DEVICE}"
        else
            ${LOG[*]} "[ERR] Could not manage to unmount external USB device"
            ${LOG[*]} "[MSG] Unmount it manually and rerun."
            exit 1
        fi
    fi

    # double check

    if findmnt "/dev/${EXT_DEVICE}"
    then
        ${LOG[*]} "[ERR] Impossible to unmount device ${EXT_DEVICE}"
        exit 1
    fi

    # if no platform-installed ocs-sr, try to bootstrap it from clonezilla iso

    if which ocs-sr
    then
        # clonezilla has been installed on platform

        cd "${VMPATH}"
        mkdir -p  /home/partimag/image
        ocs-sr -q2 -c -j2 -nogui -batch -gm -gmf -noabo -z5p \
               -i 40960000000 -fsck -senc  \
               savedisk image ${EXT_DEVICE}
    else
        # we have to boostrap clonzilla from the iso disk

        bind_mount_clonezilla_iso

        # now under mnt2/live

        if_fails $? "[ERR] Could not remount and bind CloneZilla ISO file"
        local CLONEZILLA_MOUNTED=true

        cat > squashfs-root/create_backup_iso.sh << EOF
#!/bin/bash
mkdir -p  /home/partimag/image
ocs-sr -q2 -c -j2 -nogui -batch -gm -gmf -noabo -z5p \
-i 40960000000 -fsck -senc \
savedisk image ${EXT_DEVICE}
exit
EOF

        chmod +x squashfs-root/create_backup_iso.sh

        # now chroot and run update script

        chroot squashfs-root /bin/bash create_backup_iso.sh
    fi

    # after exit of chroot

    if_fails $? "[ERR] Cloning failed!"
    ${LOG[*]} "[MSG] Cloning succeeded!"

    if "${CLONEZILLA_MOUNTED}"
    then
        unbind_filesystem squashfs-root
        mv squashfs-root/home/partimag/image "${VMPATH}"/ISOFILES/home/partimag
        cd "${VMPATH}"
        rm -rf mnt2/
    else
        cd "${VMPATH}"
    fi
    return 0
}

## @fn prepare_for_iso_vm()
## @details Short version of #add_guest_additions_to_clonezilla_iso when
## the ISO has already been pre-authored.
## @note Installing the guest additions is a prerequisite to folder sharing
## between the ISO VM
## and the host.
## Folder sharing is necessary to recover a compressed clonezilla image of
## the VDI virtual disk
## into the directory ISOFILES/home/partimag/image
## @ingroup createInstaller

prepare_for_iso_vm() {

        CLONEZILLACD="${CUSTOM_CLONEZILLA}"
	    check_file "${CLONEZILLACD}"
	    ${LOG[*]} "[INF] Using ${CLONEZILLACD} as custom-made \
CloneZilla CD with VirtualBox and guest additions."

        # copy to ISOFILES as a skeletton for ISO recovery image authoring

        [ -d ISOFILES ] && rm -rf ISOFILES
        mkdir -p ISOFILES/home/partimag
        check_dir ISOFILES/home/partimag

        # Using bsdtar make it possible to extract CloneZilla CD from workflows
        # without having to mount.
        # This is useful within containers as loop mount is
        # not easily possible in such contexts.

        if "${USE_BSDTAR}"
        then
            "${VERBOSE}" \
                && ${LOG[*]} "[MSG] Using bsdtar to extract CloneZilla ISO"
            local BSDTAR_BINARY="$(which bsdtar)"
            if [ $? != 0 ] || [ -z "${BSDTAR_BINARY}" ]
            then
                ${LOG[*]} "[MSG] bsdtar was not found."
                USE_BSDTAR=false
            fi
        fi
        if "${USE_BSDTAR}"
        then
            cd ISOFILES
            "${BSDTAR_BINARY}" xpf ../"${CLONEZILLACD}"
            if_fails $? "[ERR] Could not extract ${CLONEZILLACD} using bsdtar."
            cd -
            return 0
        fi

        if [ -d mnt2 ]
	    then
		    rm -rf mnt2/
	        if_fails $? "[ERR] Could not remove directory mnt2. \
Unmount it and remove it manually then restart."
	    fi

        if "${USE_CLONEZILLA_WORKFLOW}" \
                || ([ -n "${CUSTOM_CLONEZILLA}" ] \
                        && [ "${CUSTOM_CLONEZILLA}" != "dep" ])
        then
            # presuming that custom clonezilla comes from workflow
            # or anyhow giving priority
            return 0
        fi

	    mkdir mnt2
        check_dir mnt2

        if "${USE_BSDTAR}"
        then
          cd mnt2
          "${BSDTAR_BINARY}" xpf ../"${CLONEZILLACD}"
          if_fails $? "[ERR] Could not extract ${CLONEZILLACD} using bsdtar."
          cd -
        else
            need_root
	        mount -oloop "${CLONEZILLACD}" mnt2/
	        if_fails $? "[ERR] Could not mount ${CLONEZILLACD} to mnt2"
            rsync -a mnt2/ ISOFILES
	        if_fails $? "[ERR] Could not sync files between mnt2 and ISOFILES"
	        umount mnt2
	        if_fails $? "[ERR] Could not unmount mnt2"
        fi
}

# -----------------------------------------------------------------------------#
# Global build launcher
#

## @fn generate_Gentoo()
## @brief Launch routines: fetch install IO, starge3 archive, create VM
## @ingroup createInstaller

generate_Gentoo() {

    if "${USE_MKG_WORKFLOW}" && ! "${DOCKERIZE}"
    then
        ${LOG[*]} "[MSG] You chose to use the output of MKG GitHub Actions."
        ${LOG[*]} "[MSG] The downloaded ISO has been preprocessed."
        ${LOG[*]} "      It has a number of fixed default parameters."
        ${LOG[*]} "[MSG] The following command line options will be ignored:"
        ${LOG[*]} "      bios, cflags, clonezilla_install, debug_mode, elist"
        ${LOG[*]} "      emirrors, gui, kernel_config, minimal, minimal_size"
        ${LOG[*]} "      ncpus, nonroot_user, passwd, processor, rootpasswd"
        ${LOG[*]} "      stage3, vm_keyboard, vm_language"
        ${LOG[*]} "[MSG] In particular, all build-specific parameters \
will be set."
        ${LOG[*]} "[MSG] If you need to specify these parameters, run again"
        ${LOG[*]} "      with use_mkg_workflow=false."
        ${LOG[*]} "[MSG] You can however fix the following command line items:"
        ${LOG[*]} "      burn, cdrecord, cloning_method, custom_clonezilla"
        ${LOG[*]} "      device_installer, disable_checksum, ext_device, force"
        ${LOG[*]} "      full_cleanup, gui, hot_install, interactive, plot"
        ${LOG[*]} "      plot_color, plot_pause, plot_period, plot_position"
        ${LOG[*]} "      plot_span, quiet_mode, size, smtp_url, use_bsdtar"
        ${LOG[*]} "      use_clonezilla_workflow, workflow_tag, workflow_tag2."

        local rep="N"
        if "${INTERACTIVE}"
        then
            read -p "[MSG] Please confirm that you are ready to use \
build presets [Y]:" rep
            if [ "${rep}" = "N" ]
            then
                ${LOG[*]} "[INF] Exiting."
                exit 0
            fi
        else
            sleep 5
        fi

        fetch_preprocessed_gentoo_install

        LIVECD=preprocessed_gentoo_install.iso
        "${DOWNLOAD_ONLY}" && exit 0
        ISO=
    else
        ${LOG[*]} "[INF] Fetching live CD..."
        fetch_livecd

        ${LOG[*]} "[INF] Fetching stage3 tarball..."
        fetch_stage3
        "${DOWNLOAD_ONLY}" && exit 0

        if "${TEST_EMERGE}"
        then
            ${LOG[*]} "[INF] Testing whether packages will be emerged..."
            test_emerge_step
        fi
        ${LOG[*]} "[INF] Tweaking live CD..."
        make_boot_from_livecd
    fi

    checksums_livecd
    "${TEST_ONLY}" && exit 0

    ${LOG[*]} "[INF] Creating VM"
    if ! create_vm "${VM}"
    then
        ${LOG[*]} "[ERR] VM failed to be created!"
        exit 1
    fi
}

# ---------------------------------------------------------------------------- #
# Core program
#

## @fn main()
## @brief Main function launching routines
## @todo Daemonize the part below generate_Gentoo when #VMTYPE is `headless`
## so that the script can be detached completely with `nohup mkgentoo..  &`
## @ingroup createInstaller

main() {

    SRCPATH=$(dirname $(realpath "$0"))

    source scripts/utils.sh
    source scripts/run_mount_shared_dir.sh

    check_tool logger git

    if grep -q 'pull' <<< "$@" && ! grep -q 'pull=false' <<< "$@"
    then
        git config user.email root@docker.container
        git config user.name "docker container"
        git pull
        if [ $? = 0 ]
        then
            logger -s "[MSG] Updated local repository."
            export CLI_PULL=$(sed -r 's/(.*)pull(=true|)(.*)/\1\3/g' <<< "$@")
            logger -s "[INF] Restarting with command line:"
            logger -s "[INF] ${CLI_PULL}"

            # Respawn script with fresh code ans same options.
            "./mkg" ${CLI_PULL}
            exit $?
        else
            logger -s "[ERR] Could not pull from repository."
            logger -s "[MSG] Continuing with current HEAD."
        fi
    fi

    # Using a temporary writable array A so that
    # ARR will not be writable later on
    # Help cases: bail out

    if grep -q 'help=md' <<< "$@"
    then
        create_options_array options
        help_md
        exit 0
    elif grep -q 'help'    <<< "$@"
    then
        create_options_array options
        help_
        exit 0
    elif grep -q 'manpage' <<< "$@"
    then
        create_options_array options
        manpage
	    exit 0
    elif grep -q 'htmlpage' <<< "$@"
    then
        create_options_array options
	    htmlpage
	    exit 0
    elif grep -q 'pdfpage' <<< "$@"
    then
        create_options_array options
	    pdfpage
	    exit 0
    elif grep -q 'allpages' <<< "$@"
    then
        create_options_array options
	    allpages
	    exit 0
    elif grep -q 'disconnect' <<< "$@"
    then
        unmount_vdi
    else
        create_options_array options2
    fi

    # parse command line. All arguments must be in the form a=true/false except
    # for help, file.iso. But 'a' can be used as shorthand for 'a=true'

    # Analyse commandline and source auxiliary files

    get_options $@
    ${LOG[*]} "% ----------------------------------------------------------- %"
    ${LOG[*]} "[MSG] MKG was run with the following options: $@"
    ${LOG[*]} "% ----------------------------------------------------------- %"

    check_tool "tar" "sed" "mksquashfs" "mountpoint" "findmnt" "rsync" \
               "xorriso" "curl" "grep" "lsblk" "awk" \
               "mkisofs" "rsync" "xz" "dos2unix"

    if ! which uuid >/dev/null 2>&1 \
           && ! which uuidgen >/dev/null 2>&1
    then
        ${LOG[*]} "[ERR] Did not find uuid or uuidgen. Intall the uuid package"
        exit 1
    fi

    test_cli_pre
    for ((i=0; i<ARRAY_LENGTH; i++)); do test_cli $i; done
    test_cli_post

    cd "${SRCPATH}"
    source scripts/fetch_functions.sh
    # optional VirtualBox build

    if [ "${BUILD_VIRTUALBOX}" = "true" ]
    then
        source scripts/build_virtualbox.sh
        build_virtualbox
        exit 0
    else
        check_tool "VBoxManage"
    fi

    # containerization first

    if "${DOCKERIZE}"
    then
        fetch_docker_image
        run_docker_container "$@"
        exit 0
    fi

    # You can bypass generation by setting vm= on commandline

    if [ -n "${VM}" ] && ! "${FROM_VM}" && ! "${FROM_DEVICE}" && ! "${FROM_ISO}"
    then
        if ! "${NO_RUN}"
        then
            generate_Gentoo
            if_fails $? "[ERR] Could not create the OS virtual disk."
        fi
    fi

    # Process the virtual disk into a clonezilla image

    if [ -f "${VM}.vdi" ] \
       && "${CREATE_ISO}" \
       && ! "${FROM_DEVICE}"
    then
        # Now create a new VM from clonezilla ISO to retrieve
        # Gentoo filesystem from the VDI virtual disk.

	    if [ -z "${CUSTOM_CLONEZILLA}" ] || [ "${CUSTOM_CLONEZILLA}" = "dep" ]
	    then
            ${LOG[*]} \
                "[INF] Adding VirtualBox Guest Additions to CloneZilla ISO VM."
            "${VERBOSE}" \
                && ${LOG[*]} \
                       "[INF] These are necessary to activate folder sharing."

            if "${USE_CLONEZILLA_WORKFLOW}"
            then
                fetch_clonezilla_with_virtualbox
                CUSTOM_CLONEZILLA=clonezilla_with_virtualbox.iso
                prepare_for_iso_vm
            else
                add_guest_additions_to_clonezilla_iso
            fi
	    else
	        prepare_for_iso_vm
 	    fi

        # And launch the corresponding VM

        ${LOG[*]} "[INF] Launching Clonezilla VM to convert virtual disk to \
clonezilla image..."
        create_iso_vm
    fi

    if "${FROM_DEVICE}"
    then
        clonezilla_device_to_image
    fi

    if_fails $? "[ERR] Cannot proceed further on account of previous failures."

    # Now convert the clonezilla xz image image into a bootable ISO

    if "${CREATE_ISO}"
    then
        ${LOG[*]} "[INF] Creating Clonezilla bootable ISO..."

        # this second ISO image is the "restore" one: from clonezilla image
        # to target disk.
        # Now replacing the older "save" (from virtual disk to
        # clonezilla image) config file by the opposite "restore" one
        # (from clonezilla image to target disk)

        cp ${verb} -f clonezilla/restoredisk/isolinux.cfg ISOFILES/syslinux

        if clonezilla_to_iso "${ISO_OUTPUT}" ISOFILES
        then
            ${LOG[*]} "[MSG] Done."
            [ -f "${ISO_OUTPUT}" ] \
                && ${LOG[*]} "[MSG] ISO install medium was created here: \
                       ${ISO_OUTPUT}"  \
                || ${LOG[*]} "[ERR] ISO install medium failed to be created."
        else
            ${LOG[*]} "[ERR] ISO install medium failed to be created!"
            exit 1
        fi
    fi

    if "${SUMS}"
    then
        checksums_iso
    fi

    # optional ISO splitting
    
    if "${CUT_ISO}"
    then
        declare -i iso_disk_size=$(du -b "${ISO_OUTPUT}" | cut -f1)
        declare -i nb_2GiB_chunks=iso_disk_size/2147483648
        declare -i remainder=iso_disk_size%2147483648
        [ ${remainder} != 0 ] && nb_2GiB_chunks=nb_2GiB_chunks+1
        local prefix="${ISO_OUTPUT:0:(${#ISO_OUTPUT}-4)}"
        if split --numeric-suffixes=1 --suffix-length=1 -n ${nb_2GiB_chunks} \
              "${ISO_OUTPUT}" ${prefix}
        then
            ${LOG[*]} "[MSG] ISO file ${ISO_OUTPUT} was cut into ${nb_2GiB_chunks} parts."
        else
            ${LOG[*]} "[MSG] ISO file ${ISO_OUTPUT} could not be cut \
      into ${nb_GiB_chunks} parts."
        fi
        declare -i i
        for ((i=1; i<=nb_2GiB_chunks; i++))
        do
            mv ${prefix}${i} ${prefix}_${i}.iso
        done
    fi
    
    # exporting ISO bootable image to external device (like USB stick)

    "${DEVICE_INSTALLER}" && create_install_ext_device

    # optional disc burning

    if "${BURN}"
    then
       ${LOG[*]}  '[INF] Now burning disk: '
       burn_iso
    fi

    # optional "hot install" on external device

    if "${HOT_INSTALL}" && [ -n "${EXT_DEVICE}" ]
    then
        ${LOG[*]} "[INF] Creating OS on device ${EXT_DEVICE}..."
        create_device_system "${CLONING_METHOD}"
    fi

    # default cleanup

    if "${CLEANUP}"
    then
        ${LOG[*]} <<< $(cleanup 2>&1 | xargs echo '[INF] Cleaning up.')
    	cleanup
    fi

    # send wake-up call

    if [ -n "${EMAIL}" ] && [ -n "${SMTP_URL}" ]
    then

        # optional email end-of-job warning

        [ -n "${EMAIL_PASSWD}" ] \
            && [ -n "${EMAIL}" ] \
            && [ -n "${SMTP_URL}" ] \
            && ${LOG[*]} <<< $(send_mail 2>&1 \
                                   | xargs echo '[INF] Sending mail: ')
    fi

    # if Gentoo has already been built into an ISO image or on an external
    # device skip generating it; otherwise go and build the Gentoo virtual
    # machine

    # Delayed daemonized script for mounting VDI disk to ${SHARED_DIR}
    if [ "${SHARE_ROOT}" != "dep" ]
    then
        export SHARE_ROOT
        export SHARED_DIR
        "${VERBOSE}" \
            && ${LOG[*]} "[MSG] Trying to mount ${VM} to ${SHARE_ROOT_DIR}"
        if ! "${POSTPONE_QEMU}"
        then
            mount_shared_dir_daemon
            if_fails $? "[ERR] Could not launch qemu daemon to mount VDI disk."
            if "${EXITCODE}"
            then
                ${LOG[*]} $(cat "${SHARED_DIR}/res.log")
                unmount_vdi
            fi
            exit 1
        else
            check_tool at
            ${LOG[*]} "[WAR] You should have a functional 'atd' service"
            ${LOG[*]} "[WAR] Operation will not work otherwise/"
            if which rc-service
            then
                rc-service restart atd
                if_fails $? "[ERR] Could not restart atd service (Openrc)"
                ${LOG[*]} "[MSG] atd service was tested OK (Openrc)."
            else
                ${LOG[*]} "[WAR] It does not seem that you are running Openrc."
                ${LOG[*]} "[WAR] You may have to check atd manually and \
restart later."
            fi
            ${LOG[*]} "[MSG] Virtual VDI disk will be mounted in 15 minutes \
from now"
            ${LOG[*]} "[MSG] under directory ${SHARED_ROOT_DIR}"
            ${LOG[*]} "[MSG] with permissions ${SHARE_ROOT}."

            echo 'nohup /bin/bash -c "mount_shared_dir_daemon" &' \
                | at now '+ 15 minutes'
            if_fails $? "[ERR] Could not launch qemu daemon to mount VDI disk."
        fi
    fi

    ${LOG[*]} "[MSG] Gentoo building process ended."

    exit 0
}
