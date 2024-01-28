FROM debian:stable

RUN apt-get -qq update \
    && apt-get -q install --assume-yes debootstrap parted openssh-client \
    && apt-get clean

WORKDIR /work

COPY create-raw-image.sh /work/

CMD /work/create-raw-image.sh
