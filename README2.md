# Automatic GPU Sharing and Selection Process Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    INTELLIGENT GPU SCHEDULER PROCESS FLOW                      │
└─────────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────────┐
                              │ Inference       │
                              │ Request Arrives │
                              └─────────┬───────┘
                                        │
                                        ▼
                              ┌─────────────────┐
                              │ Extract Request │
                              │ Characteristics │
                              │ • Model size    │
                              │ • Priority      │
                              │ • SLA needs     │
                              └─────────┬───────┘
                                        │
                                        ▼
                    ┌─────────────────────────────────────────┐
                    │        WORKLOAD CLASSIFICATION          │
                    │ ┌─────────┐ ┌─────────┐ ┌─────────────┐ │
                    │ │  Tiny   │ │ Medium  │ │    Large    │ │
                    │ │ <4GB    │ │ 4-16GB  │ │   >16GB     │ │
                    │ │ A100    │ │ A100    │ │    H100     │ │
                    │ │ 25% MPS │ │ 50% MPS │ │   100% MPS  │ │
                    │ └─────────┘ └─────────┘ └─────────────┘ │
                    └─────────────────┬───────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────────┐
                    │         AVAILABLE NODES SCAN           │
                    │                                         │
                    │ ┌─────────────┐    ┌─────────────────┐ │
                    │ │   4 H100s   │    │    8 A100s      │ │
                    │ │ 700W, 80GB  │    │ 400W, 40GB     │ │
                    │ │ 1000 TOPS   │    │ 624 TOPS       │ │
                    │ └─────────────┘    └─────────────────┘ │
                    └─────────────────┬───────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────────┐
                    │           NODE FILTERING                │
                    └─────────────────┬───────────────────────┘
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
        ▼                             ▼                             ▼
