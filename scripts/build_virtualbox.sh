#!/bin/bash
export VMPATH=$PWD/..
export DOWNLOAD_CLONEZILLA="true"
/bin/bash fetch_clonezilla_iso.sh

fetch_clonezilla_iso
cd ${VMPATH}
cp -vf clonezilla/build/* ${CLONEZILLACD}/live
cd ${CLONEZILLACD}/live
./build_virtualbox.sh
cd ${VMPATH}
