#!/bin/bash

function fetch_clonezilla_iso {

    if test ${DOWNLOAD_CLONEZILLA} = "true"; then

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
       CLONEZILLACD=${clonezilla_iso}
       
       # first cache it

       if test  "${CLONEZILLACD}" != "clonezilla.iso"; then
          cp -vf ${CLONEZILLACD} clonezilla.iso
       fi
    else
        if test -f clonezilla.iso -a ! -f ${CLONEZILLACD}; then
            # uncache
            echo "Uncaching clonezilla.iso"
            CLONEZILLACD=clonezilla.copy.iso
            cp -vf clonezilla.iso ${CLONEZILLACD}
        fi    
    fi

        # now mount and unsquashfs
       
    if ! test -d mnt; then sudo rm -rf mnt; mkdir mnt; fi
    if ! test -d mnt2; then sudo rm -rf mnt2; mkdir mnt2; fi

    sudo mount -oloop ${CLONEZILLACD} ./mnt
    rsync -av ./mnt/ mnt2
    cd mnt2/live
    sudo unsquashfs filesystem.squashfs
    cp ${VMPATH}
    rm -rf ISOFILES/*
    rsync mnt2/ ISOFILES
    cp -vf clonezilla/restoredisk/isolinux.cfg ISOFILES/syslinux/
    cd -
    sudo cp -vf /etc/resolv.conf squashfs-root/etc

    return 0
}