┌──────────────┐              ┌──────────────┐              ┌──────────────┐
│   Memory     │              │  Current     │              │ Capability   │
│   Check      │              │ Utilization  │              │   Match      │
│              │              │              │              │              │
│ GPU Mem ≥    │              │ GPU Usage    │              │ Workload     │
│ Required     │              │   < 90%      │              │ Affinity     │
│              │              │              │              │              │
│ ✓ or ✗       │              │ ✓ or ✗       │              │ ✓ or ✗       │
└──────┬───────┘              └──────┬───────┘              └──────┬───────┘
       │                             │                             │
       └─────────────────────────────┼─────────────────────────────┘
                                     │
                                     ▼
                    ┌─────────────────────────────────────────┐
                    │           NODE SCORING                  │
                    │                                         │
                    │ Score = (Efficiency × 0.3) +           │
                    │         (Affinity × 0.25) +            │
                    │         (Utilization × 0.2) +          │
                    │         (Power Bonus × 0.15) +         │
                    │         (MPS Compatibility × 0.1)      │
                    └─────────────────┬───────────────────────┘
                                      │
                                      ▼
               ┌─────────────────────────────────────────────────┐
               │              DECISION MATRIX                    │
               │                                                 │
               │ Node A (H100): Score 8.5 ┌───┐                │
               │ Node B (A100): Score 9.2 │ ✓ │ ← Selected      │
               │ Node C (A100): Score 7.1 └───┘                │
               │ Node D (H100): Score 6.8                       │
               └─────────────────────┬───────────────────────────┘
                                     │
                                     ▼
               ┌─────────────────────────────────────────────────┐
               │         MPS CONFIGURATION CALCULATION           │
               │                                                 │
               │ Current Node Workloads:                         │
               │ ├─ Pod 1: Medium model (50% MPS)               │
               │ ├─ Pod 2: Tiny model (25% MPS)                 │
               │ └─ Available: 25% MPS                          │
               │                                                 │
               │ New Request: Tiny model (25% MPS) ✓ Fits       │
               └─────────────────────┬───────────────────────────┘
                                     │
                                     ▼
               ┌─────────────────────────────────────────────────┐
               │         DYNAMIC MPS RECONFIGURATION             │
               │                                                 │
               │ Updated MPS Config:                             │
               │ ┌─────────────────────────────────────────────┐ │
               │ │ version: v1                                 │ │
               │ │ sharing:                                    │ │
               │ │   mps:                                      │ │
               │ │     resources:                              │ │
               │ │     - name: nvidia.com/gpu                 │ │
               │ │       replicas: 4                          │ │
               │ │       options:                             │ │
               │ │         thread_percentages: [50,25,25,0]   │ │
               │ └─────────────────────────────────────────────┘ │
               └─────────────────────┬───────────────────────────┘
                                     │
                                     ▼
               ┌─────────────────────────────────────────────────┐
               │             POD SCHEDULING                      │
               │                                                 │
               │ 1. Create Pod with:                             │
               │    ├─ Node selector: selected-node             │
               │    ├─ MPS annotations                           │
               │    ├─ Resource limits                           │
               │    └─ Workload labels                           │
               │                                                 │
               │ 2. Apply Pod to Kubernetes                      │
               │ 3. Wait for pod to start                        │
               └─────────────────────┬───────────────────────────┘
                                     │
                                     ▼
               ┌─────────────────────────────────────────────────┐
               │              MONITORING LOOP                    │
               │                                                 │
               │ ┌─────────────┐  ┌─────────────┐ ┌─────────────┐│
               │ │Throughput   │  │Power        │ │Queue        ││
               │ │Monitoring   │  │Consumption  │ │Length       ││
               │ │             │  │             │ │             ││
               │ │Every 30s    │  │Every 30s    │ │Real-time    ││
               │ └─────────────┘  └─────────────┘ └─────────────┘│
               └─────────────────────┬───────────────────────────┘
                                     │
                                     ▼
            ┌──────────────────────────────────────────────────────┐
            │                HPA SCALING LOGIC                     │
            │                                                      │
            │ IF queue_length > 5 AND efficiency > 10 TOPS/W:     │
            │ ├─ Scale UP by 4 pods                               │
            │ │                                                   │
            │ IF queue_length < 2 AND cost_per_inference > $0.01: │
            │ ├─ Scale DOWN by 2 pods                             │
            │ │                                                   │
            │ Stabilization: 60s up, 300s down                    │
            └──────────────────────┬───────────────────────────────┘
                                   │
                                   ▼
            ┌──────────────────────────────────────────────────────┐
            │              OPTIMIZATION FEEDBACK                   │
            │                                                      │
            │ ┌─ Performance Data ─┐    ┌─ Cost Analysis ──┐      │
            │ │ • Actual vs        │    │ • $/inference    │      │
            │ │   predicted        │    │ • Power costs    │      │
            │ │   throughput       │    │ • Utilization    │      │
            │ │ • Latency metrics  │    │   efficiency     │      │
            │ └────────────────────┘    └──────────────────┘      │
            │                    │                               │
            │              ┌─────▼─────┐                         │
            │              │  Update   │                         │
            │              │ Scheduler │                         │
            │              │  Weights  │                         │
            │              └───────────┘                         │
            └──────────────────────┬───────────────────────────────┘
                                   │
                   ┌───────────────▼────────────────┐
                   │         CONTINUOUS LOOP         │
                   │                                 │
                   │ Every new request triggers:     │
                   │ ├─ Classification              │
                   │ ├─ Node selection              │
                   │ ├─ MPS reconfiguration         │
                   │ └─ Deployment                  │
                   │                                 │
                   │ Every 30 seconds:               │
                   │ ├─ Metrics collection          │
                   │ ├─ HPA evaluation              │
                   │ └─ Optimization feedback       │
                   └─────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              EXAMPLE SCENARIOS                                 │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│ SCENARIO 1: High Priority Large Model Request                                  │
