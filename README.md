# ClusterAPI sandbox

The Devcontainer has all necessary tools required to quickly get up and running a ClusterAPI cluster environment.

## Create management cluster

Once the Devcontainer starts you can deploy a management ClusterAPI cluster on the local kind cluster.

```
# enable support for ignition configs
export EXP_KUBEADM_BOOTSTRAP_FORMAT_IGNITION=true

# enable support for clusterresourcesets
export EXP_CLUSTER_RESOURCE_SET=true

# use your Equinix Metal token
export PACKET_API_KEY=<YOUR_TOKEN>

clusterctl init --infrastructure packet
```

After that you can create workload clusters.


## Basic workload cluster deploy with Ubuntu on Equinix Metal

Export required vars for packet provider:
```
export PROJECT_ID="dc001ab1-9386-4159-b45c-9a1ba0a81611"
export METRO="da"
export CONTROLPLANE_NODE_TYPE="t3.small.x86"
export WORKER_NODE_TYPE="t3.small.x86"
export NODE_OS="ubuntu_20_04"
export POD_CIDR="192.168.0.0/16"
export SERVICE_CIDR="172.26.0.0/16"
export SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGzxTkbVXQR+RRdadSkQ5eKxG53WZTervwMi3GLzlYoO"
```

Generate manifests based on the above for a new cluster test1 and apply:
```
clusterctl generate cluster test1 --kubernetes-version v1.28.2 --control-plane-machine-count=1 --worker-machine-count=1 > test1.yaml

kubectl apply -f test1.yaml
```

Wait until cluster is initialized:
```
vscode ➜ /workspaces/clusterapi-sandbox $ kubectl get clusters
NAME    PHASE         AGE   VERSION
test1   Provisioned   22m   

vscode ➜ /workspaces/clusterapi-sandbox $ kubectl get kubeadmcontrolplane
NAME                  CLUSTER   INITIALIZED   API SERVER AVAILABLE   REPLICAS   READY   UPDATED   UNAVAILABLE   AGE   VERSION
test1-control-plane   test1     true                                 1                  1         1             23m   v1.28.2
```

Get the kubeconfig for the new cluster:
```
clusterctl get kubeconfig test1 > test1.kubeconfig
```

Control plane is not ready because we need CNI:
```
vscode ➜ /workspaces/clusterapi-sandbox $ kubectl --kubeconfig=./test1.kubeconfig get node
NAME                        STATUS     ROLES           AGE   VERSION
test1-control-plane-969h5   NotReady   control-plane   18m   v1.28.2
```

Install Cilium:
```
KUBECONFIG=./test1.kubeconfig cilium install
```

## Workload cluster deploy using Flatcar/Ignition on Equinix Metal

This is not supported currently by the packet provider (see https://github.com/kubernetes-sigs/cluster-api-provider-packet/issues/495) so we need to manually craft the manifests.

Disclaimer: This is still WIP so it may not create a fully functioning kube cluster!

Make sure you export your EM API key as it will be used by the helm chart:
```
export PACKET_API_KEY=<YOUR_TOKEN>
```

Render the ClusterAPI manifests using Helm to deploy a kube cluster on Flatcar servers in Equinix Metal:
```
helm template capi-flatcar/ --set apiKey=${PACKET_API_KEY} --set nameOverride="cluster1" | kubectl apply -f -
```

After it initializes, get the kubeconfig for the new cluster, e.g.:
```
clusterctl get kubeconfig cluster1 > .kubeconfig
```

Install Cilium using the CLI to get the cluster operational:
```
KUBECONFIG=.kubeconfig cilium install --set MTU=1500
```

Confirm cluster is now Ready:
```
kubectl --kubeconfig=.kubeconfig get node
```

## Bootstrap/pivot to new management cluster

Bootstrap a local/kind mgmt cluster and create a new workload cluster from there.
Once it's up and ready, use clusterctl to init the new cluster and move all the capi configs:

```
KUBECONFIG=.kubeconfig clusterctl init --infrastructure packet
```

```
clusterctl move --to-kubeconfig=.kubeconfig
```
