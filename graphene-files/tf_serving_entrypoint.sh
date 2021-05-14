#!/usr/bin/env bash

set -e

unset http_proxy && unset https_proxy

LD_LIBRARY_PATH="/opt/intel/sgx-aesm-service/aesm/:$LD_LIBRARY_PATH" /opt/intel/sgx-aesm-service/aesm/aesm_service

${WORK_BASE_PATH}/pal_loader tensorflow_model_server
