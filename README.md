# Install Dependencies

Install Docker engine  
Install SGX Drivers  
Install Graphene  

```bash
sudo apt install libnss-mdns libnss-myhostname
```

```bash
pip3 install -r ./tensorflow-serving-cluster/tensorflow-serving/client/requirements.txt
```
(make sure pip is up to date)  

Current version has dependency issues:   
tensorflow 2.4.0 requires grpcio at version 1.32, but requirments.txt specifies grpcio at version 1.34. Also `resnet_client_grpc.py` requires grcpio to be at a version higher than 1.32.  
To fix this, first install at 1.32 using `requirments.txt` then manually install 1.34 using pip `python3 -m pip install grpcio~=1.34.0`  

The demo sets tensorflow to start with a LOT of memory and cpu resources (32G sgx memory, 32 memory & cpu in kubernetes), this might be overkill in which case we can reduce it, or needed in which case it might be a problem.  
We need ~256 threads for tensorflow model server to not crash. Using a 8GiB azure VM providing the graphene image with more than 2G of memory will crash the container (oom), execution is therefore rather slow.

When running on kubernetes the graphene ra-tls-secret-prov example is used to distribute secrets / certificates, ideally this would be taken care of my marblerun  

The demo is run on a self built kubernetes cluster -> a lot of files are mounted from the host system, including the aesm service.
Ideally we would instead run this on aks using the aesm device plugin instead.


## Building the Docker Image

* Build a working SGX graphene directory (https://graphene.readthedocs.io/en/latest/cloud-deployment.html)

* Copy everything from `./graphene-files` to `<graphene-dir>/Examples/tensorflow-serving-cluster/tensorflow-serving`

* Run `build_graphene_tf_serving_image.sh`

## Running as a Container

* Start the Marblerun coordinator

* Uploade the manifest:
    ```bash
    marblerun manifest set tf-server-manifest.json [--insecure]
    ```

* Download and convert the model
    ```bash
    ./download_model
    models_abs_dir=`pwd -P`
    python3 ./model_graph_to_saved_model.py --import_path ${models_abs_dir}/resnet50-v15-fp32/resnet50-v15-fp32.pb --export_dir ${models_abs_dir}/resnet50-v15-fp32 --model_version 1 --inputs input --outputs predict
    ```

* Start the container
    ```bash
    ./docker_run.sh
    ```
