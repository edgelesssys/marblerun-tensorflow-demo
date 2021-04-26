#!/usr/bin/env bash

set -e

unset http_proxy && unset https_proxy

## enclave-key.pem for nonattestation
#openssl genrsa -3 -out enclave-key.pem 3072
#mv ./enclave-key.pem ${GRAPHENEDIR}/Pal/src/host/Linux-SGX/signer/enclave-key.pem
#
#cd ${WORK_BASE_PATH}

#make -j `nproc`

LD_LIBRARY_PATH="/opt/intel/sgx-aesm-service/aesm/:$LD_LIBRARY_PATH" /opt/intel/sgx-aesm-service/aesm/aesm_service

${WORK_BASE_PATH}/pal_loader tensorflow_model_server
