#!/bin/bash
[ -z ${CLONEZILLACD} || -z ${VMPATH} ] && logger "Export the CLONEZILLACD and VMPATH variables before running this script." && exit -1
export VMPATH=$PWD/..
export DOWNLOAD_CLONEZILLA="true"
/bin/bash fetch_clonezilla_iso.sh

fetch_clonezilla_iso
cd ${VMPATH}
cp -vf clonezilla/build/* ${CLONEZILLACD}/live
cd ${CLONEZILLACD}/live
./build_virtualbox.sh
cd ${VMPATH}
