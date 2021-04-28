#!/usr/bin/env bash

set -e

attestation_hosts="localhost:127.0.0.1"
work_base_path=/graphene/Examples/tensorflow-marblerun
ssl_config_file="ssl.cfg"
mount_dir=`pwd -P`
host_ports="8500-8501"
image_id=ghcr.io/edgelesssys/tensorflow-graphene-marble:latest

docker run \
    -it \
    --privileged \
    --device /dev/sgx \
    --network host \
    --add-host=${attestation_hosts} \
    -p ${host_ports}:8500-8501 \
    -v ${mount_dir}/encrypted:${work_base_path}/encrypted \
    -v /var/run/aesmd:/var/run/aesmd \
    -e SGX=1 \
    -e ISGX_DRIVER_PATH=/graphene/Pal/src/host/Linux-SGX/linux-sgx-driver \
    -e EDG_MARBLE_TYPE=tf-server \
    -e EDG_UUID_FILE="/tf_server-uid/uuid-file" \
    -e EDG_MARBLE_COORDINATOR_ADDR=grpc.tf-serving.service.com:2001 \
    -e EDG_MARBLE_DNS_NAMES=grpc.tf-serving.service.com \
    ${image_id}
