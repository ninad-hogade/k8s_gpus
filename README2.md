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
