# NVIDIA GPU Setup and Distributed Computing on MicroK8s

This guide provides step-by-step instructions for setting up NVIDIA GPUs with Kubernetes using MicroK8s and implementing distributed GPU computing across multiple nodes.

## 1. Cleanup Existing NVIDIA Setup

First, let's completely remove all NVIDIA packages to start fresh:

```bash
# Remove all NVIDIA packages
sudo apt-get purge -y "*nvidia*"
sudo apt-get autoremove -y
sudo apt-get clean

# Check if any NVIDIA packages remain
dpkg -l | grep nvidia

# Remove any leftover configuration files
sudo apt-get purge -y $(dpkg -l | grep nvidia | awk '{print $2}')
sudo rm -rf /etc/nvidia
```

## 2. Install NVIDIA Drivers

```bash
# Install the 535-server driver version
sudo apt-get install -y nvidia-headless-535-server \
                       nvidia-utils-535-server

# Reboot to ensure clean driver loading
sudo reboot
```

After the system reboots, verify the installation:

```bash
# Check if NVIDIA drivers are working
nvidia-smi
```

## 3. Set Up MicroK8s Cluster

Install MicroK8s on all nodes:

```bash
# On all nodes
sudo snap install microk8s --classic --channel=1.27/stable
mkdir -p ~/.kube
sudo chown -R hogade ~/.kube
newgrp microk8s
microk8s enable dns storage helm3 gpu
```

### 3.1 Join Worker Nodes

```bash
# On master node, get join command for each node
microk8s add-node
```

## 4. NVIDIA Device Plugin

```bash
# Uninstall previous installs if there are any
microk8s kubectl delete -n nvidia-device-plugin daemonset nvdp-nvidia-device-plugin
microk8s helm3 uninstall nvdp -n nvidia-device-plugin || true

# Add NVIDIA device plugin repository
microk8s helm3 repo add nvdp https://nvidia.github.io/k8s-device-plugin
microk8s helm3 repo update

# Check available versions
microk8s helm3 search repo nvdp --devel
```

### 4.1 Install using helm

```bash
# Install NVIDIA device plugin with mps configuration
microk8s helm3 install nvdp nvdp/nvidia-device-plugin \
  --version=0.17.1 \
  --namespace nvidia-device-plugin \
  --create-namespace \
  --set gfd.enabled=true \
  --set config.default=mps2 \
  --set-file config.map.mps2=dp-mps-config.yaml
```

Wait for 1 minute

```bash
# Check status
microk8s kubectl get pods -n nvidia-device-plugin -o wide

microk8s kubectl get node --output=json | jq '.items[].metadata.labels' | grep -E "hsc|mps|SHARED|replicas"
```

## 5. Verify GPU Recognition

After completing the above steps:

```bash
# Check available GPU resources on each node
microk8s kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.capacity.nvidia\\.com/gpu

# Check if GPUs are recognized by Kubernetes
microk8s kubectl get nodes -o json | jq '.items[].status.capacity' | grep nvidia
```

## 6. GPU Sharing with NVIDIA MPS

This section demonstrates how to implement GPU sharing using NVIDIA Multi-Process Service (MPS) on Kubernetes. MPS enables multiple containers to efficiently share a single GPU, maximizing resource utilization while maintaining performance isolation.

### 6.1 Project Overview

This setup allows running multiple vLLM (Vector Language Model Library) instances on shared GPUs for efficient AI inference. By using MPS, we can serve more instances than physical GPUs available, reducing hardware costs while maintaining acceptable inference performance.

### 6.2 Key Components

This project uses the following files:

1. **dp-mps-config.yaml**: Configures the NVIDIA device plugin to expose each GPU as 2 shareable MPS resources.
   ```yaml
   version: v1
   sharing:
     mps:
       resources:
       - name: nvidia.com/gpu
         replicas: 2
   ```

2. **Dockerfile**: Builds a container image with vLLM and pre-downloads the TinyLlama model to avoid startup delays.

3. **start-vllm.sh**: Entry point script that launches the vLLM server with appropriate GPU memory utilization settings.

4. **vllm-mps-sharing.yaml**: Kubernetes manifest that creates a StatefulSet of 10 vLLM instances with MPS configuration and pod affinity settings to optimize GPU sharing.

5. **check-pod-distribution.sh**: Utility script to verify how pods are distributed across GPU nodes.

6. **re-apply-nvidia-plugin.sh**: Script to reconfigure the NVIDIA device plugin if needed.

### 6.3 Building the Docker Image

The Dockerfile preloads the TinyLlama model to optimize startup time:

```bash
# Build and push the Docker image
sudo docker build -t ninadhogade/vllm-mps:latest .
sudo docker push ninadhogade/vllm-mps:latest
```

This approach eliminates the need for each pod to download the model when starting, significantly reducing startup time and network usage.

### 6.4 Deploying vLLM with MPS

To deploy the vLLM instances with MPS sharing:

