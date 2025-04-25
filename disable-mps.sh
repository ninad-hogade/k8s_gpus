#!/bin/bash

# Uninstall the current NVIDIA device plugin with MPS configuration
microk8s kubectl delete -n nvidia-device-plugin daemonset nvdp-nvidia-device-plugin
microk8s helm3 uninstall nvdp -n nvidia-device-plugin

# Add NVIDIA device plugin repository (in case it's needed)
microk8s helm3 repo add nvdp https://nvidia.github.io/k8s-device-plugin
microk8s helm3 repo update

# Install NVIDIA device plugin with standard configuration (no MPS)
microk8s helm3 install nvdp nvdp/nvidia-device-plugin \
  --version=0.17.1 \
  --namespace nvidia-device-plugin \
  --create-namespace \
  --set gfd.enabled=true

echo "Waiting for the device plugin to restart..."
sleep 15

# Verify the configuration
echo "Checking GPU resources after disabling MPS:"
microk8s kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.capacity.nvidia\\.com/gpu

# Verify that MPS-related labels are removed
echo "Checking for absence of MPS labels:"
microk8s kubectl get node --output=json | jq '.items[].metadata.labels' | grep -E "mps|SHARED|replicas" || echo "No MPS labels found - successfully disabled"
