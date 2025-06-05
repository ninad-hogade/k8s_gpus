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


# Production-Grade MPS Configuration Management

## 1. Configuration Change Scenarios & Strategies

### **Scenario A: Planned Optimization Updates**
*Example: Improving MPS partitioning based on performance data*

```yaml
# config-update-strategy.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mps-update-strategy
data:
  strategy: "blue-green"
  update-window: "02:00-04:00 UTC"
  max-disruption: "20%"
  validation-timeout: "300s"
```

**Implementation:**
```bash
#!/bin/bash
# planned-mps-update.sh

# 1. Wait for optimal time window
wait_for_low_traffic_window() {
    while true; do
        CURRENT_QPS=$(get_current_qps)
        if [ $CURRENT_QPS -lt $LOW_TRAFFIC_THRESHOLD ]; then
            echo "Low traffic detected: $CURRENT_QPS QPS"
            break
        fi
        echo "Traffic too high: $CURRENT_QPS QPS. Waiting..."
        sleep 300  # Check every 5 minutes
    done
}

# 2. Blue-Green node pool strategy
update_with_blue_green() {
    # Create new node pool with updated MPS config
    kubectl apply -f blue-node-pool-with-new-mps.yaml
    
    # Wait for nodes to be ready
    kubectl wait --for=condition=Ready nodes -l pool=blue --timeout=600s
    
    # Gradually shift traffic
    shift_traffic_gradually
    
    # Monitor health for 30 minutes
    monitor_health_30min
    
    # If healthy, drain green pool
    if [ $HEALTH_CHECK_PASSED ]; then
        kubectl drain nodes -l pool=green
        kubectl delete -f green-node-pool.yaml
    else
        # Rollback
        shift_traffic_back_to_green
    fi
}
```

### **Scenario B: Emergency Configuration Changes**
*Example: Critical GPU memory issue requiring immediate MPS adjustment*

```python
# emergency-mps-handler.py
class EmergencyMPSHandler:
    def __init__(self):
        self.max_allowed_disruption = 0.3  # 30% of services
        self.emergency_configs = self._load_emergency_configs()
    
    def handle_gpu_memory_crisis(self, node_name, new_config):
        """Handle emergency MPS reconfiguration"""
        
        # 1. Assess impact
        affected_pods = self._get_pods_on_node(node_name)
        critical_pods = [p for p in affected_pods if p.priority == 'critical']
        
        # 2. Emergency evacuation for critical workloads
        if critical_pods:
            self._emergency_evacuate_critical_pods(critical_pods)
        
        # 3. Apply emergency MPS config
        self._apply_emergency_config(node_name, new_config)
        
        # 4. Validate and monitor
        success = self._validate_emergency_change(node_name)
        
        if not success:
            self._emergency_rollback(node_name)
            
        return success
    
    def _emergency_evacuate_critical_pods(self, pods):
        """Move critical pods to other nodes immediately"""
        for pod in pods:
            # Find alternative node
            target_node = self._find_emergency_node(pod.resource_requirements)
            
            if target_node:
                # Create identical pod on new node
                self._create_pod_copy(pod, target_node)
                # Wait for readiness
                self._wait_for_pod_ready(pod.name + '-emergency')
                # Delete original
                self._delete_pod_gracefully(pod)
```

## 2. Production-Safe Update Mechanisms

### **A. Traffic-Aware Updates**
```yaml
# traffic-aware-updater.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: traffic-aware-mps-updater
spec:
  schedule: "*/15 * * * *"  # Check every 15 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: updater
            image: mps-config-updater:latest
            env:
            - name: MIN_QPS_THRESHOLD
              value: "100"  # Don't update if QPS > 100
            - name: MAX_ERROR_RATE
              value: "0.01"  # Don't update if error rate > 1%
            - name: REQUIRED_FREE_CAPACITY
              value: "0.4"   # Need 40% free capacity to start update
```

### **B. Circuit Breaker Pattern**
```python
# circuit-breaker-mps-updater.py
class MPSCircuitBreaker:
    def __init__(self):
        self.failure_threshold = 3
        self.failure_count = 0
        self.state = 'CLOSED'  # CLOSED, OPEN, HALF_OPEN
        self.last_failure_time = None
        
    def can_update_mps(self):
        """Check if MPS updates are allowed based on circuit state"""
        
        if self.state == 'OPEN':
            # Check if cooldown period has passed
            if time.time() - self.last_failure_time > 3600:  # 1 hour cooldown
                self.state = 'HALF_OPEN'
                return True
            return False
            
        return self.state != 'OPEN'
    
    def record_update_success(self):
        """Record successful MPS update"""
        self.failure_count = 0
        self.state = 'CLOSED'
        
    def record_update_failure(self):
        """Record failed MPS update"""
        self.failure_count += 1
        self.last_failure_time = time.time()
        
        if self.failure_count >= self.failure_threshold:
            self.state = 'OPEN'
            self._alert_operations_team()
```

