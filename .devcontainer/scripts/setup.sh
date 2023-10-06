#!/bin/bash

export ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then ARCH=arm64; fi

export KIND_CLI_VERSION=0.20.0
export CLUSTERCTL_VERSION=1.5.2
export CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)

go install sigs.k8s.io/kind@v${KIND_CLI_VERSION}
go install github.com/equinix/metal-cli/cmd/metal@latest

# install cluster-api clusterctl
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v${CLUSTERCTL_VERSION}/clusterctl-linux-${ARCH} -o clusterctl && \
    sudo install -o root -g root -m 0755 clusterctl /usr/local/bin/clusterctl && \
    rm clusterctl

# install ct
git clone --branch v0.9.4 https://github.com/flatcar/container-linux-config-transpiler && \
    cd container-linux-config-transpiler && \
    make && \
    sudo install -o root -g root -m 0755 bin/ct /usr/local/bin/ct && \
    cd ../ && \
    rm -rf container-linux-config-transpiler

# install cilium cli
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${ARCH}.tar.gz.sha256sum && \
    sudo tar xzvfC cilium-linux-${ARCH}.tar.gz /usr/local/bin && \
    rm cilium-linux-${ARCH}.tar.gz{,.sha256sum}

echo "Creating kind cluster ..."
kind delete cluster
kind create cluster

kubectl cluster-info

echo "To initialize a local management cluster with a packet provider run the following:"
echo
echo "export EXP_KUBEADM_BOOTSTRAP_FORMAT_IGNITION=true"
echo "export PACKET_API_KEY=<YOUR_TOKEN>"
echo "clusterctl init --infrastructure packet"
echo
