# syntax=docker/dockerfile:experimental

FROM alpine/git:latest AS pull
RUN git clone https://github.com/edgelesssys/marblerun.git /premain
#RUN git clone https://github.com/edgelesssys/graphene-tensorflow-demo.git /decrypt

FROM ghcr.io/edgelesssys/edgelessrt-dev AS build-premain
COPY --from=pull /premain /premain
WORKDIR /premain/build
RUN cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
RUN make premain-graphene
#COPY --from=pull /decrypt /decrypt
#RUN ertgo build -buildmode=pie -o decrypt-model ./decrypt-model

# Use with fully built graphene as build context
# place Makefile, tf_serving_entrypoint.sh and tensorflow_model_server.manifest.template inside ${LOCAL_GRAPHENEDIR}/Examples/tensorflow-marblerun
FROM ghcr.io/edgelesssys/edgelessrt-deploy:latest
ENV GRAPHENEDIR=/graphene
ENV ISGX_DRIVER_PATH=${GRAPHENEDIR}/Pal/src/host/Linux-SGX/linux-sgx-driver
ENV WORK_BASE_PATH=${GRAPHENEDIR}/Examples/tensorflow-marblerun
ENV MODEL_BASE_PATH=${WORK_BASE_PATH}/models
ENV MODEL_NAME=model
ENV WERROR=1
ENV SGX=1

# Add steps here to set up dependencies
RUN apt-get update \
    && apt-get install -y \
        build-essential \
        autoconf \
        gawk \
        bison \
        wget \
        python3 \
	    curl \
        libcurl4-openssl-dev \
        python3-protobuf \
        libprotobuf-c-dev \
        protobuf-c-compiler \
        python3-pip \
        software-properties-common \
        libsgx-quote-ex-dev \
        libsgx-aesm-launch-plugin \
        tar \
    && apt-get install -y --no-install-recommends apt-utils \
    && python3 -m pip install toml

# Add TensorFlow Serving distribution URI as a package source
RUN echo "deb [arch=amd64] http://storage.googleapis.com/tensorflow-serving-apt stable tensorflow-model-server tensorflow-model-server-universal" | tee /etc/apt/sources.list.d/tensorflow-serving.list \
    && curl https://storage.googleapis.com/tensorflow-serving-apt/tensorflow-serving.release.pub.gpg | apt-key add -

RUN apt-get update

# Install the latest tensorflow-model-server
RUN apt-get install -y tensorflow-model-server

# Clean apt cache
RUN apt-get clean all

# Only add the needed folders to save space
COPY ./Examples/tensorflow-marblerun ${GRAPHENEDIR}/Examples/tensorflow-marblerun
COPY ./LibOS ${GRAPHENEDIR}/LibOS
COPY ./Pal ${GRAPHENEDIR}/Pal
COPY ./python ${GRAPHENEDIR}/python
COPY ./Runtime ${GRAPHENEDIR}/Runtime
COPY ./Scripts ${GRAPHENEDIR}/Scripts

WORKDIR ${WORK_BASE_PATH}

COPY --from=build-premain /premain/build/premain-graphene ${WORK_BASE_PATH}
#COPY --from=build-premain /decrypt/decrypt-model ${WORK_BASE_PATH}
RUN mv ./tf_serving_entrypoint.sh /usr/bin

# Expose tensorflow-model-server ports
# gRPC
RUN unset http_proxy && unset https_proxy
EXPOSE 8500
# REST
EXPOSE 8501
RUN make SGX=1

RUN chmod +x /usr/bin/tf_serving_entrypoint.sh

ENTRYPOINT ["/usr/bin/tf_serving_entrypoint.sh"]
