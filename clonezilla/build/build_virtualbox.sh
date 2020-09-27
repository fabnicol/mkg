#!/bin/bash
# to be run as root
# VMPATH, VERSION, VERSION_FULL and LINENO_PATCH should be exported
# defaults are $PWD, 6.1.14, 6.1.14a, 797
echo "VERSION: ${VERSION}"
sleep 5
unsquashfs filesystem.squashfs
cp -vf /etc/resolv.conf squashfs-root/etc
cp -vf HISTORY squashfs-root
for i in proc sys dev run; do mount -B /$i squashfs-root/$i; done
cp HISTORY temp.sh
echo "#!/bin/bash" > header.sh
echo "VERSION=${VERSION}" >> header.sh
echo "VERSION_FULL=${VERSION_FULL}" >> header.sh
echo "LINENO_PATCH=${LINENO_PATCH}" >> header.sh
cat header.sh temp.sh > run.sh
rm header.sh temp.sh
chmod +x run.sh
cp -vf run.sh squashfs-root/
chroot squashfs-root ./run.sh
for i in proc sys dev run; do umount -l squashfs-root/$i; done
rm -rf ${VMPATH}/virtualbox
mkdir  ${VMPATH}/virtualbox
rsync -aH squashfs-root/ ${VMPATH}/virtualbox
ln -s  ${VMPATH}/virtualbox/VirtualBox-${VERSION_FULL}/out/linux.amd64/release/bin   ${VMPATH}/VirtualBox
rm -rf squashfs-root
