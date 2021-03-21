FROM ubuntu:20.04
MAINTAINER Fabrice Nicol <fabrnicol@gmail.com>

WORKDIR /root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
          libguestfs-tools \
          qemu-utils \
          linux-image-generic \
          uuid \
          dos2unix \
          squashfs-tools \
          curl \
          mkisofs \
          cdrecord \
          util-linux \
          xorriso \
          xz-utils \
          virtualbox

ENV LIBGUESTFS_BACKEND=direct \
    HOME=/root

ENTRYPOINT ["mkg"]
