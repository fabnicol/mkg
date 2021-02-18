#!/bin/bash

## @fn fetch_gentoo_install_iso()
## @brief Download minimal Gentoo install ISO file and caches.q
## @details Optionaly checks MD5SUMS.
## @ingroup fetchFunctions

fetch_gentoo_install_iso() {

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


## @fn fetch_clonezilla_iso()
## @brief Download clonezilla ISO file and caches it.
## @ingroup fetchFunctions

fetch_clonezilla_iso() {

    local verb=""
    ${LOG[*]} "[INF] Downloading CloneZilla..."
    local clonezilla_file="$(sed -E 's/.*\/(.*)\/download/\1/' \
                                <<< ${DOWNLOAD_CLONEZILLA_PATH})"
    ! "${VERBOSE}" && verb="-s"
    if ! curl -L "${DOWNLOAD_CLONEZILLA_PATH}" -o "${clonezilla_file}" ${verb}
    then
        ${LOG[*]} "Could not download CloneZilla iso from ${DOWNLOAD_CLONEZILLA_PATH}"
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

## @fn cache_uncache_clonezilla_iso()
## @brief Either download clonezilla ISO file and caches it OR uncaches it.
## @ingroup fetchFunctions

cache_uncache_clonezilla_iso() {
    if  "${DOWNLOAD_CLONEZILLA}" && !  "${CLONEZILLA_INSTALL}"
    then

        # If CLONEZILLA_INSTALL == true the ISO has already been downloaded

        fetch_clonezilla_iso
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

## @fn fetch_process_clonezilla_iso()
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
## @ingroup fetchFunctions

fetch_process_clonezilla_iso() {

    cache_uncache_clonezilla_iso
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

## @fn fetch_livecd()
## @brief Downloads Gentoo install CD
## @details Caches it as ${ISO}
## @retval Returns 0 on success or -1 on exit
## @ingroup fetchFunctions

fetch_livecd() {
    cd "${VMPATH}"
    local CACHED_ISO="install-${PROCESSOR}-minimal.iso"

    # Use clonezilla ISO for headless VM and Gentoo minimal install ISO for gui
    # VM

    if  "${CLONEZILLA_INSTALL}"
    then
        DOWNLOAD_CLONEZILLA="${DOWNLOAD}"
        CACHED_ISO=clonezilla.iso
    else
        "${DOWNLOAD}" && fetch_gentoo_install_iso
    fi
    if "${DOWNLOAD_CLONEZILLA}"
    then
        fetch_clonezilla_iso
        "${CLONEZILLA_INSTALL}" && ISO="${CLONEZILLACD}"
    else
        [ -f "clonezilla.iso" ] && CLONEZILLACD="clonezilla.iso" \
        || { ${LOG[*]} "[ERR] CloneZilla ISO has not been cached. \
Run with download=true" ; exit 1; }
    fi
    if ! "${DOWNLOAD}"
    then
        if  "${CREATE_SQUASHFS}"
        then
            [ -f ${CACHED_ISO} ] \
                && { ${LOG[*]} "[INF] Uncaching ${ISO} from ${CACHED_ISO}"
                cp -f ${CACHED_ISO} "${ISO}"; }
        else
            ${LOG[*]} "[ERR] No ISO file was found, please rerun with \
download=true"
            exit 1
        fi
        LIVECD="${ISO}"
    fi
    return 0
}

## @fn fetch_stage3()
## @brief Downloads a fresh stage3 Gentoo archive
## @details Caches it as ${STAGE3}
## @ingroup fetchFunctions

fetch_stage3() {

    # Fetching stage3 tarball

    local CACHED_STAGE3="stage3-${PROCESSOR}.tar.xz"
    local verb1=""
    local verb2=""
    ! "${VERBOSE}" && verb1="-s"
    "${VERBOSE}" && verb2="-v"
    if "${DOWNLOAD_ARCH}"
    then
        ${LOG[*]} "[INF] Cleaning up stage3 data..."
        for file in latest-stage3*.txt*
        do
            [ -f "${file}" ] && rm ${verb2} -f "${file}"
        done
        ${LOG[*]} "[INF] Downloading stage3 data..."
        ${LOG[*]} <<< "$(curl -L -O ${MIRROR}/releases/${PROCESSOR}/autobuilds/\
latest-stage3-${PROCESSOR}.txt ${verb1} 2>&1 | xargs echo '[INF]')"
        if_fails $? "[ERR] Could not download stage3 from mirrors: \
${MIRROR}/releases/${PROCESSOR}/autobuilds/latest-stage3-${PROCESSOR}.txt"
    else
        check_file latest-stage3-${PROCESSOR}.txt \
            "[ERR] No stage 3 download information available!" \
            "[ERR] Rerun with download_stage3=true"
    fi

    local current=$(cat latest-stage3-${PROCESSOR}.txt | \
                        grep "stage3-${PROCESSOR}".*.tar.xz | cut -f 1 -d' ')

    if "${DOWNLOAD_ARCH}"
    then
        ${LOG[*]} "[INF] Cleaning up stage3 archives(s)..."
        for file in "stage3-${PROCESSOR}"-*tar.xz*
        do
            [ -f ${file} ] && rm ${verb2} -f "${file}"
        done

        [ -f ${STAGE3} ] && rm ${verb2} -f ${STAGE3}
        ${LOG[*]} "[INF] Downloading ${current}..."
        ${LOG[*]} <<< "$(curl -L -O ${MIRROR}/releases/${PROCESSOR}/\
autobuilds/${current} ${verb1} 2>&1 | xargs echo '[INF]')"
        if_fails $? "[ERR] Could not download stage3 tarball from mirror:\
 ${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}"

        ! ${DISABLE_MD5_CHECK} && check_md5sum $(basename ${current})
        ${LOG[*]} "[INF] Caching ${current} to ${CACHED_STAGE3}"
        cp ${verb2} -f "$(echo -s ${current} \
                             | sed s/.*stage3/stage3/)"  "${CACHED_STAGE3}"
    fi

    check_file "${CACHED_STAGE3}"  "[ERR] No stage3 tarball!" \
                                   "[ERR] Rerun with download_stage3=true"
    ${LOG[*]} "[INF] Uncaching stage3 from ${CACHED_STAGE3} to ${STAGE3}"
    cp ${verb2} -f ${CACHED_STAGE3} "${STAGE3}"
}
