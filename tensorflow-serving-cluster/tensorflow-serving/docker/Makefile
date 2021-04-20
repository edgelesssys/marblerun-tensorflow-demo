# Building the manifest for TF-Serving:
#
# - make                Build for Linux, TF-Serving with Release build
# - make DEBUG=1        Build for Linux, TF-Serving with Debug build, Graphene with debug output
# - make SGX=1          Build for SGX, TF-Serving with Release build
# - make SGX=1 DEBUG=1  Build for SGX, TF-Serving with Debug build, Graphene with debug output
#
# Use `make clean` to remove Graphene-generated files.
#
# Use `make distclean` to further remove the TF-Serving source and installation.

THIS_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

# Relative path to Graphene root and key for enclave signing
GRAPHENE_DIR ?= /graphene
SGX_SIGNER_KEY ?= $(GRAPHENE_DIR)/Pal/src/host/Linux-SGX/signer/enclave-key.pem

TF-SERVING_DIR := /usr/bin
MODEL_DIR := $(GRAPHENE_DIR)/Examples/tensorflow-serving-cluster/tensorflow-serving/models

ifeq ($(DEBUG),1)
GRAPHENE_DEBUG = inline
TF-SERVING_BUILD = Debug
else
GRAPHENE_DEBUG = none
TF-SERVING_BUILD = Release
endif

.PHONY: all
all: tensorflow_model_server tensorflow_model_server.manifest pal_loader

ifeq ($(SGX),1)
all: tensorflow_model_server tensorflow_model_server.manifest.sgx tensorflow_model_server.sig tensorflow_model_server.token
endif

include $(GRAPHENE_DIR)/Scripts/Makefile.configs

tensorflow_model_server.manifest: tensorflow_model_server.manifest.template
	sed -e 's|$$(GRAPHENE_DIR)|'"$(GRAPHENE_DIR)"'|g' \
	    -e 's|$$(GRAPHENE_DEBUG)|'"$(GRAPHENE_DEBUG)"'|g' \
	    -e 's|$$(TF-SERVING_DIR)|'"$(TF-SERVING_DIR)"'|g' \
	    -e 's|$$(TF-SERVING_DIR_ABSPATH)|'"$(abspath $(TF-SERVING_DIR))"'|g' \
	    -e 's|$$(MODEL_DIR)|'"$(MODEL_DIR)"'|g' \
	    -e 's|$$(TF-SERVING_BUILD)|'"$(TF-SERVING_BUILD)"'|g' \
	    -e 's|$$(ARCH_LIBDIR)|'"$(ARCH_LIBDIR)"'|g' \
	    $< > $@

# Generating the SGX-specific manifest (tensorflow_model_server.manifest.sgx), the enclave signature,
# and the token for enclave initialization.
tensorflow_model_server.manifest.sgx: tensorflow_model_server.manifest
	$(GRAPHENE_DIR)/Pal/src/host/Linux-SGX/signer/pal-sgx-sign \
		-exec tensorflow_model_server \
		-libpal $(GRAPHENE_DIR)/Runtime/libpal-Linux-SGX.so \
		-key $(SGX_SIGNER_KEY) \
		-manifest $< -output $@

tensorflow_model_server.sig: tensorflow_model_server.manifest.sgx

tensorflow_model_server.token: tensorflow_model_server.sig
	$(GRAPHENE_DIR)/Pal/src/host/Linux-SGX/signer/pal-sgx-get-token -sig $< -output $@

tensorflow_model_server:
	ln -s $(TF-SERVING_DIR)/tensorflow_model_server $@

pal_loader:
	ln -s $(GRAPHENE_DIR)/Runtime/pal_loader $@

.PHONY: clean
clean:
	$(RM) *.manifest *.manifest.sgx *.token *.sig tensorflow_model_server pal_loader
