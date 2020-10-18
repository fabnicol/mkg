#!/bin/bash

## @fn get_gentoo_install_iso()
## @brief Download minimal Gentoo install ISO file and caches.q
## @details Optionaly checks MD5SUMS.
## @ingroup createInstaller

get_gentoo_install_iso() {

    local verb="-v"
    ! ${VERBOSE} && verb=""

    local GENTOO_LIST="install-${PROCESSOR}-minimal"
    for i in ${GENTOO_LIST}*\.iso
    do
        [ -f $i ] && rm ${verb} -f $i
    done
    for i in ${GENTOO_LIST}*\.txt*
    do
        [ -f $i ] && rm ${verb} -f $i
    done
    local downloaded=""
    local verb=""
    if ! ${VERBOSE}
    then
        verb="-s"
    else
        echo "Downloading from: ${MIRROR}/releases/${PROCESSOR}/autobuilds/\
latest-install-${PROCESSOR}-minimal.txt"
    fi

    if ! curl -L -O "${MIRROR}/releases/${PROCESSOR}/autobuilds/\
latest-install-${PROCESSOR}-minimal.txt" ${verb}
    then
        ${LOG[*]} "[ERR] Could not download live CD from Gentoo mirror"
        exit 1
    fi

    local current="$(grep install-${PROCESSOR}-minimal.*.iso \
latest-install-${PROCESSOR}-minimal.txt | sed -E 's/iso.*$/iso/' )"
    local downloaded=$(basename "${current}")
    ${LOG[*]} "[INF] Downloading $current..."

    if [ -n "${current}" ]
    then
        curl -L -O "${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}" \
             ${verb}
    else
        ${LOG[*]} "[ERR] Could not download current install iso."
        exit 1
    fi

    [ $? != 0 ] && ${LOG[*]} "[ERR] Could not download live CD" && exit 1
    ! "${DISABLE_MD5_CHECK}" && check_md5sum "${downloaded}"
    if [ -f "${downloaded}" ]
    then
          verb=""
          ${VERBOSE} && verb="-v"
          ${LOG[*]} "[INF] Caching downloaded ISO to ${CACHED_ISO}"
          cp ${verb} -f ${downloaded} ${CACHED_ISO}
          mv ${verb} ${downloaded} ${ISO}
          if [ -f ${ISO} ]
           then
             export LIVECD=${ISO}
          else
             ${LOG[*]} "[ERR] You need to fetch an install ISO (${ISO}) file!"
             exit 1
          fi
    else
          ${LOG[*]} "[ERR] Could not find downloaded live CD ${downloaded}"
          exit 1
    fi
}


## @fn get_clonezilla_iso()
## @brief Download clonezilla ISO file and caches it.
## @ingroup createInstaller

get_clonezilla_iso() {

    local verb=""
    ${LOG[*]} "[INF] Downloading CloneZilla..."
    local clonezilla_file="$(sed -E 's/.*\/(.*)\/download/\1/' \
                                <<< ${DOWNLOAD_CLONEZILLA_PATH})"
    ! "${VERBOSE}" && verb="-s"
    if ! curl -L "${DOWNLOAD_CLONEZILLA_PATH}" -o "${clonezilla_file}" ${verb}
    then
        ${LOG[*]} "Could not download CloneZilla iso"
        exit 1
    fi
    local clonezilla_iso="$(ls clonezilla-live*${PROCESSOR}.iso)"
    [ ${DISABLE_MD5_CHECK} = "false" ] && check_md5sum "${clonezilla_iso}"
    export CLONEZILLACD="${clonezilla_iso}"

    # first cache it

    verb=""
    "${VERBOSE}" && verb="-v"
    cp ${verb} -f "${CLONEZILLACD}" clonezilla.iso
}

## @fn get_cache_clonezilla_iso()
## @brief Either download clonezilla ISO file and caches it OR uncaches it.
## @ingroup createInstaller

get_cache_clonezilla_iso() {
    if  "${DOWNLOAD_CLONEZILLA}" && !  "${CLONEZILLA_INSTALL}"
    then

        # If CLONEZILLA_INSTALL == true the ISO has already been downloaded

        get_clonezilla_iso
    else
        if [ -f clonezilla.iso ]
        then

           # uncache

           ${LOG[*]} "[INF] Uncaching clonezilla.iso"
           CLONEZILLACD=clonezilla.copy.iso
           if ! cp -vf clonezilla.iso ${CLONEZILLACD}; then
               ${LOG[*]} "[ERR] Could not uncache clonezilla.iso"
               exit 1
           fi
        else
            ${LOG[*]} "[WAR] No CloneZilla ISO file was found.\
 Please run again with 'download_clonezilla=true'"
            exit 1
        fi
    fi
}

## @fn fetch_clonezilla_iso()
## @brief Download clonezilla ISO file and process it.
## @details
## @li Download iff #DOWNLOAD_CLONEZILLA has value "true"
## @li Optionnally checks MD5 sum.
## @li Caches ISO download for later uses.
## @li Uncaches it if no fresh download.
## @li Mount ISO download. Copy ro mounted filesystem to rw directory.
## @li Unsquash ISO filesystem.squashfs.
## @li Copy clonezilla config file.
## @li Copy resolv.conf to unsquashed filesystem.
## @retval 0 on success or exits -1 on failure.
## @ingroup createInstaller

fetch_clonezilla_iso() {

    get_cache_clonezilla_iso
    cd "${VMPATH}" || exit 2
    local verb=""
    "${VERBOSE}" && verb=-v

    # now cleanup, mount and copy CloneZilla live CD

    if [ ! -d mnt ]
    then
        mkdir mnt
    else
        if mountpoint mnt
        then
            if ! umount -l mnt
            then
                ${LOG[*]} "[ERR] Could not unmount mnt."
                ${LOG[*]} "[ERR] Fatal. Exiting..."
                exit 4
            fi
        fi
        rm ${verb} -rf mnt && mkdir mnt || exit 2
    fi

    [ ! -d mnt2 ] &&  mkdir mnt2  ||  { rm ${verb} -rf mnt2 && mkdir mnt2; }

    "${VERBOSE}"  && ${LOG[*]} "[INF] Mounting CloneZilla CD ${CLONEZILLACD}"
    mount -oloop "${CLONEZILLACD}" ./mnt  \
     	|| { ${LOG[*]} "[ERR] Could not mount ${CLONEZILLACD} to mnt"
             exit 1; }
    "${VERBOSE}" \
        && ${LOG[*]} "[INF] Now syncing CloneZilla CD to mnt2 in rw mode."
    rsync ${verb} -a ./mnt/ mnt2 \
    	|| { ${LOG[*]} "[ERR] Could not copy clonezilla files to mnt2"
             exit 1; }
    cd mnt2/live || exit 2
    unsquashfs filesystem.squashfs \
      || { ${LOG[*]} "[ERR] Failed to unsquash clonezilla's filesystem.squashfs"
             exit 1; }
    cp ${verb} -f /etc/resolv.conf squashfs-root/etc
    cd "${VMPATH}"
    return 0
}
