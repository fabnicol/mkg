#!/bin/bash

get_gentoo_install_iso() {
    rm install-${PROCESSOR}-minimal*\.iso*
    rm latest-install-${PROCESSOR}-minimal*\.txt*
    local downloaded=""
    wget ${MIRROR}/releases/${PROCESSOR}/autobuilds/latest-install-${PROCESSOR}-minimal.txt
    if test $? != 0; then
        echo "Could not download live CD from Gentoo mirror"
        exit -1
    fi
    local current=$(cat latest-install-${PROCESSOR}-minimal.txt | grep "install-${PROCESSOR}-minimal.*.iso" | sed -E 's/iso.*$/iso/' )
    local downloaded=$(basename ${current})
    echo "Downloading $current..."
    wget "${MIRROR}/releases/${PROCESSOR}/autobuilds/${current}"
    if test $? != 0; then
        echo "Could not download live CD"
        exit -1
    else
        if test ${DISABLE_MD5_CHECK} = "false"; then
            check_md5sum ${downloaded}
        fi
        if test -f ${downloaded}; then
            echo "Caching downloaded ISO to ${CACHED_ISO}"
            cp -f ${downloaded} ${CACHED_ISO}
            mv ${downloaded} ${ISO}
            if test -f ${ISO}; then
                export LIVECD=${ISO}
            else
                echo "No active ISO (${ISO}) file!"
                exit -1
            fi
        else
            echo "Could not find downloaded live CD ${downloaded}"
            exit -1
        fi
    fi
}

get_clonezilla_iso() {
    local clonezilla_file=$(echo ${DOWNLOAD_CLONEZILLA_PATH} | sed -E 's/.*\/(.*)\/download/\1/')
    wget ${DOWNLOAD_CLONEZILLA_PATH} -O ${clonezilla_file}
    if test $? != 0; then
        echo "Could not download CloneZilla iso"
        exit -1
    fi
    local clonezilla_iso=$(ls clonezilla-live*amd64.iso)
    if test ${DISABLE_MD5_CHECK} = "false"; then
        check_md5sum  ${clonezilla_iso}
    fi
    export CLONEZILLACD=${clonezilla_iso}
}

get_cache_clonezilla_iso() {
    if test "${DOWNLOAD_CLONEZILLA}" = "true" -a "${VMTYPE}" = "gui"; then

        # if VMTYPE == headless, the ISO has already been downloaded

        get_clonezilla_iso

        # first cache it

        cp -vf ${CLONEZILLACD} clonezilla.iso
    else
       if test -f clonezilla.iso -a ! -f ${CLONEZILLACD}; then

           # uncache

           echo "Uncaching clonezilla.iso"
           CLONEZILLACD=clonezilla.copy.iso
           if ! $(cp -vf clonezilla.iso ${CLONEZILLACD}); then
               echo "Could not uncache clonezilla.iso"
               exit -1
           fi
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
    if test "${VMTYPE}" = "gui"; then
        get_cache_clonezilla_iso
    fi

    # now mount and unsquashfs

    if ! test -d mnt; then  rm -rf mnt; mkdir mnt; fi
    if ! test -d mnt2; then  rm -rf mnt2; mkdir mnt2; fi

    if ! $( mount -oloop ${CLONEZILLACD} ./mnt); then
        echo "Could not mount ${CLONEZILLACD} to mnt"
        exit -1
    fi
    if ! $(rsync -av ./mnt/ mnt2); then
        echo "Could not copy clonezilla files to mnt2"
        exit -1
    fi
    cd mnt2/live
    if ! $( unsquashfs filesystem.squashfs); then
        echo "Failed to unsquash clonezilla's filesystem.squashfs"
        exit -1
    fi
    cd ${VMPATH}
    rm -rf ISOFILES/*
    rsync mnt2/ ISOFILES
    cp -vf clonezilla/restoredisk/isolinux.cfg ISOFILES/syslinux/
     cp -vf /etc/resolv.conf mnt2/live/squashfs-root/etc
    return 0
}
