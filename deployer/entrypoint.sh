#!/usr/bin/env bash

set -exuo pipefail

envsubst < /data/manifests/application/application.yaml.tmpl > /data/manifests/application/application.yaml
kubectl apply -f /data/manifests/application/

envsubst < /data/manifests/kustomize/kustomization.yaml.tmpl > /data/manifests/kustomize/kustomization.yaml
kustomize build /data/manifests/kustomize | kubectl apply -f -