### **C. Canary Deployment for MPS Configs**
```bash
#!/bin/bash
# canary-mps-deployment.sh

deploy_mps_canary() {
    local new_config=$1
    local canary_percentage=${2:-10}  # Default 10% canary
    
    # 1. Select canary nodes (10% of cluster)
    CANARY_NODES=$(kubectl get nodes -l nvidia.com/gpu.present=true \
        --no-headers | shuf -n $(( $(kubectl get nodes -l nvidia.com/gpu.present=true --no-headers | wc -l) / 10 )) \
        | awk '{print $1}')
    
    echo "Selected canary nodes: $CANARY_NODES"
    
    # 2. Label canary nodes
    for node in $CANARY_NODES; do
        kubectl label node $node mps-config=canary
    done
    
    # 3. Apply new MPS config to canary nodes only
    apply_mps_config_to_nodes "$new_config" "$CANARY_NODES"
    
    # 4. Monitor canary for 1 hour
    monitor_canary_health 3600
    
    # 5. Decision point
    if [ $CANARY_HEALTH_GOOD ]; then
        echo "Canary successful. Rolling out to all nodes..."
        rollout_to_all_nodes "$new_config"
    else
        echo "Canary failed. Rolling back..."
        rollback_canary_nodes "$CANARY_NODES"
    fi
}

monitor_canary_health() {
    local duration=$1
    local start_time=$(date +%s)
    
    while [ $(($(date +%s) - start_time)) -lt $duration ]; do
        # Check key metrics
        ERROR_RATE=$(get_error_rate_for_nodes "$CANARY_NODES")
        LATENCY_P99=$(get_p99_latency_for_nodes "$CANARY_NODES")
        GPU_UTILIZATION=$(get_gpu_utilization_for_nodes "$CANARY_NODES")
        
        # Validate metrics
        if (( $(echo "$ERROR_RATE > 0.05" | bc -l) )); then
            echo "CANARY FAILURE: Error rate too high: $ERROR_RATE"
            return 1
        fi
        
        if (( $(echo "$LATENCY_P99 > 2000" | bc -l) )); then
            echo "CANARY FAILURE: Latency too high: $LATENCY_P99 ms"
            return 1
        fi
        
        sleep 60  # Check every minute
    done
    
    echo "Canary health validation passed"
    return 0
}
```

## 3. When to Apply Configuration Changes

### **A. Intelligent Timing Engine**
```python
# timing-engine.py
class ConfigUpdateTimingEngine:
    def __init__(self):
        self.metrics_client = MetricsClient()
        self.update_rules = self._load_update_rules()
    
    def is_safe_to_update(self, update_type, target_nodes):
        """Determine if it's safe to apply configuration changes"""
        
        # Check current system load
        current_load = self._get_system_load()
        
        # Check update rules
        rule = self.update_rules[update_type]
        
        checks = {
            'traffic_load': current_load['qps'] < rule['max_qps'],
            'error_rate': current_load['error_rate'] < rule['max_error_rate'],
            'gpu_utilization': current_load['gpu_util'] < rule['max_gpu_util'],
            'free_capacity': self._check_free_capacity(target_nodes) > rule['min_free_capacity'],
            'time_window': self._in_allowed_time_window(rule['allowed_windows']),
            'no_ongoing_incidents': not self._has_active_incidents(),
            'dependency_health': self._check_dependency_health()
        }
        
        # All checks must pass
        all_passed = all(checks.values())
        
        if not all_passed:
            failed_checks = [k for k, v in checks.items() if not v]
            self._log_update_postponed(update_type, failed_checks)
            
        return all_passed
    
    def get_optimal_update_time(self, update_type):
        """Predict optimal time for updates based on historical data"""
        
        historical_metrics = self._get_historical_metrics(days=30)
        
        # Find patterns in low-traffic periods
        low_traffic_windows = self._identify_low_traffic_patterns(historical_metrics)
        
        # Consider timezone and business hours
        business_hours = self._get_business_hours_for_regions()
        
        # Find intersection of low traffic and off-business hours
        optimal_windows = self._find_optimal_windows(
            low_traffic_windows, 
            business_hours
        )
        
        return optimal_windows[0]  # Return next optimal time
```

