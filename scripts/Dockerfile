# name the portage image
FROM docker.io/gentoo/portage:20210331 as portage

# image is based on stage3-amd64
FROM docker.io/gentoo/stage3:amd64-20210331 

# copy the entire portage volume in
COPY --from=portage /var/db/repos/gentoo /var/db/repos/gentoo

# continue with image build ...
# It may be safer not to update now.
# USE, ACCEPT_KEYWORDS and LICENSE fixes

RUN echo 'USE="-gtk -gtk2 -gtk3 -sandbox -introspection"' \
            >> /etc/portage/make.conf
RUN echo '>=media-libs/libsdl-1.2.15-r9 X'  > new.use
RUN echo '>=media-libs/libglvnd-1.3.2-r2 X' >> new.use
RUN echo '>=x11-libs/libxkbcommon-1.0.3 X'  >> new.use
RUN echo '>=dev-libs/libpcre2-10.35 pcre16' >> new.use
RUN echo 'app-emulation/virtualbox -alsa -debug -doc dtrace headless -java libressl -lvm -opengl -opus pam -pax_kernel -pulseaudio -python -qt5 -sdk udev -vboxwebsrv -vnc' >> new.use
RUN mv new.use /etc/portage/package.use
RUN echo '>=app-emulation/virtualbox-extpack-oracle-6.1.18.142142 PUEL' \
           >> /etc/portage/package.license
RUN mkdir -p /etc/portage/package.accept_keywords && echo '>=sys-apps/sandbox-2.21 ~amd64' > /etc/portage/package.accept_keywords/sandbox
# Notably dev-python/setuptools and a couple of other python dev tools
# will be obsolete. No other cautious way than unmerge/remerge
RUN emerge --unmerge dev-python/* 2>&1 | tee -a log   
RUN emerge -uDN dev-lang/python 2>&1 | tee -a log
RUN emerge -uDN dev-python/setuptools 2>&1 | tee -a log
RUN emerge -u1 portage
RUN emerge -u sys-devel/gcc
RUN emerge gcc-config
RUN gcc-config $(gcc-config -l| wc -l)  && source /etc/profile
RUN emerge glibc binutils 

# Kernel sources must be available for some package merges

RUN emerge gentoo-sources 2>&1 | tee -a log
RUN eselect kernel set 1
RUN eselect profile set 1

# One needs a config file to modules_prepare the kernel sources, 
# which some packages want.

RUN emerge -u dev-vcs/git 2>&1 | tee -a log
RUN git clone --depth=1 https://github.com/fabnicol/mkg.git \
    && cd /mkg \
    && cp -vf .config /usr/src/linux  2>&1 | tee -a log
RUN cd /usr/src/linux && make syncconfig \
    && make modules_prepare  2>&1 | tee -a log 

# However it is useless to build the kernel and @world updates may 
# or may not succeed.
# Merging first util-linux to facilitate possible debugging operations 
# within the container.
# Also, `uuidgen' in util-linux is an MKG dependency

RUN USE=caps emerge -u sys-apps/util-linux 2>&1 | tee -a log

# Although the container is console-only, virtualbox packages 
# have opengl dependencies that cannot be turned off using USE values. 

RUN emerge -uDN virtual/glu x11-apps/mesa-progs mesa 2>&1 | tee -a log
RUN emerge -uDN virtualbox virtualbox-modules virtualbox-extpack-oracle \
      2>&1 | tee -a log

# Common maintenance precautions, might be dispensed with
RUN env-update && source /etc/profile
RUN emerge eix && eix-update

# MKG dependencies now
RUN emerge dos2unix libisofs cdrtools util-linux squashfs-tools \
     2>&1 | tee -a log 
RUN emerge libisoburn 2>&1 | tee -a log

# Now, world updates may be considered anfter sync. 
# Should it fail, reverting would be easier.
# Prefer webrsync over sync, to alleviate rsync server load

RUN emerge-webrsync 2>&1 | tee -a log
RUN emerge -uDN --with-bdeps=y @world 2>&1 | tee -a log \
    && echo "[MSG] Docker image built! Launching depclean..."
RUN emerge --depclean 2>&1 | tee -a log
RUN revdep-rebuild 2>&1 | tee -a log \
      && echo "[MSG] Docker image ready. Check build log."
RUN env-update



