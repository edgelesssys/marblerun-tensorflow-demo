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

When running on kubernetes the graphene ra-tls-secret-prov example is used to distribute secrets / certificates, ideally this would be taken care of my marblerun

The demo is run on a self built kubernetes cluster -> a lot of files are mounted from the host system, including the aesm service.
Ideally we would instead run this on aks using the aesm device plugin instead.