### **B. Configuration Update Rules**
```yaml
# update-rules.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mps-update-rules
data:
  rules.yaml: |
    update_types:
      routine_optimization:
        max_qps: 50
        max_error_rate: 0.01
        max_gpu_util: 0.7
        min_free_capacity: 0.3
        allowed_windows:
          - "02:00-04:00 UTC"
          - "14:00-16:00 UTC"
        max_disruption_percentage: 10
        
      emergency_fix:
        max_qps: 1000  # Higher tolerance for emergency
        max_error_rate: 0.05
        max_gpu_util: 0.9
        min_free_capacity: 0.1
        allowed_windows: "*"  # Any time
        max_disruption_percentage: 50
        
      capacity_expansion:
        max_qps: 100
        max_error_rate: 0.005
        max_gpu_util: 0.6
        min_free_capacity: 0.4
        allowed_windows:
          - "01:00-05:00 UTC"
        max_disruption_percentage: 5
```

## 4. Zero-Downtime Update Architecture

### **A. Dual-Stack Approach**
```yaml
# dual-stack-architecture.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dual-stack-config
data:
  architecture.yaml: |
    stacks:
      primary:
        node_selector:
          stack: "primary"
        mps_config: "current-stable"
        traffic_percentage: 100
        
      secondary:
        node_selector:
          stack: "secondary"  
        mps_config: "new-candidate"
        traffic_percentage: 0
        
    update_process:
      1. Prepare secondary stack with new config
      2. Gradually shift traffic (0% → 10% → 50% → 100%)
      3. Monitor health at each step
      4. Rollback available instantly
```

### **B. Intelligent Load Balancer**
```python
# intelligent-load-balancer.py
class MPSAwareLoadBalancer:
    def __init__(self):
        self.primary_stack_weight = 100
        self.secondary_stack_weight = 0
        self.health_monitor = HealthMonitor()
        
    def route_request(self, request):
        """Route requests based on MPS configuration updates"""
        
        # Check if update is in progress
        if self._is_update_in_progress():
            # Route based on current weights
            if random.randint(1, 100) <= self.secondary_stack_weight:
                return self._route_to_secondary(request)
            else:
                return self._route_to_primary(request)
        else:
            return self._route_to_primary(request)
    
    def adjust_traffic_weights(self, primary_weight, secondary_weight):
        """Gradually adjust traffic distribution"""
        
        self.primary_stack_weight = primary_weight
        self.secondary_stack_weight = secondary_weight
        
        # Log traffic shift
        self._log_traffic_shift(primary_weight, secondary_weight)
        
        # Update load balancer configuration
        self._update_lb_config()
    
    def emergency_failover(self):
        """Immediate failover in case of issues"""
        
        self.primary_stack_weight = 100
        self.secondary_stack_weight = 0
        
        self._log_emergency_failover()
        self._alert_operations_team("Emergency failover executed")
```

## 5. Production Implementation Timeline

### **Phase 1: Infrastructure Preparation (Week 1-2)**
```bash
# Setup dual-stack infrastructure
kubectl apply -f dual-stack-node-pools.yaml
kubectl apply -f traffic-splitting-ingress.yaml
kubectl apply -f health-monitoring-stack.yaml
```

### **Phase 2: Gradual Rollout (Week 3-4)**
```bash
# Day 1: Deploy to 5% of traffic
./gradual-rollout.sh --percentage=5 --duration=24h

# Day 3: Increase to 25% if healthy
./gradual-rollout.sh --percentage=25 --duration=48h

# Day 7: Full rollout if all metrics good
./gradual-rollout.sh --percentage=100
```

### **Phase 3: Automated Operations (Week 5+)**
```bash
# Enable fully automated updates with safeguards
kubectl apply -f automated-mps-updater.yaml
kubectl apply -f circuit-breaker-config.yaml
kubectl apply -f emergency-rollback-automation.yaml
```

This production approach ensures:
- **Zero-downtime updates** through traffic shifting
- **Automated safety checks** before any changes
- **Instant rollback capability** when issues detected
- **Intelligent timing** based on system load and business hours
- **Comprehensive monitoring** throughout the update process



# QPS (Queries Per Second) - Deep Dive

## What is QPS?

