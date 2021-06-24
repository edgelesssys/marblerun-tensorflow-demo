# syntax=docker/dockerfile:experimental

FROM alpine/git:latest AS pull
RUN git clone https://github.com/edgelesssys/marblerun.git /premain

FROM ghcr.io/edgelesssys/edgelessrt-dev AS build-premain
COPY --from=pull /premain /premain
WORKDIR /premain/build
RUN cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
RUN make premain-graphene

FROM ghcr.io/edgelesssys/edgelessrt-deploy:latest AS release
RUN apt-get update && apt-get install -y git meson build-essential autoconf gawk bison wget python3 libcurl4-openssl-dev \
    python3-protobuf libprotobuf-c-dev protobuf-c-compiler python3-pip software-properties-common python3-click python3-jinja2 \
    linux-headers-5.4.0-1051-azure curl
RUN wget -qO- https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | apt-key add
RUN add-apt-repository 'deb [arch=amd64] https://download.01.org/intel-sgx/sgx_repo/ubuntu bionic main'
RUN apt-get install -y libsgx-quote-ex-dev libsgx-aesm-launch-plugin
RUN python3 -m pip install "toml>=0.10"

RUN git clone https://github.com/oscarlab/graphene.git /graphene
WORKDIR /graphene
RUN git reset --hard b37ac75efec0c1183fd42340ce2d3e04dcfb3388

RUN make ISGX_DRIVER_PATH=/usr/src/linux-headers-5.4.0-1051-azure/arch/x86/ SGX=1
RUN meson build -Ddirect=disabled -Dsgx=enabled
RUN ninja -C build
RUN ninja -C build install

RUN echo "deb [arch=amd64] http://storage.googleapis.com/tensorflow-serving-apt stable tensorflow-model-server tensorflow-model-server-universal" | tee /etc/apt/sources.list.d/tensorflow-serving.list && curl https://storage.googleapis.com/tensorflow-serving-apt/tensorflow-serving.release.pub.gpg | apt-key add -
RUN apt-get update && apt-get install -y tensorflow-model-server

COPY --from=build-premain /premain/build/premain-graphene /graphene/Examples/tensorflow-marblerun/
COPY graphene-files/ /graphene/Examples/tensorflow-marblerun/
WORKDIR /graphene/Examples/tensorflow-marblerun
RUN --mount=type=secret,id=signingkey,dst=/graphene/Pal/src/host/Linux-SGX/signer/enclave-key.pem,required=true \
    make SGX=1 DEBUG=1
ENTRYPOINT ["/graphene/Examples/tensorflow-marblerun/tetf_serving_entrypoint.sh"]
