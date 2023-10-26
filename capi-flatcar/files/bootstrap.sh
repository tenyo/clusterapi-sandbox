#!/bin/bash
# This will configure k8s prereqs on a machine and install kubeadm, kubelet, kubectl, etc.

BIN_DIR="/opt/bin"
KUBE_VER="{{ .Values.kubeVersion }}"

mkdir -p "$BIN_DIR"

echo "Bootstrapping - $(date) ..."
echo "$(uname -a)"
echo "Kube version: $KUBE_VER"

sysctl --system

## initialize container disk

echo "$(lsblk -I 8 -o name,label,size)"

# TODO: make this check more reliable
# pick the smallest available disk
CONTAINER_DISK=$(lsblk --json -I 8 -o name,label,size | jq -r '.blockdevices | sort_by(.size) | map(select(.children == null)) | map(select(.size != "0B")) | .[0].name')
if [ ! -z "$CONTAINER_DISK" ]; then
echo "Using container disk: /dev/${CONTAINER_DISK}"

sgdisk --zap-all "/dev/${CONTAINER_DISK}"
blkdiscard  "/dev/${CONTAINER_DISK}"
mkfs.ext4 "/dev/${CONTAINER_DISK}"
e2label "/dev/${CONTAINER_DISK}" CONTAINER_STORE

systemctl stop containerd

cat  <<EOF > /etc/systemd/system/var-lib-containerd.mount
[Unit]
Before=local-fs.target
[Mount]
What=LABEL=CONTAINER_STORE
Where=/var/lib/containerd
Type=ext4
[Install]
WantedBy=local-fs.target
EOF

cat  <<EOF > /etc/systemd/system/containerd.service.d/10-wait-var-lib-containerd.conf
[Unit]
After=var-lib-containerd.mount
Requires=var-lib-containerd.mount
EOF

systemctl daemon-reload
systemctl enable --now var-lib-containerd.mount
mkdir /var/lib/containerd/pod-logs && rm -rf /var/log/pods
ln -s /var/lib/containerd/pod-logs /var/log/pods
systemctl start containerd
else
echo "WARNING: unable to pick an available container disk using lsblk!"
fi

## install kubeadm, kubelet, kubectl and add a kubelet systemd service

if [[ $(arch) == arm* ]] || [[ $(arch) == aarch64 ]]; then
ARCH="arm64"
else
ARCH="amd64"
fi

echo "Downloading kube binaries (arch: ${ARCH}) ..."

cd $BIN_DIR
curl -L --remote-name-all https://dl.k8s.io/release/${KUBE_VER}/bin/linux/${ARCH}/{kubeadm,kubelet,kubectl}
chmod +x {kubeadm,kubelet,kubectl}

systemctl enable --now kubelet

mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sed -i "s,sandbox_image.*$,sandbox_image = \"$(/opt/bin/kubeadm config images list | grep pause | sort -r | head -n1)\"," /etc/containerd/config.toml

systemctl restart containerd
