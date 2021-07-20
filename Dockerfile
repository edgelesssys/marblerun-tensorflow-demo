# syntax=docker/dockerfile:experimental

FROM alpine/git:latest AS pull
RUN git clone https://github.com/edgelesssys/marblerun.git /premain

FROM ghcr.io/edgelesssys/edgelessrt-deploy:latest AS release
RUN apt-get update && apt-get install -y git meson build-essential autoconf gawk bison wget python3 libcurl4-openssl-dev \
    python3-protobuf libprotobuf-c-dev protobuf-c-compiler python3-pip software-properties-common python3-click python3-jinja2 \
    curl
RUN wget -qO- https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | apt-key add
RUN add-apt-repository 'deb [arch=amd64] https://download.01.org/intel-sgx/sgx_repo/ubuntu bionic main'
RUN apt-get install -y libsgx-quote-ex-dev libsgx-aesm-launch-plugin
RUN python3 -m pip install "toml>=0.10"

RUN git clone https://github.com/intel/SGXDataCenterAttestationPrimitives.git /SGXDriver
WORKDIR /SGXDriver
RUN git reset --hard a93785f7d66527aa3bd331ba77b7993f3f9c729b

RUN git clone https://github.com/oscarlab/graphene.git /graphene
WORKDIR /graphene
RUN git reset --hard 202b77ace19e13bffd24959e3a6dc46dc9066ec9

RUN make ISGX_DRIVER_PATH=/SGXDriver/driver/linux/ SGX=1
RUN meson build -Ddirect=disabled -Dsgx=enabled
RUN ninja -C build
RUN ninja -C build install


RUN echo "deb [arch=amd64] http://storage.googleapis.com/tensorflow-serving-apt stable tensorflow-model-server tensorflow-model-server-universal" | tee /etc/apt/sources.list.d/tensorflow-serving.list && curl https://storage.googleapis.com/tensorflow-serving-apt/tensorflow-serving.release.pub.gpg | apt-key add -
RUN apt-get update && apt-get install -y tensorflow-model-server

COPY ./graphene-files/ /graphene/Examples/tensorflow-marblerun/
WORKDIR /graphene/Examples/tensorflow-marblerun
RUN wget https://github.com/edgelesssys/marblerun/releases/latest/download/premain-libos && chmod u+x premain-libos
RUN --mount=type=secret,id=signingkey,dst=/graphene/Pal/src/host/Linux-SGX/signer/enclave-key.pem,required=true \
    make SGX=1 DEBUG=0
ENTRYPOINT ["/graphene/Examples/tensorflow-marblerun/tf_serving_entrypoint.sh"]
