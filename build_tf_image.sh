#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# Copyright (C) 2021 Intel Corporation
#                    Yunge Zhu <yunge.zhu@intel.linux.com>

set -e

if [ $# -lt 2 ];
then
    echo "Usage: $0 <grapene-dir> <image tage>"
    exit 1
fi

graphene_dir=$1
tag=$2

# You can remove build-arg http_proxy and https_proxy if your network doesn't need it
proxy_server="" # your http proxy server

docker buildx build \
    -f tensorflow.dockerfile $graphene_dir \
    -t ghcr.io/edgelesssys/tensorflow-graphene-marble:${tag} \
    --build-arg no_proxy=localhost,127.0.0.0/1 \
    --progress plain
