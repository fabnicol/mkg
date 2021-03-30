FROM ubuntu:20.04

WORKDIR /root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
          libguestfs-tools \
          qemu-utils \
          uuid \
          dos2unix \
          squashfs-tools \
          curl \
          mkisofs \
          cdrecord \
          util-linux \
          xorriso \
          xz-utils \
          virtualbox \
          rsync \
          curl
              
ENV LIBGUESTFS_BACKEND=direct \
    HOME=/root

ENTRYPOINT ["mkg"]