**QPS = Queries Per Second** - A fundamental metric measuring the number of requests your system processes per second.

```
QPS = Total Requests / Time Period (seconds)

Example:
- 3,600 requests in 1 minute = 60 QPS
- 86,400 requests in 1 day = 1 QPS average
```

### In Your ML Inference Context:
```bash
# Each "query" is an inference request:
curl -X POST http://your-vllm-service:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello, how are you?", "max_tokens": 50}'

# If you get 100 such requests per second → 100 QPS
```

## Why QPS Matters for MPS Configuration

### **High QPS = Risky Time for Updates**
```python
# Example decision logic
def is_safe_for_mps_update(current_qps):
    if current_qps > 200:
        return False, "Too much traffic - risk of service disruption"
    elif current_qps > 100:
        return False, "Medium traffic - wait for lower load"
    elif current_qps < 50:
        return True, "Low traffic - safe to update"
    else:
        return True, "Moderate traffic - proceed with caution"
```

### **QPS Patterns Throughout the Day**
```
QPS Pattern for a Typical ML Service:
    
300 |     **                    **
250 |   **  **                **  **
200 | **      **            **      **
150 |*          **        **          *
100 |             **    **
 50 |               ****               
  0 +--------------------------------
    0  3  6  9  12 15 18 21 24 (hours)
    
Best Update Windows:
- 2-4 AM: QPS typically lowest (20-30)
- 2-4 PM: Secondary low period (40-60)
```

## QPS Monitoring Implementation

### **1. Application-Level Monitoring**

#### **A. vLLM Built-in Metrics**
```python
# vllm-metrics-exporter.py
from prometheus_client import Counter, Histogram, start_http_server
import time

# Prometheus metrics
REQUEST_COUNT = Counter('vllm_requests_total', 'Total requests', ['status'])
REQUEST_DURATION = Histogram('vllm_request_duration_seconds', 'Request duration')

class vLLMMetricsCollector:
    def __init__(self):
        self.request_times = []
        self.start_time = time.time()
        
    def record_request(self, status='success', duration=None):
        """Record each inference request"""
        REQUEST_COUNT.labels(status=status).inc()
        
        if duration:
            REQUEST_DURATION.observe(duration)
            
        # Calculate rolling QPS
        current_time = time.time()
        self.request_times.append(current_time)
        
        # Keep only requests from last 60 seconds
        self.request_times = [t for t in self.request_times 
                             if current_time - t <= 60]
        
        current_qps = len(self.request_times)
        
        return current_qps

# Usage in your vLLM service
metrics = vLLMMetricsCollector()

@app.route('/v1/completions', methods=['POST'])
def inference():
    start_time = time.time()
    try:
        # Your inference logic here
        result = model.generate(prompt)
        
        duration = time.time() - start_time
        qps = metrics.record_request('success', duration)
        
        return jsonify(result)
    except Exception as e:
        metrics.record_request('error')
        return jsonify({'error': str(e)}), 500
```

#### **B. nginx/Ingress Level Monitoring**
```yaml
# nginx-with-metrics.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    http {
        # Enable request logging
        log_format detailed '$remote_addr - $remote_user [$time_local] '
                          '"$request" $status $body_bytes_sent '
                          '"$http_referer" "$http_user_agent" '
                          'rt=$request_time uct="$upstream_connect_time" '
                          'uht="$upstream_header_time" urt="$upstream_response_time"';
        
        access_log /var/log/nginx/access.log detailed;
        
        server {
            listen 80;
            
            # Prometheus metrics endpoint
            location /nginx_status {
                stub_status on;
                access_log off;
            }
            
            location / {
                proxy_pass http://vllm-service:8000;
                
                # Add QPS tracking headers
                add_header X-Request-Time $request_time;
                add_header X-Upstream-Time $upstream_response_time;
            }
        }
    }
```

### **2. Prometheus + Grafana Monitoring Stack**

