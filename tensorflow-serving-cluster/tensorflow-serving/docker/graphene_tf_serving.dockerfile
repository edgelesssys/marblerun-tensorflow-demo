FROM ubuntu:18.04

ENV GRAPHENEDIR=/graphene
ENV ISGX_DRIVER_PATH=${GRAPHENEDIR}/Pal/src/host/Linux-SGX/linux-sgx-driver
ENV WORK_BASE_PATH=${GRAPHENEDIR}/Examples/tensorflow-serving-cluster/tensorflow-serving
ENV MODEL_BASE_PATH=${WORK_BASE_PATH}/models
ENV MODEL_NAME=model
ENV WERROR=1
ENV SGX=1
ENV GRAPHENE_VERSION=303528131c67f58aeee677397ade9593f222ae88

# Enable it to disable debconf warning
# RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Add steps here to set up dependencies
RUN apt-get update \
    && apt-get install -y \
        autoconf \
        bison \
        build-essential \
        curl \
        coreutils \
        git \
        gawk \
        init \
        libnss-mdns \
        lsb-release \
        libnss-myhostname \
        libprotobuf-c-dev \
        libcurl4-openssl-dev \
        python3-protobuf \
        protobuf-c-compiler \
        wget \
    && apt-get install -y --no-install-recommends apt-utils

RUN echo "deb [trusted=yes arch=amd64] https://download.01.org/intel-sgx/sgx_repo/ubuntu bionic main" | tee /etc/apt/sources.list.d/intel-sgx.list \
    && wget -qO - https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | apt-key add -

# Add TensorFlow Serving distribution URI as a package source
RUN echo "deb [arch=amd64] http://storage.googleapis.com/tensorflow-serving-apt stable tensorflow-model-server tensorflow-model-server-universal" | tee /etc/apt/sources.list.d/tensorflow-serving.list \
    && curl https://storage.googleapis.com/tensorflow-serving-apt/tensorflow-serving.release.pub.gpg | apt-key add -

RUN apt-get update

# Install SGX PSW
RUN apt-get install -y libsgx-pce-logic libsgx-ae-qve libsgx-quote-ex libsgx-qe3-logic sgx-aesm-service

# Install DCAP
RUN apt-get install -y libsgx-dcap-ql-dev libsgx-dcap-default-qpl libsgx-dcap-quote-verify-dev

# Clone Graphene and init submodules
RUN git clone https://github.com/oscarlab/graphene.git ${GRAPHENEDIR} \
    && cd ${GRAPHENEDIR} \
    && git checkout ${GRAPHENE_VERSION}

# Create SGX driver for header files
RUN cd ${GRAPHENEDIR}/Pal/src/host/Linux-SGX \
    && git clone https://github.com/intel/SGXDataCenterAttestationPrimitives.git linux-sgx-driver \
    && cd linux-sgx-driver \
    && git checkout DCAP_1.9 && cp -r driver/linux/* .

# Build Graphene-SGX
RUN cd ${GRAPHENEDIR} \
    && make -s -j `nproc` \
    && true

# Translate runtime symlinks to files
RUN for f in $(find ${GRAPHENEDIR}/Runtime -type l); do cp --remove-destination $(realpath $f) $f; done

# Build Secret Provision
RUN cd ${GRAPHENEDIR}/Examples/ra-tls-secret-prov \
    && make -j `nproc` -C ${GRAPHENEDIR}/Pal/src/host/Linux-SGX/tools/ra-tls dcap \
    && make -j `nproc` dcap pf_crypt

# Install the latest tensorflow-model-server
RUN apt-get install -y tensorflow-model-server

# Clean apt cache
RUN apt-get clean all

WORKDIR ${WORK_BASE_PATH}
RUN cp ${GRAPHENEDIR}/Examples/ra-tls-secret-prov/libsecret_prov_attest.so . \
    && cp ${GRAPHENEDIR}/Examples/ra-tls-secret-prov/libsecret_prov_verify_dcap.so . \
    && cp ${GRAPHENEDIR}/Examples/ra-tls-secret-prov/libsgx_util.so . \
    && cp ${GRAPHENEDIR}/Examples/ra-tls-secret-prov/libmbed*.so* . \
    && cp -R ${GRAPHENEDIR}/Examples/ra-tls-secret-prov/certs .

COPY Makefile .
COPY tensorflow_model_server.manifest.template .
COPY tf_serving_entrypoint.sh /usr/bin
COPY sgx_default_qcnl.conf /etc/sgx_default_qcnl.conf

# Expose tensorflow-model-server ports
# gRPC
EXPOSE 8500
# REST
EXPOSE 8501

RUN chmod +x /usr/bin/tf_serving_entrypoint.sh

ENTRYPOINT ["/usr/bin/tf_serving_entrypoint.sh"]
