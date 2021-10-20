#!/usr/bin/env bash

set -e

mount_dir=$(pwd -P)
image_id=ghcr.io/edgelesssys/tensorflow-gramine-marble:latest
coordinator_addr=localhost:2001
tf_dns_names=localhost

docker run \
    -it \
    --rm \
    --device /dev/sgx \
    --network host \
    -v "${mount_dir}/models":/tensorflow-marblerun/models \
    -v /var/run/aesmd:/var/run/aesmd \
    -e EDG_MARBLE_TYPE=tf-server \
    -e EDG_UUID_FILE="/tf_server-uid/uuid-file" \
    -e EDG_MARBLE_COORDINATOR_ADDR=${coordinator_addr} \
    -e EDG_MARBLE_DNS_NAMES=${tf_dns_names} \
    ${image_id}