│ ┌───────────────────────────────────────────────────────────────────────────┐ │
│ │ Request: 40GB model, Priority: HIGH, Latency: <100ms                     │ │
│ │ Decision: Route to H100 (even if less efficient)                         │ │
│ │ MPS: 100% allocation (no sharing)                                        │ │
│ │ Result: Optimal latency, higher cost acceptable                          │ │
│ └───────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
│ SCENARIO 2: Batch Processing Request                                           │
│ ┌───────────────────────────────────────────────────────────────────────────┐ │
│ │ Request: 8GB model, Priority: LOW, Batch: 100 requests                   │ │
│ │ Decision: Route to A100 (better efficiency)                              │ │
│ │ MPS: 50% allocation (shared with similar workload)                       │ │
│ │ Result: Optimal throughput/watt, cost minimized                          │ │
│ └───────────────────────────────────────────────────────────────────────────┘ │
│                                                                                 │
│ SCENARIO 3: Mixed Workload Balancing                                           │
│ ┌───────────────────────────────────────────────────────────────────────────┐ │
│ │ Current: 3 H100s busy, 6 A100s at 60% utilization                       │ │
│ │ New Request: Medium model                                                 │ │
│ │ Decision: Route to least utilized A100                                   │ │
│ │ MPS: Dynamic partition sizing based on co-located workloads              │ │
│ │ HPA: Consider scaling if queue grows                                     │ │
│ └───────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Key Decision Points in the Flow:

**1. Workload Classification:**
- Determines GPU type preference
- Sets MPS partition requirements
- Influences scheduling weights

**2. Node Scoring Algorithm:**
```
* Efficiency Score (30%): TOPS/Watt ratio
* Affinity Score (25%): Workload-GPU type match  
* Utilization Score (20%): Current load factor
* Power Bonus (15%): Priority-based power preference
* MPS Compatibility (10%): Available partition space
```

**3. MPS Dynamic Reconfiguration:**
- Calculates optimal partition sizes
- Updates device plugin configuration
- Restarts necessary components

**4. HPA Triggers:**
```
Scale UP when:
├─ Queue length > 5 requests
├─ Efficiency > 10 TOPS/Watt maintained
└─ Cost per inference < threshold

Scale DOWN when:
├─ Queue length < 2 requests  
├─ Utilization < 70%
└─ Cost optimization possible
```

This flow ensures optimal GPU utilization while maintaining performance requirements and cost efficiency across your heterogeneous H100/A100 cluster.


**Short Answer: No, not safely.** Updating MPS ConfigMaps while pods are running will typically require pod restarts and can cause service disruption.

## What Happens When You Update MPS ConfigMap

### 1. **NVIDIA Device Plugin Restart Required**
```bash
# When you update the MPS ConfigMap:
kubectl patch configmap mps-config -p '{"data":{"config.yaml":"new-config"}}'

# The NVIDIA device plugin daemonset must restart to pick up changes:
kubectl rollout restart daemonset/nvdp-nvidia-device-plugin -n nvidia-device-plugin
```

### 2. **MPS Server Restart Impact**
- The MPS server on each node must be stopped and restarted
- All existing MPS contexts are terminated
- Running pods lose GPU access immediately
- Pods may crash or enter error states

### 3. **Pod Disruption**
```bash
# Before MPS config change - pods running normally
kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
vllm-mps-0     1/1     Running   0          10m
vllm-mps-1     1/1     Running   0          10m

# After MPS config change - pods may fail
kubectl get pods
NAME           READY   STATUS    RESTARTS   AGE
vllm-mps-0     0/1     Error     1          11m
vllm-mps-1     0/1     Error     1          11m
```

## Safe Strategies for Dynamic MPS Updates

### 1. **Rolling Node Updates**
```bash
#!/bin/bash
# rolling-mps-update.sh

NODES=$(kubectl get nodes -l nvidia.com/gpu.present=true -o name)

for NODE in $NODES; do
    NODE_NAME=$(echo $NODE | cut -d'/' -f2)
    echo "Updating MPS config on $NODE_NAME"
    
    # 1. Cordon the node
    kubectl cordon $NODE_NAME
    
    # 2. Drain pods gracefully
    kubectl drain $NODE_NAME --ignore-daemonsets --delete-emptydir-data --force
    
    # 3. Update MPS config for this node
    kubectl patch configmap mps-config-$NODE_NAME -p '{"data":{"config.yaml":"'$(cat new-mps-config.yaml | base64 -w 0)'"}}'
    
    # 4. Restart device plugin on this node only
    kubectl delete pod -n nvidia-device-plugin -l app=nvidia-device-plugin --field-selector spec.nodeName=$NODE_NAME
    
    # 5. Wait for device plugin to restart
    sleep 30
    
    # 6. Uncordon the node
    kubectl uncordon $NODE_NAME
    
    # 7. Wait for pods to reschedule
    sleep 60
    
    echo "Node $NODE_NAME updated successfully"
done
```

