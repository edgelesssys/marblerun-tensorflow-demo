#!/usr/bin/env bash

set -e

unset http_proxy && unset https_proxy

#encryptedTarget=/graphene/Examples/tensorflow-marblerun/models/resnet50-v15-fp32/1/saved_model.pb
#
#if [ "$EDG_DECRYPT_MODEL" = "1" ]; then
#mkdir -p /graphene/Examples/tensorflow-marblerun/encrypted
#until [ -f $encryptedTarget ]
#do
#        echo "No encrypted model found at ${encryptedTarget}. Trying again in 10 seconds"
#        sleep 10
#done
#echo "File found"
#fi

LD_LIBRARY_PATH="/opt/intel/sgx-aesm-service/aesm/:$LD_LIBRARY_PATH" /opt/intel/sgx-aesm-service/aesm/aesm_service

${WORK_BASE_PATH}/pal_loader tensorflow_model_server
