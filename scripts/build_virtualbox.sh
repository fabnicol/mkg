#!/bin/bash

CLONEZILLACD=clonezilla-live-20200703-focal-amd64.iso
export VMPATH=$PWD/..

if [ ! -f "${VMPATH}/${CLONEZILLACD}" ] || [ ! -d "${VMPATH}" ]
then
    eval ${LOG} "Export the CLONEZILLACD and VMPATH variables before running \
this script."
    exit -1
fi

export DOWNLOAD_CLONEZILLA="true"
source fetch_clonezilla_iso.sh

fetch_clonezilla_iso
cd ${VMPATH}
cp -vf clonezilla/build/* ${CLONEZILLACD}/live
cd ${CLONEZILLACD}/live
./build_virtualbox.sh
cd ${VMPATH}
