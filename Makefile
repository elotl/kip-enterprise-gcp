TAG ?= latest

include gcloud.Makefile
include var.Makefile

APP_DEPLOYER_IMAGE ?= $(REGISTRY)/elotl-public/kip/deployer:$(TAG)
APP_PARAMETERS ?= { \
  "name": "$(NAME)", \
  "namespace": "$(NAMESPACE)", \
  "imageKipProvider": "$(REGISTRY)/elotl-public/kip:$(TAG)", \
  "imageInitCert": "$(REGISTRY)/elotl-public/kip/init-cert:$(TAG)", \
  "imageKubeProxy": "$(REGISTRY)/elotl-public/kip/kube-proxy:$(TAG)", \
  "imageUbbagent": "$(REGISTRY)/elotl-public/kip/ubbagent:$(TAG)", \
  "reportingSecret": "$(REPORTING_SECRET)" \
}
TESTER_IMAGE ?= $(REGISTRY)/elotl-public/kip/tester:$(TAG)
APP_TEST_PARAMETERS ?= { \
  "imageTester": "$(TESTER_IMAGE)" \
}

# app.Makefile requires several APP_* variables defined above, and thus must be
# included after.
include app.Makefile

app/build:: .build/elotl-public/deployer \
            .build/elotl-public/kip \
            .build/elotl-public/kip/init-cert \
            .build/elotl-public/kip/kube-proxy \
            .build/elotl-public/kip/ubbagent

.build/elotl-public: | .build
	mkdir -p "$@"

.build/elotl-public/deployer: .build/var/APP_DEPLOYER_IMAGE \
                           .build/var/MARKETPLACE_TOOLS_TAG \
                           .build/var/REGISTRY \
                           .build/var/TAG \
                           apptest/deployer/* \
                           apptest/deployer/manifests/* \
                           deployer/* \
                           manifests/* \
                           schema.yaml \
                           | .build/elotl-public
	$(call print_target, $@)
	docker build \
	    --build-arg REGISTRY="$(REGISTRY)/elotl-public/kip" \
	    --build-arg TAG="$(TAG)" \
	    --build-arg MARKETPLACE_TOOLS_TAG="$(MARKETPLACE_TOOLS_TAG)" \
	    --tag "$(APP_DEPLOYER_IMAGE)" \
	    -f deployer/Dockerfile \
	    .
	docker push "$(APP_DEPLOYER_IMAGE)"
	@touch "$@"

.build/elotl-public/tester: .build/var/TESTER_IMAGE
	$(call print_target, $@)
	docker pull cosmintitei/bash-curl
	docker tag cosmintitei/bash-curl "$(TESTER_IMAGE)"
	docker push "$(TESTER_IMAGE)"
	@touch "$@"

# Primary app image, copying public image to local registry.
.build/elotl-public/kip: .build/var/REGISTRY \
                            .build/var/TAG \
                            | .build/elotl-public
	$(call print_target, $@)
	docker pull elotl/kip
	docker tag elotl/kip "$(REGISTRY)/elotl-public/kip:$(TAG)"
	docker push "$(REGISTRY)/elotl-public/kip:$(TAG)"
	@touch "$@"

# Init container image init-cert.
.build/elotl-public/init-cert: init/* \
                       .build/var/REGISTRY \
                       .build/var/TAG \
                       | .build/elotl-public
	$(call print_target, $@)
	docker pull elotl/init-cert
	docker tag elotl/init-cert "$(REGISTRY)/elotl-public/init-cert:$(TAG)"
	docker push "$(REGISTRY)/elotl-public/init-cert:$(TAG)"
	@touch "$@"

# Copy kube-proxy image to $REGISTRY.
.build/elotl-public/mysql: .build/var/REGISTRY \
                        .build/var/TAG \
                        | .build/elotl-public
	$(call print_target, $@)
	docker pull k8s.gcr.io/kube-proxy:v1.18.3
	docker tag k8s.gcr.io/kube-proxy:v1.18.3 "$(REGISTRY)/elotl-public/kube-proxy:$(TAG)"
	docker push "$(REGISTRY)/elotl-public/init-cert:$(TAG)"
	@touch "$@"

# Copy ubbagent image to $REGISTRY.
.build/elotl-public/ubbagent: .build/var/REGISTRY \
                           .build/var/TAG \
                           | .build/elotl-public
	$(call print_target, $@)
	docker pull "gcr.io/cloud-marketplace-tools/metering/ubbagent"
	docker tag "gcr.io/cloud-marketplace-tools/metering/ubbagent" "$(REGISTRY)/elotl-public/elotl-public/ubbagent:$(TAG)"
	docker push "$(REGISTRY)/elotl-public/elotl-public/ubbagent:$(TAG)"
	@touch "$@"
