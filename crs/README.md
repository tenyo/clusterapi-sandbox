# ClusterResourceSets

You can define ClusterResourceSets (crs) on the management cluster if you want to automatically install any addons on the created workload clusters.

This feature requires the `EXP_CLUSTER_RESOURCE_SET` env variable to be set (for more details see https://cluster-api.sigs.k8s.io/tasks/experimental-features/experimental-features).

## Cilium

```
helm repo add cilium https://helm.cilium.io
```

Render the cilium templates overriding any specific cilium values: 
```
helm template cilium cilium/cilium --namespace kube-system --version 1.14.3 \
  --set authentication.enabled=false \
  --set hostFirewall.enabled=true \
  --set hubble.enabled=false \
  --set ipam.mode=kubernetes \
  --set loadBalancer.algorithm=maglev \
  --set loadBalancer.mode=snat \
  --set operator.replicas=1 \
> cilium-crs.yaml
```

Create a configmap:
```
kubectl create configmap cilium-crs --from-file=cilium-crs.yaml
```

Create the cilium crs using the example manifest:
```
kubectl apply -f cilium-crs.yaml
```

```
kubectl describe clusterresourceset cilium-crs
```

Now any workload `Cluster`s created with a matching `cni` label with get Cilium installed:
```
kind: Cluster
metadata:
  labels:
    cni: cilium
...
```