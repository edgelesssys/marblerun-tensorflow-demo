## Install Dependencies
```bash
sudo apt install libnss-mdns libnss-myhostname
```

```bash
pip3 install -r ./client/requirements.txt
```
(make sure pip is up to date)  



## Building the Docker Image

* Build a working SGX graphene directory (https://graphene.readthedocs.io/en/latest/cloud-deployment.html)

* Copy everything from `./graphene-files` to `<graphene-dir>/Examples/tensorflow-marblerun`

* Run `./build_tf_image.sh <graphene-dir> latest`


## Running as a Container

* Create a mapping of machine B's IP adress (the machine you plan to run the docker image on) to the Tensorflow Serving domain name (127.0.0.1 if you are running on just one machine)
    ```bash
    machineB_ip_addr=XX.XX.XX.XX
    echo "${machineB_ip_addr} grpc.tf-serving.service.com" >> /etc/hosts
    ```

* Start Marblerun
    ```bash
    EDG_COODINATOR_DNS_NAMES=grpc.tf-serving.service.com erthost ${marblerun_dir}/build/coordinator.signed
    export MARBLERUN=grpc.tf-serving.service.com:4433
    ```

* Upload the manifest
    ```bash
    marblerun manifest set tf-server-manifest.json $MARBLERUN
    ```

* Download and convert the model
    ```bash
    ./download_model
    models_abs_dir=`pwd -P`
    python3 ./model_graph_to_saved_model.py --import_path ${models_abs_dir}/resnet50-v15-fp32/resnet50-v15-fp32.pb --export_dir ${models_abs_dir}/resnet50-v15-fp32 --model_version 1 --inputs input --outputs predict
    ```

* Start the Tensorflow Model Server
    ```bash
    ./run_tf_image.sh
    ```

* Get Marbleruns intermediate certificate to connect to the model server
    ```bash
    marblerun certificate intermediate $MARBLERUN -o tensorflow.crt
    ```

* Test the model server
    ```bash
    python3 ./client/resnet_client_grpc.py --url grpc.tf-serving.service.com:8500 --crt tensorflow.crt --batch 1 --cnum 1 --loop 10
    ```


## Running on Kubernetes
* Start the Marblerun coordinator
    ```bash
    marblerun install
    ```

* Wait for Marblerun to setup
    ```bash
    marblerun check
    ```

* Port-forward the client API service to localhost
    ```bash
    kubectl -n marblerun port-forward svc/coordinator-client-api 4433:4433 --address localhost >/dev/null &
    export MARBLERUN=localhost:4433
    ```

* Download and convert the model
    ```bash
    ./download_model
    models_abs_dir=`pwd -P`
    python3 ./model_graph_to_saved_model.py --import_path ${models_abs_dir}/resnet50-v15-fp32/resnet50-v15-fp32.pb --export_dir ${models_abs_dir}/resnet50-v15-fp32 --model_version 1 --inputs input --outputs predict
    ```

* Use `encrypt_model.go` to generate a AES key and encrypt the model
    ```bash
    go run client/encrypt_model.go -k model_key -m models/resnet50-v15-fp32/1/saved_model.pb
    ```

* Create a configmap containing the encrypted model
    ```bash
    kubectl create configmap encrypted-model --from-file=encrypted/saved_model.pb.encrypted
    ```

* Set the content of `model_key` in `tf-server-manifest.json` as the value for `model_key.priv` in `Marbles/tf-server/Parameters/Files`
        ```bash
        aes_key=`cat model_key`
        cat tf-server-manifest.json | sed "s/YOUR_KEY_HERE/${aes_key}/g" > manifest.json
        ```

* Upload the manifest:
    ```bash
    marblerun manifest set manifest.json $MARBLERUN
    ```

* Start the Tensorflow Model Server
    ```bash
    kubectl create -f ./kubernetes/deployment.yaml
    ```

* Get Marblerun's certificate
    ```bash
    marblerun certificate intermediate $MARBLERUN -o tensorflow.crt
    ```

* Submit a request
    ```bash
    python3 ./client/resnet_client_grpc.py --url $MARBLERUN --crt ./tensorflow.crt --batch 1 --cnum 1 --loop 10
    ```