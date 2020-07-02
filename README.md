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

- A GKE cluster, see `schema.yaml` for required capacity
- make
- kubectl >= 1.14, configured to access the GKE cluster

If you want to enable image caching, you also need a Filestore or NFS server in
your network. Image caching will decrease pod start up times, especially if the
images used by your pods are large.

### Install from the command line

Set environment variables (modify if necessary):

    $ export NAME=elotl
    $ export NAMESPACE=kip-test
    $ export MARKETPLACE_TOOLS_TAG=latest
    $ export REGISTRY=gcr.io/elotl-public/kip
    $ export TAG=v0.1.0 # Change this to the version you want to install

If your kubeconfig file is in a non-standard location:

    $ export KUBE_CONFIG=<kubeconfig path>

See `Makefile` for all possible variables.

Create the namespace:

    $ kubectl create namespace $NAMESPACE

Create an image pull secret from credentials that have access to the image
repository and enable it as a default pull secret. For example, if your
credentials file is `~/.gcp-elotl-public-gcr-pull.json`:

    $ kubectl create -n $NAMESPACE secret docker-registry gcr-pull --docker-server=gcr.io --docker-username=_json_key --docker-password="$(cat ~/.gcp-elotl-public-gcr-pull.json)" --docker-email=info@elotl.co
    $ kubectl patch -n $NAMESPACE serviceaccount default -p '{"imagePullSecrets": [{"name": "gcr-pull"}]}'

Make sure the application CRD is applied:

    $ kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml

Install the application:

    $ make app/install

This will install Kip, which will create a new virtual node:

    $ kubectl -n $NAMESPACE get nodes
    NAME                                        STATUS   ROLES    AGE    VERSION
    elotl-kip-provider-0                        Ready    agent    57s
    gke-elotl-node-pool-elotl-8bc14dfd-cxhc     Ready    <none>   2d1h   v1.14.10-gke.36
    
### Uninstall

To remove everything, first make sure you have terminated all [cells](https://github.com/elotl/kip/blob/master/docs/cells.md) started by Kip. Then simply:

    $ make app/uninstall

### Enable image caching

You need a Filestore endpoint or NFS server in your network, that exports a
writable volume.

First, go through the steps up until `make app/install` from the [Install from
the command line](#install-from-the-command-line) section. Then export the
following variables:

    $ export NFS_VOLUME_ENDPOINT="10.120.0.2:/data"
    $ export IMAGE_CACHE_CONTROLLER_REPLICAS=1

Install Kip:

    $ make app/install

This will start a deployment that will cache images used in your cluster, so
cells don't need to download them when they start up. Verify that the
deployment is running:

    $ kubectl get -n $NAMESPACE deployments -l app=image-cache-controller
    NAME          READY   UP-TO-DATE   AVAILABLE   AGE
    elotl-cache   1/1     1            1           106s

Note: you need to start a new installation, existing installs can't be updated
this way.

# Backups

Kip will store its internal state including pods, cells and certificates in an
etcd database. The data is saved to a persistent volume:

    $ kubectl -n <namespace> get pv
    NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                             STORAGECLASS   REASON   AGE
    pvc-ea04dc38-aa9e-11ea-bdd2-42010a800188   4Gi        RWO            Delete           Bound    <namespace>/data-kip-provider-0   standard                153m

Check the GCE disk the persistent volume:

    $ kubectl -n <namespace> get pv pvc-ea04dc38-aa9e-11ea-bdd2-42010a800188 -ojsonpath={.spec.gcePersistentDisk}; echo
    map[fsType:ext4 pdName:gke-pd-439b155a-dy-pvc-ea04dc38-aa9e-11ea-bdd2-42010a800188]

and follow the instructions
[here](https://cloud.google.com/compute/docs/disks/create-snapshots) to create
a snapshot from that disk.

To restore a backup, [create a disk from the snapshot](https://cloud.google.com/compute/docs/disks/restore-and-delete-snapshots), and then follow the instructions [here](https://cloud.google.com/kubernetes-engine/docs/how-to/persistent-volumes/preexisting-pd) to create a persistent volume from the GCE disk and bind it to a persistent volume claim that can be used by a Kip instance.

# Upgrades

Set the new image version in an environment variable:

    $ export NEW_VERSION=v0.1.0  # Choose the version you want to upgrade to.
    $ export IMAGE_KIP_PROVIDER="gcr.io/cloud-marketplace/elotl/kip:$NEW_VERSION"

Update the Deployment definition with the reference to the new image:

    $ kubectl patch -n $NAMESPACE statefulset <kip-statefulset-name> \
      --type='json' \
      --patch="[{ \
          \"op\": \"replace\", \
          \"path\": \"/spec/template/spec/containers/0/image\", \
          \"value\":\"${IMAGE_KIP_PROVIDER}\" \
        }]"

You can monitor the progress via:

    $ kubectl get -n $NAMESPACE pods \
      -l "app=kip-provider" \
      --output go-template='Status={{.status.phase}} Image={{(index .spec.containers 0).image}}' \
      --watch

The Kip pod will be terminated, and a new one will be started with the image
specified, getting into the "Running" state.
