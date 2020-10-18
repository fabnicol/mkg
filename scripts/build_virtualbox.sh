#!/bin/bash

if [ ! -f "${VMPATH}/${CLONEZILLACD}" ] || [ ! -d "${VMPATH}" ]
then
    ${LOG[*]} "Export the CLONEZILLACD and VMPATH variables before running \
this script."
    exit 1
fi

export DOWNLOAD_CLONEZILLA="true"
source fetch_clonezilla_iso.sh

fetch_clonezilla_iso
cd ${VMPATH} || exit 2
cp -vf clonezilla/build/* ${CLONEZILLACD}/live
cd ${CLONEZILLACD}/live || exit 2
./build_virtualbox.sh
cd ${VMPATH} || exit 2
