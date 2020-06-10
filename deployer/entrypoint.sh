#!/usr/bin/env bash

set -exuo pipefail

kubectl get namespace $NAMESPACE || kubectl create namespace $NAMESPACE

envsubst < /data/manifest/application/application.yaml.tmpl > /data/manifest/application/application.yaml
envsubst < /data/manifest/kustomize/kustomization.yaml.tmpl > /data/manifest/kustomize/kustomization.yaml
cp /data/manifest/application/*.yaml /data/manifest/kustomize/*.yaml /data/
rm -rf /data/manifest/application/ /data/manifest/kustomize/

/bin/deploy.sh
