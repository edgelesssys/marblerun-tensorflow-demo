FROM alpine/git:latest AS pull_marblerun
RUN git clone https://github.com/edgelesssys/marblerun.git /marblerun

FROM ghcr.io/edgelesssys/edgelessrt-dev AS build-premain
COPY --from=pull_marblerun /marblerun /premain
WORKDIR /premain/build
RUN cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
RUN make premain-libos

FROM gramineproject/gramine:v1.4 AS release
RUN apt update && \
    apt install -y libssl-dev gnupg software-properties-common

RUN apt-key adv --fetch-keys https://storage.googleapis.com/tensorflow-serving-apt/tensorflow-serving.release.pub.gpg && \
    add-apt-repository 'deb [arch=amd64] http://storage.googleapis.com/tensorflow-serving-apt stable tensorflow-model-server tensorflow-model-server-universal'

RUN apt-get update && apt-get install -y \
    wget \
    libsgx-quote-ex-dev \
    libsgx-aesm-launch-plugin \
    libsgx-dcap-default-qpl \
    build-essential \
    libprotobuf-c-dev \
    libstdc++6 \
    tensorflow-model-server && \
    apt-get clean -y && apt-get autoclean -y && apt-get autoremove -y

COPY ./gramine-files/ /tensorflow-marblerun
COPY --from=build-premain /premain/build/premain-libos /tensorflow-marblerun
WORKDIR /tensorflow-marblerun
RUN --mount=type=secret,id=signingkey,dst=/tensorflow-marblerun/signing_key.pem,required=true \
    make DEBUG=0

ENTRYPOINT [ "/tensorflow-marblerun/start.sh" ]
