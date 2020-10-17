#!/bin/bash
if [ -z ${CLONEZILLACD} ] || [ -z ${VMPATH} ]
then
    logger "Export the CLONEZILLACD and VMPATH variables \
before running this script."
    exit -1
fi

export VMPATH=$PWD/..
export DOWNLOAD_CLONEZILLA="true"
/bin/bash fetch_clonezilla_iso.sh

fetch_clonezilla_iso
cd ${VMPATH}
cp -vf clonezilla/build/* ${CLONEZILLACD}/live
cd ${CLONEZILLACD}/live
./build_virtualbox.sh
cd ${VMPATH}
