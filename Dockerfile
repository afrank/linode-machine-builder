FROM debian:stable

RUN apt-get -qq update \
    && apt-get -q install --assume-yes debootstrap dosfstools parted openssh-client rsync pigz \
    && apt-get clean

RUN touch /usr/local/bin/udevadm \
    && chmod +x /usr/local/bin/udevadm

WORKDIR /work

CMD /work/create-raw-image.sh
