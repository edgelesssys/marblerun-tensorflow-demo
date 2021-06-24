#!/usr/bin/env bash

set -e

attestation_hosts="localhost:127.0.0.1"
work_base_path=/graphene/Examples/tensorflow-marblerun
mount_dir=`pwd -P`
host_ports="8500-8501"
image_id=ghcr.io/edgelesssys/tensorflow-graphene-marble:latest

docker run \
    -it \
    --rm \
    --privileged \
    --device /dev/sgx \
    --network host \
    --add-host=${attestation_hosts} \
    --entrypoint bash \
    -p ${host_ports}:8500-8501 \
    -v ${mount_dir}/models:${work_base_path}/models \
    -v /var/run/aesmd:/var/run/aesmd \
    -e EDG_MARBLE_TYPE=tf-server \
    -e EDG_UUID_FILE="/tf_server-uid/uuid-file" \
    -e EDG_MARBLE_COORDINATOR_ADDR=grpc.tf-serving.service.com:2001 \
    -e EDG_MARBLE_DNS_NAMES=grpc.tf-serving.service.com \
    ${image_id}
