TAG ?= latest
ELOTL_KIP_TAG ?= v0.0.6
ELOTL_INIT_CERT_TAG ?= latest
KUBE_PROXY_TAG ?= v1.18.3
UBB_AGENT_TAG ?= latest

include gcloud.Makefile
include var.Makefile

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

# app.Makefile requires several APP_* variables defined above, and thus must be
# included after.
include app.Makefile

app/build:: .build/elotl-public/kip \
            .build/elotl-public/kip/deployer \
            .build/elotl-public/kip/init-cert \
            .build/elotl-public/kip/kube-proxy \
            .build/elotl-public/kip/ubbagent

.build/kip: | .build
	mkdir -p "$@"

.build/kip/deployer: .build/var/APP_DEPLOYER_IMAGE \
                           .build/var/MARKETPLACE_TOOLS_TAG \
                           .build/var/REGISTRY \
                           .build/var/TAG \
                           apptest/deployer/* \
                           apptest/deployer/manifest/* \
                           deployer/* \
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

.build/kip/tester: .build/var/TESTER_IMAGE
	$(call print_target, $@)
	docker pull cosmintitei/bash-curl
	docker tag cosmintitei/bash-curl "$(TESTER_IMAGE)"
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
	docker push "$(REGISTRY)/init-cert:$(TAG)"
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
