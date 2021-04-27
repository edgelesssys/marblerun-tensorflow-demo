"""
Python client to test the tensorflow REST API
"""
from numpy import uint8, float32
from numpy.random import randint
from requests import post
from json import dumps

# Generate random test data
image_np = randint(0, 255, (1, 224, 224, 3), dtype=uint8).astype(float32)
data = dumps({"signature_name": "serving_default", "instances": image_np.tolist()})
print('Data: {} ... {}'.format(data[:50], data[len(data)-52:]))

# Send data to tensorflow model server and print reponse
headers = {"content-type": "application/json"}
json_response = post('http://grpc.tf-serving.service.com:8501/v1/models/resnet50-v15-fp32:predict', data=data, headers=headers)
print(json_response)

