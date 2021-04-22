#!/usr/bin/env bash

set -e

attestation_hosts="localhost:127.0.0.1"
work_base_path=/graphene/Examples/tensorflow-serving-cluster/tensorflow-serving
ssl_config_file="ssl.cfg"
mount_dir=`pwd -P`
host_ports="8500-8501"
image_id=graphene_tf_serving:latest

docker run \
    -it \
    --privileged \
    --device /dev/sgx \
    --network host \
    --add-host=${attestation_hosts} \
    -p ${host_ports}:8500-8501 \
    -v ${mount_dir}/models:/models \
    -v ${mount_dir}/ssl_configure/${ssl_config_file}:${work_base_path}/${ssl_config_file} \
    -v /var/run/aesmd/aesm:/var/run/aesmd/aesm \
    -e EDG_MARBLE_TYPE=tf_server \
    -e EDG_UUID_FILE="/tf_server-uid/uuid-file" \
    -e EDG_MARBLE_COORDINATOR_ADDR=localhost:2001 \
    -e EDG_MARBLE_DNS_NAMES=grpc.tf-serving.service.com \
    ${image_id}