#### **A. Prometheus Configuration**
```yaml
# prometheus-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      
    scrape_configs:
    # Scrape vLLM metrics
    - job_name: 'vllm-inference'
      static_configs:
      - targets: ['vllm-service:8000']
      metrics_path: /metrics
      scrape_interval: 5s  # More frequent for QPS accuracy
      
    # Scrape nginx metrics
    - job_name: 'nginx-ingress'
      static_configs:
      - targets: ['nginx-ingress:80']
      metrics_path: /nginx_status
      scrape_interval: 5s
      
    # Custom QPS calculation rules
    rule_files:
    - /etc/prometheus/rules/*.yml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-rules
data:
  qps-rules.yml: |
    groups:
    - name: qps_calculations
      rules:
      # Calculate QPS over different time windows
      - record: vllm:qps_1m
        expr: rate(vllm_requests_total[1m])
        
      - record: vllm:qps_5m  
        expr: rate(vllm_requests_total[5m])
        
      - record: vllm:qps_15m
        expr: rate(vllm_requests_total[15m])
        
      # Calculate success rate
      - record: vllm:success_rate
        expr: |
          rate(vllm_requests_total{status="success"}[5m]) / 
          rate(vllm_requests_total[5m])
          
      # Alert rules
      - alert: HighQPS
        expr: vllm:qps_1m > 200
        for: 2m
        annotations:
          summary: "High QPS detected: {{ $value }} requests/sec"
          
      - alert: LowSuccessRate
        expr: vllm:success_rate < 0.95
        for: 5m
        annotations:
          summary: "Success rate dropped to {{ $value }}%"
```

#### **B. Grafana Dashboard**
```json
{
  "dashboard": {
    "title": "vLLM QPS Monitoring",
    "panels": [
      {
        "title": "Real-time QPS",
        "type": "stat",
        "targets": [
          {
            "expr": "vllm:qps_1m",
            "legendFormat": "Current QPS"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "thresholds": {
              "steps": [
                {"color": "green", "value": 0},
                {"color": "yellow", "value": 100},
                {"color": "red", "value": 200}
              ]
            }
          }
        }
      },
      {
        "title": "QPS Over Time",
        "type": "timeseries",
        "targets": [
          {
            "expr": "vllm:qps_1m",
            "legendFormat": "1 minute"
          },
          {
            "expr": "vllm:qps_5m", 
            "legendFormat": "5 minute"
          }
        ]
      },
      {
        "title": "QPS by Node",
        "type": "timeseries",
        "targets": [
          {
            "expr": "sum by (node) (rate(vllm_requests_total[1m]))",
            "legendFormat": "{{ node }}"
          }
        ]
      }
    ]
  }
}
```

### **3. Real-time QPS Monitoring for MPS Updates**

#### **A. QPS-Aware Update Controller**
```python
# qps-aware-mps-controller.py
import prometheus_api_client
import time
import logging

class QPSAwareMPSController:
    def __init__(self):
        self.prom = prometheus_api_client.PrometheusConnect(url="http://prometheus:9090")
        self.qps_thresholds = {
            'safe_update': 50,      # Safe to update MPS
            'caution_update': 100,  # Proceed with caution
            'no_update': 200        # Too risky to update
        }
        
    def get_current_qps(self):
        """Get current QPS from Prometheus"""
        query = 'sum(rate(vllm_requests_total[1m]))'
        result = self.prom.custom_query(query=query)
        
        if result:
            return float(result[0]['value'][1])
        return 0
    
    def get_qps_trend(self, minutes=15):
        """Get QPS trend over specified minutes"""
        query = f'sum(rate(vllm_requests_total[{minutes}m]))'
        result = self.prom.custom_query_range(
            query=query,
            start_time=time.time() - (minutes * 60),
            end_time=time.time(),
            step=60
        )
        
        values = [float(point[1]) for point in result[0]['values']]
        return {
            'current': values[-1] if values else 0,
            'average': sum(values) / len(values) if values else 0,
            'trend': 'increasing' if values[-1] > values[0] else 'decreasing',
            'peak': max(values) if values else 0
        }
    
    def is_safe_for_mps_update(self):
        """Determine if it's safe to update MPS configuration"""
        current_qps = self.get_current_qps()
        trend_data = self.get_qps_trend()
        
        # Check current QPS
        if current_qps > self.qps_thresholds['no_update']:
            return False, f"Current QPS too high: {current_qps:.1f}"
        
        # Check if QPS is trending upward rapidly
        if (trend_data['trend'] == 'increasing' and 
            current_qps > trend_data['average'] * 1.5):
            return False, f"QPS trending up rapidly: {current_qps:.1f}"
        
        # Check recent peak
        if trend_data['peak'] > self.qps_thresholds['no_update']:
            return False, f"Recent peak too high: {trend_data['peak']:.1f}"
        
        # Determine safety level
        if current_qps <= self.qps_thresholds['safe_update']:
            return True, f"Safe: QPS is low ({current_qps:.1f})"
        elif current_qps <= self.qps_thresholds['caution_update']:
            return True, f"Caution: QPS is moderate ({current_qps:.1f})"
        else:
            return False, f"Wait: QPS is high ({current_qps:.1f})"

# Usage in MPS update workflow
controller = QPSAwareMPSController()

def attempt_mps_update():
    safe, reason = controller.is_safe_for_mps_update()
    
    if safe:
        logging.info(f"Proceeding with MPS update: {reason}")
        return update_mps_configuration()
    else:
        logging.warning(f"Postponing MPS update: {reason}")
        return schedule_retry_later()
```

