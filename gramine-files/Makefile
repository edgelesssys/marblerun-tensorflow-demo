# Building the manifest for TF-Serving:
#
# - make          Build for SGX, TF-Serving with Release build
# - make DEBUG=1  Build for SGX, TF-Serving with Debug build, Gramine with debug output
#
# Use `make clean` to remove Gramine-generated files.

ARCH_LIBDIR ?= /lib/$(shell $(CC) -dumpmachine)
THIS_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

# Relative path to Gramine root and key for enclave signing
SGX_SIGNER_KEY ?= $(THIS_DIR)/signing_key.pem

TF-SERVING_DIR := /usr/bin

ifeq ($(DEBUG),1)
GRAMINE = debug
else
GRAMINE_LOG_LEVEL = error
endif

.PHONY: all
all: tensorflow_model_server tensorflow_model_server.manifest.sgx tensorflow_model_server.sig tensorflow_model_server.token

tensorflow_model_server.manifest: tensorflow_model_server.manifest.template
	gramine-manifest \
		-Dlog_level=$(GRAMINE_LOG_LEVEL) \
		-Darch_libdir=$(ARCH_LIBDIR) \
		-Dtf_serving_dir=$(TF-SERVING_DIR) \
		-Dtf_serving_dir_abspath=$(abspath $(TF-SERVING_DIR)) \
		$< > $@

# Generating the SGX-specific manifest (tensorflow_model_server.manifest.sgx), the enclave signature,
# and the token for enclave initialization.
tensorflow_model_server.manifest.sgx: tensorflow_model_server.manifest
	gramine-sgx-sign \
		--key $(SGX_SIGNER_KEY) \
		--manifest tensorflow_model_server.manifest \
		--output tensorflow_model_server.manifest.sgx

tensorflow_model_server.sig: tensorflow_model_server.manifest.sgx

tensorflow_model_server.token: tensorflow_model_server.sig
	gramine-sgx-get-token --sig $< --output $@

tensorflow_model_server:
	ln -s $(TF-SERVING_DIR)/tensorflow_model_server $@

.PHONY: clean
clean:
	$(RM) *.manifest *.manifest.sgx *.token *.sig tensorflow_model_server
