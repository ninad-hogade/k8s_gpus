#!/bin/bash

echo "========== GPU NODE INFORMATION =========="
microk8s kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.capacity.nvidia\\.com/gpu

echo -e "\n========== POD DISTRIBUTION BY NODE =========="
for NODE in $(microk8s kubectl get nodes -l nvidia.com/gpu.present=true -o jsonpath='{.items[*].metadata.name}'); do
    echo "Node: $NODE"
    echo "Pods:"
    microk8s kubectl get pods -o wide | grep "$NODE" | grep vllm-mps | awk '{print "  " $1}'
    echo "Total pods on node: $(microk8s kubectl get pods -o wide | grep "$NODE" | grep vllm-mps | wc -l)"
    echo "-----------------------------------"
done

echo -e "\n========== TOTAL POD COUNT =========="
echo "Total running vLLM MPS pods: $(microk8s kubectl get pods | grep vllm-mps | grep Running | wc -l)"
echo "Total pending vLLM MPS pods: $(microk8s kubectl get pods | grep vllm-mps | grep Pending | wc -l)"
