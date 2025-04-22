#!/bin/bash

# Make sure helm3 is enabled in microk8s
microk8s enable helm3

# Uninstall previous installation if it exists

# microk8s helm3 uninstall -n gpu-operator $(microk8s helm3 list -n gpu-operator -q)
# microk8s kubectl get clusterrolebinding -o name | grep -E 'gpu|nvidia' | xargs microk8s kubectl delete
# microk8s kubectl get clusterrole -o name | grep -E 'gpu|nvidia' | xargs microk8s kubectl delete
# microk8s kubectl get crd -o name | grep -E 'gpu|nvidia' | xargs microk8s kubectl delete
# microk8s kubectl delete namespace gpu-operator --ignore-not-found

# Install GPU Operator with correct settings

# microk8s helm3 install --wait --generate-name \
#   -n gpu-operator --create-namespace \
#   --set devicePlugin.enabled=true \
#   --set dcgmExporter.enabled=true \
#   --set driver.enabled=false \
#   --set toolkit.enabled=true \
#   --set gfd.enabled=true \
#   --set operator.defaultRuntime=containerd \
#   nvidia/gpu-operator


#  --set operator.defaultRuntime=containerd \
# microk8s kubectl get all --all-namespace
# s | grep -i nvidia


microk8s kubectl delete -n nvidia-device-plugin daemonset nvdp-nvidia-device-plugin
microk8s helm3 uninstall nvdp -n nvidia-device-plugin || true

# Add NVIDIA device plugin repository
microk8s helm3 repo add nvdp https://nvidia.github.io/k8s-device-plugin
microk8s helm3 repo update

# Check available versions
microk8s helm3 search repo nvdp --devel

# Install NVIDIA device plugin with time-slicing configuration
microk8s helm3 install nvdp nvdp/nvidia-device-plugin \
  --version=0.17.1 \
  --namespace nvidia-device-plugin \
  --create-namespace \
  --set gfd.enabled=true \
  --set config.default=mps2 \
  --set-file config.map.mps2=dp-mps-config.yaml

#   --set runtimeClassName=nvidia \
  #  --set-file config.configMap.config=dp-mps-config.yaml


echo "Waiting for the device plugin to start..."
sleep 10

# Check status
microk8s kubectl get pods -n nvidia-device-plugin  -o wide


microk8s kubectl get node --output=json | jq '.items[].metadata.labels' | grep -E "hsc|mps|SHARED|replicas"

# Check if GPUs are recognized by Kubernetes
microk8s kubectl get nodes -o json | jq '.items[].status.capacity' | grep nvidia

# Check available GPU resources on each node
microk8s kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.capacity.nvidia\\.com/gpu

