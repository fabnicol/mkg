#!/bin/bash

## @fn get_gentoo_install_iso()
## @brief Download minimal Gentoo install ISO file and caches.
## @details Optionaly checks MD5SUMS.
## @ingroup createInstaller

get_gentoo_install_iso() {

    rm install-${PROCESSOR}-minimal*\.iso*
    rm latest-install-${PROCESSOR}-minimal*\.txt*
    local downloaded=""
    wget ${MIRROR}/releases/${PROCESSOR}/autobuilds/latest-install-${PROCESSOR}-minimal.txt
    [ $? != 0 ] && logger -s "[ERR] Could not download live CD from Gentoo mirror" && exit -1
    local current=$(cat latest-install-${PROCESSOR}-minimal.txt \
                        | grep "install-${PROCESSOR}-minimal.*.iso" \
                        | sed -E 's/iso.*$/iso/' )
    local downloaded=$(basename ${current})
    logger -s "[INF] Downloading $current..."
    wget "${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}"
    [ $? != 0 ] && logger -s "[ERR] Could not download live CD" && exit -1
    ! "${DISABLE_MD5_CHECK}" && check_md5sum "${downloaded}"
    if [ -f ${downloaded} ]
    then
          logger -s "[INF] Caching downloaded ISO to ${CACHED_ISO}"
          cp -f ${downloaded} ${CACHED_ISO}
          mv ${downloaded} ${ISO}
          if [ -f ${ISO} ]
          then
             export LIVECD=${ISO}
          else
             logger -s "[ERR] You need to fetch an install ISO (${ISO}) file!"
             exit -1
          fi
    else
          logger -s "[ERR] Could not find downloaded live CD ${downloaded}"
          exit -1
    fi
}


## @fn get__clonezilla_iso()
## @brief Download clonezilla ISO file and caches it.
## @ingroup createInstaller

get_clonezilla_iso() {

    logger -s "[INF] Downloading CloneZilla..."
    local clonezilla_file=$(sed -E 's/.*\/(.*)\/download/\1/' <<< ${DOWNLOAD_CLONEZILLA_PATH})
    wget ${DOWNLOAD_CLONEZILLA_PATH} -O ${clonezilla_file}
    [ $? != 0 ] && { logger -s "Could not download CloneZilla iso"; exit -1; }
    local clonezilla_iso=$(ls clonezilla-live*${PROCESSOR}.iso)
    [ ${DISABLE_MD5_CHECK} = "false" ] && check_md5sum ${clonezilla_iso}
    export CLONEZILLACD=${clonezilla_iso}

    # first cache it
    local verb=""
    "${VERBOSE}" && verb="-v"
    cp ${verb} -f ${CLONEZILLACD} clonezilla.iso
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

           logger -s "[INF] Uncaching clonezilla.iso"
           CLONEZILLACD=clonezilla.copy.iso
           if ! cp -vf clonezilla.iso ${CLONEZILLACD}; then
               logger -s "[ERR] Could not uncache clonezilla.iso"
               exit -1
           fi
        else
            logger -s "[WAR] No CloneZilla ISO file was found. Please run again with 'download_clonezilla=true'"
            exit -1
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
    cd "${VMPATH}"
    local verb=""

    # now mount

    [ ! -d mnt ] &&  { rm -rf mnt; mkdir mnt; }
    [ ! -d mnt2 ] && { rm -rf mnt2; mkdir mnt2; }
    "${VERBOSE}" && logger -s "[INF] Mounting CloneZilla CD ${CLONEZILLACD}" && verb="-v"
    mount -oloop "${CLONEZILLACD}" ./mnt  \
     	|| { logger -s "[ERR] Could not mount ${CLONEZILLACD} to mnt"; exit -1; }
    "${VERBOSE}" && logger -s "[INF] Now syncing CloneZilla CD to mnt2 in rw mode."
    rsync ${verb} -a ./mnt/ mnt2 \
    	|| { logger -s "[ERR] Could not copy clonezilla files to mnt2"; exit -1; }
    cd mnt2/live
    unsquashfs filesystem.squashfs \
       || { logger -s "[ERR] Failed to unsquash clonezilla's filesystem.squashfs"; exit -1; }
    cp ${verb} -f /etc/resolv.conf squashfs-root/etc
    cd "${VMPATH}"
    return 0
}