```bash
# Apply the Kubernetes configuration
microk8s kubectl apply -f vllm-mps-sharing.yaml

# Check if the pods are starting (may take a few minutes)
microk8s kubectl get pods -w
```

The deployment uses several key MPS features:
- NVIDIA MPS enabled through pod annotations
- Each pod uses 40% GPU thread allocation (`CUDA_MPS_ACTIVE_THREAD_PERCENTAGE=40`)
- Pod affinity settings to encourage optimal distribution
- Shared MPS pipe directories for interprocess communication

### 6.5 Verifying the Deployment

Use the provided script to check pod distribution across GPU nodes:

```bash
# Verify pod distribution across GPU nodes
bash check-pod-distribution.sh
```

The script shows how many pods are running on each GPU node, helping you confirm proper MPS sharing.

### 6.6 Testing the MPS Service

```bash
# Get the LoadBalancer IP
VLLM_IP=$(microk8s kubectl get svc vllm-mps-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test with curl
curl http://$VLLM_IP:8000/v1/models
```

If the LoadBalancer doesn't get an external IP, use port-forwarding instead:

```bash
microk8s kubectl port-forward svc/vllm-mps 8000:8000
curl http://localhost:8000/v1/models
```

### 6.7 Sample Chat Completion Request

Test the LLM inference with this sample request:

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "/app/models/TinyLlama-1.1B-Chat-v1.0",
    "messages": [
      {"role": "system", "content": "You are a helpful AI assistant."},
      {"role": "user", "content": "Explain how Kubernetes works in one paragraph."}
    ],
    "temperature": 0.7,
    "max_tokens": 150
  }'
```

### 6.8 Cleaning Up

When you're finished with the distributed job, clean up the resources:

```bash
microk8s kubectl delete -f vllm-mps-sharing.yaml 
```

## Troubleshooting

### If GPU Configuration Is Not Working Properly

Check the current status:

```bash
microk8s kubectl get all --all-namespaces | grep -i nvidia
```

Identify the problematic node, and check logs of the problematic pods like below (change pod name):

```bash
microk8s kubectl logs -n gpu-operator pod/nvidia-container-toolkit-daemonset-8h6n2
```

Reinstall NVIDIA Container Runtime on problematic node:

```bash
# Install NVIDIA container toolkit and runtime
sudo apt-get install -y nvidia-container-toolkit nvidia-container-runtime

# Configure container runtime
sudo nvidia-ctk runtime configure --runtime=containerd
sudo systemctl restart snap.microk8s.daemon-containerd
```

Restart Kubernetes services on workers:

```bash
sudo systemctl stop kubelet && sudo systemctl disable kubelet
sudo systemctl restart snap.microk8s.daemon-kubelite.service
```

Check the current status again. If not resolved, try the following.

### GPU Operator

Complete cleanup of GPU Operator and related resources:

```bash
microk8s helm3 uninstall -n gpu-operator $(microk8s helm3 list -n gpu-operator -q)
microk8s kubectl get clusterrolebinding -o name | grep -E 'gpu|nvidia' | xargs microk8s kubectl delete
microk8s kubectl get clusterrole -o name | grep -E 'gpu|nvidia' | xargs microk8s kubectl delete
microk8s kubectl get crd -o name | grep -E 'gpu|nvidia' | xargs microk8s kubectl delete
```

Reinstall GPU Operator:

```bash
# Clean up any previous installation
microk8k8s kubectl delete namespace gpu-operator --ignore-not-found

# Wait for complete cleanup
sleep 30

# Reinstall GPU Operator
microk8s helm3 install --wait --generate-name \
  -n gpu-operator --create-namespace \
  --set driver.enabled=false \
  --set toolkit.enabled=true \
  --set devicePlugin.enabled=true \
  --set dcgmExporter.enabled=true \
  --set gfd.enabled=true \
  --set operator.defaultRuntime=containerd \
  nvidia/gpu-operator
```

### Pod Status Issues

If pods are showing CrashLoopBackOff after computation completes:
- This is normal behavior as the pods exit after completing their task.
- The logs will still contain the computation results.
- You can verify successful completion by checking that verification results show zero error.

```bash
# Delete all debug pods
microk8s kubectl get pods | grep Error | awk '{print $1}' | xargs microk8s kubectl delete pod --force

microk8s kubectl get pods | grep Completed | awk '{print $1}' | xargs microk8s kubectl delete pod

# Force terminate all pods in ContainerCreating state
microk8s kubectl get pods | grep ContainerCreating | awk '{print $1}' | xargs microk8s kubectl delete pod --grace-period=0 --force
```

Manual NVIDIA-MPS commands:

```bash
nvidia-cuda-mps-control -d
export CUDA_MPS_ACTIVE_THREAD_PERCENTAGE=50
./launch_app
echo quit | nvidia-cuda-mps-control
```

Remove and reset everything:

```bash
microk8s leave
microk8s stop
sudo snap remove microk8s
sudo rm -rf ~/.kube
sudo rm -rf /var/snap/microk8s
```
