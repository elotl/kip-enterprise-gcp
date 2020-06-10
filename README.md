# Overview

Kip is a Virtual Kubelet provider that allows a Kubernetes cluster to
transparently launch pods onto their own cloud instances. The kip pod is run on
a cluster and will create a virtual Kubernetes node in the cluster. When a pod
is scheduled onto the Virtual Kubelet, Kip starts a right-sized cloud instance
for the pod’s workload and dispatches the pod onto the instance. When the pod
is finished running, the cloud instance is terminated. We call these cloud
instances “cells”.

When workloads run on Kip, your cluster size naturally scales with the cluster
workload, pods are strongly isolated from each other and the user is freed from
managing worker nodes and strategically packing pods onto nodes. This results
in lower cloud costs, improved security and simpler operational overhead.

# Installation

## Quick install with Google Cloud Marketplace

You can install Kip to a Google Kubernetes Engine cluster using Google Cloud
Marketplace. Follow the on-screen instructions: [TODO: fix link](https://console.cloud.google.com/marketplace/details/elotl/kip-enterprise).

## Command line instructions

Follow these instructions to install Kip from the command line.

### Prerequisites

- A GKE cluster
- kubectl >= 1.14, configured to access the GKE cluster
- kustomize >= 3.0.0

### Commands

Set environment variables (modify if necessary):
```
export APP_INSTANCE_NAME=kip
export NAMESPACE=kube-system
export IMAGE_KIP_PROVIDER=launcher.gcr.io/elotl-public/kip:XXX
export IMAGE_KUBE_PROXY=launcher.gcr.io/elotl-public/kip/kube-proxy:XXX
export IMAGE_IMAGE_CACHE_CONTROLLER=launcher.gcr.io/elotl-public/kip/image-cache-controller:XXX
export IMAGE_UBBAGENT=launcher.gcr.io/elotl-public/kip/ubbagent:XXX
```

Expand manifest template:
```
cat manifests/kustomization.yaml.tmpl | envsubst > manifests/kustomization.yaml
```

Apply the manifests:
```
kustomize build manifests | kubectl apply -f -
```

# Backups

Kip will store its internal state including pods, cells and certificates in an
etcd database. The data is saved to a persistent volume:

    $ kubectl -n <namespace> get pv
    NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                             STORAGECLASS   REASON   AGE
    pvc-ea04dc38-aa9e-11ea-bdd2-42010a800188   4Gi        RWO            Delete           Bound    <namespace>/data-kip-provider-0   standard                153m

Check the GCE disk the persistent volume:

    $ ks get pv pvc-ea04dc38-aa9e-11ea-bdd2-42010a800188 -ojsonpath={.spec.gcePersistentDisk}; echo
    map[fsType:ext4 pdName:gke-vilmos-439b155a-dy-pvc-ea04dc38-aa9e-11ea-bdd2-42010a800188]

and follow the instructions [here](https://cloud.google.com/compute/docs/disks/create-snapshots) to create a snapshot from that disk.

To restore a backup, [create a disk from the snapshot](https://cloud.google.com/compute/docs/disks/restore-and-delete-snapshots), and then follow the instructions [here](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/preexisting-pd) to create a persistent volume from the GCE disk.

# Upgrades

Set your kubectl context to point to the namespace in which you installed Kip:

    kubectl config set-context --current --namespace=<namespace>

Set the new image version in an environment variable:

    export NEW_VERSION=1.2.3  # Choose the version you want to upgrade to.
    export IMAGE_KIP_PROVIDER="gcr.io/cloud-marketplace/elotl/kip:$NEW_VERSION"

Update the Deployment definition with the reference to the new image:

    kubectl patch statefulset <kip-statefulset-name> \
      --type='json' \
      --patch="[{ \
          \"op\": \"replace\", \
          \"path\": \"/spec/template/spec/containers/0/image\", \
          \"value\":\"${IMAGE_KIP_PROVIDER}\" \
        }]"

You can monitor the progress via:

    kubectl get pods \
      -l "app=kip-provider" \
      --output go-template='Status={{.status.phase}} Image={{(index .spec.containers 0).image}}' \
      --watch

The Kip pod will be terminated, and a new one will be started with the image
specified, getting into the "Running" state.
