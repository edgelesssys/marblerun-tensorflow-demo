import tensorflow as tf
from tensorflow import keras

# Helper libraries
import numpy as np
import matplotlib.pyplot as plt
import os
import subprocess

def show(img, title):
    plt.figure()
    plt.axis('off')
    plt.title('\n\n{}'.format(title), fontdict={'size': 16})
    print(title)
    plt.imsave('sample_image.png', img)#test_images[idx].reshape(244,244))

print('TensorFlow version: {}'.format(tf.__version__))
#fashion_mnist = keras.datasets.fashion_mnist
#(_, _), (test_images, test_labels) = fashion_mnist.load_data()
#test_images = test_images / 255.0
#test_images = test_images.reshape(test_images.shape[0], 28, 28, 1)
#class_names = ['T-shirt/top', 'Trouser', 'Pullover', 'Dress', 'Coat',
#               'Sandal', 'Shirt', 'Sneaker', 'Bag', 'Ankle boot']
#print('\ntest_images.shape: {}, of {}'.format(test_images.shape, test_images.dtype))

image_np = np.random.randint(0, 255, (1, 224, 224, 3), dtype=np.uint8).astype(np.float32)
show(image_np, 'Random Image')
#import random
#rando = random.randint(0,len(test_images)-1)
#show(image_np, 'An Example Image: {}'.format(class_names[test_labels[rando]]))

import json
data = json.dumps({"signature_name": "serving_default", "instances": image_np.tolist()})
print('Data: {} ... {}'.format(data[:50], data[len(data)-52:]))

import requests
headers = {"content-type": "application/json"}
json_response = requests.post('http://grpc.tf-serving.service.com:8501/v1/models/resnet50-v15-fp32:predict', data=data, headers=headers)
print(json_response)

#predictions = json.loads(json_response.text)['predictions']

#show(image_np, 'The model thought {}'.format(predictions[0]))