### 2. **Node Pool Strategy**
```yaml
# Use different node pools with different MPS configurations
apiVersion: v1
kind: Node
metadata:
  name: gpu-node-pool-1
  labels:
    node-pool: "high-throughput"
    mps-config: "multi-partition"
---
apiVersion: v1
kind: Node  
metadata:
  name: gpu-node-pool-2
  labels:
    node-pool: "single-model"
    mps-config: "single-partition"
```

### 3. **Graceful Pod Migration**
```python
# graceful_mps_update.py
import kubernetes
from kubernetes import client, config

class GracefulMPSUpdater:
    def __init__(self):
        config.load_incluster_config()
        self.v1 = client.CoreV1Api()
        self.apps_v1 = client.AppsV1Api()
    
    def update_mps_with_migration(self, new_config, target_nodes):
        """Update MPS config with pod migration"""
        
        for node_name in target_nodes:
            # 1. Get pods running on this node
            pods = self._get_gpu_pods_on_node(node_name)
            
            # 2. Scale up replicas on other nodes first
            self._scale_up_on_other_nodes(pods)
            
            # 3. Wait for new pods to be ready
            self._wait_for_pods_ready()
            
            # 4. Gracefully terminate pods on target node
            self._terminate_pods_on_node(node_name)
            
            # 5. Update MPS configuration
            self._update_mps_config(node_name, new_config)
            
            # 6. Restart device plugin on this node
            self._restart_device_plugin(node_name)
            
            # 7. Allow pods to reschedule
            self._enable_scheduling(node_name)
```

## Best Practices for Production

### 1. **Maintenance Windows**
```yaml
# Schedule MPS updates during low-traffic periods
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mps-config-updater
spec:
  schedule: "0 2 * * 0"  # Sunday 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: mps-updater
            image: kubectl:latest
            command: ["/scripts/rolling-mps-update.sh"]
```

### 2. **Pre-warming Strategy**
```bash
# Pre-create pods with new configuration on available nodes
kubectl scale statefulset vllm-mps --replicas=15  # Scale up before update
# Then update MPS config on nodes with fewer pods
# Finally scale back down
kubectl scale statefulset vllm-mps --replicas=10
```

### 3. **Health Checks and Rollback**
```yaml
# Add readiness probes to detect MPS configuration issues
containers:
- name: vllm
  readinessProbe:
    httpGet:
      path: /health
      port: 8000
    initialDelaySeconds: 30
    periodSeconds: 10
    failureThreshold: 3
  
  # Environment variable to detect MPS changes
  env:
  - name: MPS_CONFIG_VERSION
    valueFrom:
      configMapKeyRef:
        name: mps-config
        key: version
```

### 4. **Monitoring During Updates**
```bash
# Monitor pod health during MPS updates
kubectl get pods -w --field-selector status.phase!=Running

# Check GPU utilization
nvidia-smi dmon -s u -c 10

# Monitor inference latency
curl -s http://vllm-service:8000/metrics | grep inference_latency
```

## Recommended Approach

For your production system, implement a **staged update approach**:

1. **Blue-Green Node Strategy**: Maintain two sets of nodes with different MPS configurations
2. **Gradual Migration**: Move workloads gradually between node sets
3. **Automated Rollback**: If issues detected, automatically revert to previous configuration
4. **Comprehensive Monitoring**: Track pod health, GPU utilization, and inference performance throughout the update

This ensures zero-downtime updates while maintaining optimal GPU utilization across your heterogeneous cluster.
