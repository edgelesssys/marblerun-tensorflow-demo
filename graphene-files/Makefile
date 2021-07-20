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

ifeq ($(DEBUG),1)
GRAPHENE_LOG_LEVEL = debug
else
GRAPHENE_LOG_LEVEL = error
endif

.PHONY: all
all: tensorflow_model_server tensorflow_model_server.manifest

ifeq ($(SGX),1)
all: tensorflow_model_server tensorflow_model_server.manifest.sgx tensorflow_model_server.sig tensorflow_model_server.token
endif

include $(GRAPHENE_DIR)/Scripts/Makefile.configs

tensorflow_model_server.manifest: tensorflow_model_server.manifest.template
	graphene-manifest \
		-Dlog_level=$(GRAPHENE_LOG_LEVEL) \
		-Darch_libdir=$(ARCH_LIBDIR) \
		-Dtf_serving_dir=$(TF-SERVING_DIR) \
		-Dtf_serving_dir_abspath=$(abspath $(TF-SERVING_DIR)) \
		$< >$@

# Generating the SGX-specific manifest (tensorflow_model_server.manifest.sgx), the enclave signature,
# and the token for enclave initialization.
tensorflow_model_server.manifest.sgx: tensorflow_model_server.manifest
	graphene-sgx-sign \
		--key $(SGX_SIGNER_KEY) \
		--manifest tensorflow_model_server.manifest \
		--output tensorflow_model_server.manifest.sgx

tensorflow_model_server.sig: tensorflow_model_server.manifest.sgx

tensorflow_model_server.token: tensorflow_model_server.sig
	graphene-sgx-get-token --sig $< --output $@

tensorflow_model_server:
	ln -s $(TF-SERVING_DIR)/tensorflow_model_server $@

.PHONY: clean
clean:
	$(RM) *.manifest *.manifest.sgx *.token *.sig tensorflow_model_server
