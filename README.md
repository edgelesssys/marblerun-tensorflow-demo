# Privacy Preserving Machine Learning Demo using Tensorflow 

This demo is based on the [Graphene Tensorflow Demo](https://github.com/oscarlab/graphene), using Graphene to run a Tensorflow Model Server in an SGX enclave and Marblerun to take care of attestation and secret provisioning.

### Install Dependencies

To run the gRPC client written in python we need some extra libraries. Make sure pip is up to date and run:
```bash
pip3 install -r ./client/requirements.txt
``` 

## Running as a Container

1. Create a mapping of machine B's IP adress (the machine you plan to run the docker image on) to the Tensorflow Serving domain name (127.0.0.1 if you are running on just one machine)
    ```bash
    machineB_ip_addr=XX.XX.XX.XX
    echo "${machineB_ip_addr} grpc.tf-serving.service.com" >> /etc/hosts
    ```

1. Start Marblerun
    ```bash
    EDG_COORDINATOR_DNS_NAMES=grpc.tf-serving.service.com erthost ${marblerun_dir}/build/coordinator-enclave.signed
    export MARBLERUN=grpc.tf-serving.service.com:4433
    ```

1. Download and convert the model
    ```bash
    ./tools/download_model.sh
    models_abs_dir=`pwd -P`
    python3 ./tools/model_graph_to_saved_model.py --import_path ${models_abs_dir}/models/resnet50-v15-fp32/resnet50-v15-fp32.pb --export_dir ${models_abs_dir}/models/resnet50-v15-fp32 --model_version 1 --inputs input --outputs predict
    ```

1. Use `encrypt_model.go` to generate an AES key and encrypt the model. The key will be saved to `model_key` in base64 encoding
    ```bash
    go run ./tools/encrypt_model.go -k model_key -m models/resnet50-v15-fp32/1/saved_model.pb
    ```

1. Set the content of `model_key` in `tf-server-manifest.json` as the value for `model_key.priv` in `Marbles/tf-server/Parameters/Files`
    ```bash
    cat tf-server-manifest.json | sed "s|YOUR_KEY_HERE|$(cat model_key)|g" > manifest.json
    ```

1. Upload the manifest
    ```bash
    marblerun manifest set manifest.json $MARBLERUN
    ```

1. Start the Tensorflow Model Server
    ```bash
    ./tools/run_tf_image.sh
    ```

1. Get Marbleruns intermediate certificate to connect to the model server
    ```bash
    marblerun certificate intermediate $MARBLERUN -o tensorflow.crt
    ```

1. Test the model server using the gRPC client
    ```bash
    python3 ./client/resnet_client_grpc.py --url grpc.tf-serving.service.com:8500 --crt tensorflow.crt --batch 1 --cnum 1 --loop 10
    ```


## Running on Kubernetes
1. Start the Marblerun coordinator
    ```bash
    marblerun install --domain=grpc.tf-serving.service.com
    ```

1. Wait for Marblerun to setup
    ```bash
    marblerun check
    ```

1. Port-forward the client API service to localhost
    ```bash
    kubectl -n marblerun port-forward svc/coordinator-client-api 4433:4433 --address localhost >/dev/null &
    export MARBLERUN=localhost:4433
    ```

1. Download and convert the model
    ```bash
    ./tools/download_model.sh
    models_abs_dir=`pwd -P`
    python3 ./tools/model_graph_to_saved_model.py --import_path ${models_abs_dir}/models/resnet50-v15-fp32/resnet50-v15-fp32.pb --export_dir ${models_abs_dir}/models/resnet50-v15-fp32 --model_version 1 --inputs input --outputs predict
    ```

1. Use `encrypt_model.go` to generate a AES key and encrypt the model
    ```bash
    go run ./tools/encrypt_model.go -k model_key -m models/resnet50-v15-fp32/1/saved_model.pb
    ```

1. Set the content of `model_key` in `tf-server-manifest.json` as the value for `model_key.priv` in `Marbles/tf-server/Parameters/Files`
    ```bash
    cat tf-server-manifest.json | sed "s|YOUR_KEY_HERE|$(cat model_key)|g" > manifest.json
    ```

1. Upload the manifest:
    ```bash
    marblerun manifest set manifest.json $MARBLERUN
    ```

1. Create and add the tensorflow namespace to Marblerun
    ```bash
    kubectl create namespace tensorflow
    marblerun namespace add tensorflow
    ```

1. Start the Tensorflow Model Server
    ```bash
    helm install -f ./kubernetes/values.yaml tensorflow-demo ./kubernetes -n tensorflow
    ```

1. Upload the model to Kubernetes
    ```bash
    kubectl cp ./encrypted/saved_model.pb.encrypted tensorflow/tf-server:/encrypted/saved_model.pb.encrypted
    ```

1. Get Marblerun's certificate
    ```bash
    marblerun certificate intermediate $MARBLERUN -o tensorflow.crt
    ```

1. Submit a request
    ```bash
    python3 ./client/resnet_client_grpc.py --url grpc.tf-serving.service.com:8500 --crt ./tensorflow.crt --batch 1 --cnum 1 --loop 10
    ```

### Cleaning up

1. Remove tensorflow from the cluster
    ```bash
    helm uninstall tensorflow-demo -n tensorflow
    kubectl delete namespace tensorflow
    ```

1. Uninstall Marblerun
    ```bash
    marblerun uninstall
    ```

## Building the Docker Image

*Prerequisite*: Graphene is set up and example applications are working correctly with SGX.

1. Build the model decryption premain
    ```bash
    ertgo build -buildmode=pie -o graphene-files/decrypt-model ./decrypt-model
    ```

1. Assuming you have built Graphene in `/graphene` copy everything from `./graphene-files` into `/graphene/Examples/tensorflow-marblerun`
    ```bash
    mkdir /graphene/Examples/tensorflow-marblerun
    cp ./graphene-files/* /graphene/Examples/tensorflow-marblerun
    ```

1. Next we can build the Docker image:
    ```bash
    docker buildx build --tag ghcr.io/edgelesssys/tensorflow-graphene-marble:latest -f tensorflow.dockerfile /graphene
    ```