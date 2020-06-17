# Base repo and the tag to build and push.
REGISTRY ?= gcr.io/elotl-public/kip-enterprise
TAG ?= latest

# Tags for source images.
ELOTL_KIP_TAG ?= v0.0.7
ELOTL_INIT_CERT_TAG ?= v0.0.7
ELOTL_IMAGE_CACHE_CONTROLLER_TAG ?= v0.0.5
ELOTL_KIP_UBBAGENT_TAG ?= v0.0.3
KUBE_PROXY_TAG ?= v1.18.3

# Defaults for testing.
NAME ?= elotl
NAMESPACE ?= kip

include gcloud.Makefile
include var.Makefile

REPORTING_SECRET ?= gs://cloud-marketplace-tools/reporting_secrets/fake_reporting_secret.yaml
APP_DEPLOYER_IMAGE ?= $(REGISTRY)/deployer:$(TAG)
IMAGE_CACHE_CONTROLLER_REPLICAS ?= 0
APP_PARAMETERS ?= { \
  "name": "$(NAME)", \
  "namespace": "$(NAMESPACE)", \
  "imageKipProvider": "$(REGISTRY):$(TAG)", \
  "imageInitCert": "$(REGISTRY)/init-cert:$(TAG)", \
  "imageKubeProxy": "$(REGISTRY)/kube-proxy:$(TAG)", \
  "imageUbbagent": "$(REGISTRY)/ubbagent:$(TAG)", \
  "reportingSecret": "$(REPORTING_SECRET)", \
  "nfsVolumeEndpoint": "$(NFS_VOLUME_ENDPOINT)", \
  "imageCacheControllerReplicas": $(IMAGE_CACHE_CONTROLLER_REPLICAS) \
}
TESTER_IMAGE ?= elotl/debug:latest
APP_TEST_PARAMETERS ?= { \
  "imageTester": "$(TESTER_IMAGE)" \
}
IMAGE_PULL_SECRET ?= ""

# app.Makefile requires several APP_* variables defined above, and thus must be
# included after.
include app.Makefile

app/build:: .build/kip/deployer \
            .build/kip/init-cert \
			.build/kip/kip \
            .build/kip/kube-proxy \
            .build/kip/ubbagent \
            .build/kip/image-cache-controller

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
	docker pull gcr.io/elotl-kip/kip-ubbagent:$(UBB_AGENT_TAG)
	docker tag gcr.io/elotl-kip/kip-ubbagent:$(UBB_AGENT_TAG) \
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
