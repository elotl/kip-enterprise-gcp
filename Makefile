TAG ?= latest
ELOTL_KIP_TAG ?= v0.0.6
ELOTL_DEBUG_TAG ?= latest
ELOTL_INIT_CERT_TAG ?= latest
ELOTL_IMAGE_CACHE_CONTROLLER_TAG ?= latest
KUBE_PROXY_TAG ?= v1.18.3
UBB_AGENT_TAG ?= latest

include gcloud.Makefile
include var.Makefile

REPORTING_SECRET ?= gs://cloud-marketplace-tools/reporting_secrets/fake_reporting_secret.yaml
APP_DEPLOYER_IMAGE ?= $(REGISTRY)/deployer:$(TAG)
APP_PARAMETERS ?= { \
  "name": "$(NAME)", \
  "namespace": "$(NAMESPACE)", \
  "imageKipProvider": "$(REGISTRY):$(TAG)", \
  "imageInitCert": "$(REGISTRY)/init-cert:$(TAG)", \
  "imageKubeProxy": "$(REGISTRY)/kube-proxy:$(TAG)", \
  "imageUbbagent": "$(REGISTRY)/ubbagent:$(TAG)", \
  "reportingSecret": "$(REPORTING_SECRET)" \
}
TESTER_IMAGE ?= $(REGISTRY)/tester:$(TAG)
APP_TEST_PARAMETERS ?= { \
  "imageTester": "$(TESTER_IMAGE)" \
}
APP_EXTRA_OPTIONS ?= ""

# app.Makefile requires several APP_* variables defined above, and thus must be
# included after.
include app.Makefile

app/build:: .build/kip/deployer \
            .build/kip/init-cert \
			.build/kip/kip \
            .build/kip/kube-proxy \
            .build/kip/ubbagent \
            .build/kip/image-cache-controller \
            .build/kip/tester \

.build/kip: | .build
	mkdir -p "$@"

.build/kip/deployer: .build/var/APP_DEPLOYER_IMAGE \
                           .build/var/MARKETPLACE_TOOLS_TAG \
                           .build/var/REGISTRY \
                           .build/var/TAG \
                           apptest/deployer/* \
                           apptest/deployer/manifest/* \
                           deployer/* \
                           kustomize/* \
                           manifest/* \
                           schema.yaml \
                           | .build/kip
	$(call print_target, $@)
	docker build \
	    --build-arg REGISTRY="$(REGISTRY)" \
	    --build-arg TAG="$(TAG)" \
	    --build-arg MARKETPLACE_TOOLS_TAG="$(MARKETPLACE_TOOLS_TAG)" \
	    --tag "$(APP_DEPLOYER_IMAGE)" \
	    -f deployer/Dockerfile \
	    .
	docker push "$(APP_DEPLOYER_IMAGE)"
	@touch "$@"

# Tester image.
.build/kip/tester: .build/var/TESTER_IMAGE
	$(call print_target, $@)
	docker pull elotl/debug:$(ELOTL_DEBUG_TAG)
	docker tag elotl/debug:$(ELOTL_DEBUG_TAG) "$(TESTER_IMAGE)"
	docker push "$(TESTER_IMAGE)"
	@touch "$@"

# Primary app image, copying public image to local registry.
.build/kip/kip: .build/var/REGISTRY \
                            .build/var/TAG \
                            | .build/kip
	$(call print_target, $@)
	docker pull elotl/kip:$(ELOTL_KIP_TAG)
	docker tag elotl/kip:$(ELOTL_KIP_TAG) "$(REGISTRY):$(TAG)"
	docker push "$(REGISTRY):$(TAG)"
	@touch "$@"

# Init container image init-cert.
.build/kip/init-cert: .build/var/REGISTRY \
                       .build/var/TAG \
                       | .build/kip
	$(call print_target, $@)
	docker pull elotl/init-cert:$(ELOTL_INIT_CERT_TAG)
	docker tag elotl/init-cert:$(ELOTL_INIT_CERT_TAG) "$(REGISTRY)/init-cert:$(TAG)"
	docker push "$(REGISTRY)/init-cert:$(TAG)"
	@touch "$@"

# Copy kube-proxy image to $REGISTRY.
.build/kip/kube-proxy: .build/var/REGISTRY \
                        .build/var/TAG \
                        | .build/kip
	$(call print_target, $@)
	docker pull k8s.gcr.io/kube-proxy:$(KUBE_PROXY_TAG)
	docker tag k8s.gcr.io/kube-proxy:$(KUBE_PROXY_TAG) "$(REGISTRY)/kube-proxy:$(TAG)"
	docker push "$(REGISTRY)/kube-proxy:$(TAG)"
	@touch "$@"

# Copy ubbagent image to $REGISTRY.
.build/kip/ubbagent: .build/var/REGISTRY \
                           .build/var/TAG \
                           | .build/kip
	$(call print_target, $@)
	docker pull gcr.io/cloud-marketplace-tools/metering/ubbagent:$(UBB_AGENT_TAG)
	docker tag gcr.io/cloud-marketplace-tools/metering/ubbagent:$(UBB_AGENT_TAG) \
		"$(REGISTRY)/ubbagent:$(TAG)"
	docker push "$(REGISTRY)/ubbagent:$(TAG)"
	@touch "$@"

# Copy image-cache-controller image to $REGISTRY.
.build/kip/image-cache-controller: .build/var/REGISTRY \
                           .build/var/TAG \
                           | .build/kip
	$(call print_target, $@)
	docker pull gcr.io/elotl-kip/image-cache-controller:$(ELOTL_IMAGE_CACHE_CONTROLLER_TAG)
	docker tag gcr.io/elotl-kip/image-cache-controller:$(ELOTL_IMAGE_CACHE_CONTROLLER_TAG) \
		"$(REGISTRY)/image-cache-controller:$(TAG)"
	docker push "$(REGISTRY)/image-cache-controller:$(TAG)"
	@touch "$@"