#### **B. Live QPS Dashboard for Operations**
```bash
#!/bin/bash
# live-qps-monitor.sh

# Real-time QPS monitoring script
watch_qps() {
    while true; do
        # Get current QPS
        QPS=$(curl -s "http://prometheus:9090/api/v1/query?query=sum(rate(vllm_requests_total[1m]))" \
              | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
        
        # Get success rate
        SUCCESS_RATE=$(curl -s "http://prometheus:9090/api/v1/query?query=sum(rate(vllm_requests_total{status=\"success\"}[1m]))/sum(rate(vllm_requests_total[1m]))" \
                      | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
        
        # Color coding
        if (( $(echo "$QPS > 200" | bc -l) )); then
            COLOR="\033[31m"  # Red
            STATUS="HIGH TRAFFIC - NO UPDATES"
        elif (( $(echo "$QPS > 100" | bc -l) )); then
            COLOR="\033[33m"  # Yellow  
            STATUS="MODERATE TRAFFIC - CAUTION"
        else
            COLOR="\033[32m"  # Green
            STATUS="LOW TRAFFIC - SAFE FOR UPDATES"
        fi
        
        # Clear screen and display
        clear
        echo -e "${COLOR}Current QPS: $(printf "%.1f" $QPS)"
        echo -e "Success Rate: $(printf "%.2f" $(echo "$SUCCESS_RATE * 100" | bc))%"
        echo -e "Status: $STATUS\033[0m"
        echo ""
        echo "Threshold Guidelines:"
        echo "  < 50 QPS: Safe for MPS updates"
        echo "  50-100 QPS: Proceed with caution"  
        echo "  100-200 QPS: High risk"
        echo "  > 200 QPS: Do not update"
        
        sleep 5
    done
}

# Run the monitor
watch_qps
```

## QPS Monitoring Best Practices

### **1. Multiple Time Windows**
```yaml
# Monitor QPS at different granularities
metrics:
  qps_1m: "Immediate traffic spikes"
  qps_5m: "Short-term trends" 
  qps_15m: "Medium-term patterns"
  qps_1h: "Long-term planning"
```

### **2. Business Context**
```python
# business-aware-qps.py
class BusinessAwareQPS:
    def __init__(self):
        self.business_hours = {
            'US': {'start': 9, 'end': 17, 'tz': 'America/New_York'},
            'EU': {'start': 9, 'end': 17, 'tz': 'Europe/London'},
            'ASIA': {'start': 9, 'end': 17, 'tz': 'Asia/Tokyo'}
        }
    
    def get_expected_qps_range(self, current_time):
        """Get expected QPS range based on business hours"""
        
        active_regions = self._get_active_business_regions(current_time)
        
        if len(active_regions) == 0:
            return {'min': 10, 'max': 50, 'optimal_update': True}
        elif len(active_regions) == 1:
            return {'min': 50, 'max': 150, 'optimal_update': False}
        else:
            return {'min': 150, 'max': 300, 'optimal_update': False}
```

### **3. Alerts and Automation**
```yaml
# qps-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: qps-alerting-rules
spec:
  groups:
  - name: qps.rules
    rules:
    - alert: QPSSpike
      expr: increase(vllm_requests_total[5m]) > 1000
      for: 1m
      annotations:
        summary: "Sudden QPS spike detected"
        action: "Postpone any planned MPS updates"
        
    - alert: QPSDroppedToZero
      expr: rate(vllm_requests_total[5m]) == 0
      for: 2m
      annotations:
        summary: "No traffic detected - possible service issue"
        
    - alert: OptimalUpdateWindow
      expr: rate(vllm_requests_total[5m]) < 30
      for: 10m
      annotations:
        summary: "Low traffic detected - optimal for updates"
        action: "Consider running scheduled MPS optimizations"
```

QPS monitoring provides the critical feedback loop for safe, intelligent MPS configuration management in your production ML inference system.
