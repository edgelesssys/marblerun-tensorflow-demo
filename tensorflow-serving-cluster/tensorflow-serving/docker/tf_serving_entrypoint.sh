#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-or-later
# Copyright (C) 2021 Intel Corporation
#                    Yunge Zhu <yunge.zhu@intel.linux.com>

set -e

unset http_proxy && unset https_proxy

# enclave-key.pem for nonattestation
openssl genrsa -3 -out enclave-key.pem 3072
mv ./enclave-key.pem ${GRAPHENEDIR}/Pal/src/host/Linux-SGX/signer/enclave-key.pem

cd ${WORK_BASE_PATH}

make -j `nproc`

LD_LIBRARY_PATH="/opt/intel/sgx-aesm-service/aesm/:$LD_LIBRARY_PATH" /opt/intel/sgx-aesm-service/aesm/aesm_service

${WORK_BASE_PATH}/pal_loader tensorflow_model_server \
    --model_name=${model_name} \
    --model_base_path=/models/${model_name} \
    --port=8500 \
    --rest_api_port=8501 \
    --enable_model_warmup=true \
    --flush_filesystem_caches=false \
    --enable_batching=${enable_batching} \
    --ssl_config_file=${ssl_config_file} \
    --rest_api_num_threads=${rest_api_num_threads} \
    --tensorflow_session_parallelism=${session_parallelism} \
    --tensorflow_intra_op_parallelism=${intra_op_parallelism} \
    --tensorflow_inter_op_parallelism=${inter_op_parallelism} \
    --file_system_poll_wait_seconds=${file_system_poll_wait_seconds}
