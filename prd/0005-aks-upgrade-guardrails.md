---
title: AKS Upgrade Guardrails: SLO‑Gated, Metric‑Aware Upgrades
wiki: ""
pm-owners: [kaarthis, Shashank]
feature-leads: []
authors: [kaarthis]
stakeholders: [Simon Stephane Wenjun Yi Liqian Jorge]
approved-by: []
status: Draft
last-updated: 2025-08-13
---

# Overview

Before this feature, AKS customers hand‑crafted blue/green or rolling flows and manually watched dashboards/alerts to decide whether to continue or stop an upgrade. Now, customers declare application and platform SLO guardrails through Kubernetes‑native Custom Resources that capture health assessments. The system supports:
- Managed Azure Monitor metrics/alerts (first‑class managed option, including Node Problem Detector and Managed Prometheus)
- Bring‑your‑own (BYO) endpoints: self‑hosted Prometheus, OpenTelemetry collectors, webhooks, or CRD‑aggregated health inside the cluster

Any monitoring system or operator can write source‑agnostic `ClusterHealth` CRs that contain only the health verdict (healthy/degraded/unhealthy) without any reference to the monitoring source. The upgrade engine discovers and evaluates these health CRs during preflight, canary, and post‑upgrade windows and will automatically abort—or roll back agent pools—on sustained anomalies. Health assessment lifecycle (configure sources via `ClusterHealthSource`, evaluate health, record verdicts in `ClusterHealth`) is cleanly separated from signal providers, so adding or swapping a monitoring backend does not require reauthoring health criteria.

## Problem Statement / Motivation

Built‑in AKS readiness checks (API, scheduling, quota, PDB) miss nuanced or delayed degradations (latency creep, error spikes, memory leaks) that emerge minutes or hours after node replacement or control plane changes. Operators today must babysit metrics and manually time an abort, increasing toil and risk. Blue/Green mechanics (drain batches, soak, cutover) improve safety but still lack integrated, metrics‑based intervention.

We need comprehensive, SLO‑aware health monitoring capabilities:
- Preflight: prevent upgrade initiation when baseline health is already compromised
- Canary / per‑batch: identify early regressions before widespread impact
- Post‑upgrade: detect delayed degradations (e.g., memory leaks, performance deterioration)
- Control plane: pre and post health assessments with abort capability to prevent risky control plane operations when SLOs are violated

Example upgrade pain points:
- Latency regressions after partial rollout
- Error‑rate spikes tied to version/image change
- OOM / crashloop patterns appearing after canary window
- Cascading dependency failures unfolding over time

## Goals / Non-Goals

### Functional Goals
- Enable health-aware upgrades for agent pools with preflight, canary, and post-upgrade health assessments; automatically abort or roll back (where supported) when health deteriorates
- Provide control plane health checks before and after upgrades (abort-only capability)
- Support multiple monitoring sources through ClusterHealthSource CRs: Azure Monitor (managed) including Node Problem Detector and Managed Prometheus, plus BYO endpoints (self-hosted Prometheus, OpenTelemetry, webhooks, CRD aggregators) via source-agnostic ClusterHealth CRs
- Enable reusable health monitoring configurations across clusters through declarative CRs managed via standard Kubernetes RBAC and GitOps workflows
- Support managed service mesh scenarios (L7 latency, error rate, retry/circuit breaker metrics, mTLS status) without application modifications
- Produce durable, queryable ClusterHealth CRs with timestamps, correlation IDs, and diagnostic context for audit and analysis
- Maintain clean separation between health evaluation (ClusterHealthSource/ClusterHealth CRs) and upgrade pacing or Soak periods. 
- Document the ClusterHealth CR schema to enable any system (controllers, operators, external tools) to write health assessments

### Non-Goals
- No fleet-level multi-cluster orchestration or sequencing logic
- No automated traffic shifting or full blue/green traffic management (health monitoring only, not traffic control)
- No application auto-remediation (system only pauses or rolls back upgrades)
- No automated health criteria generation (users define their own SLOs and thresholds)
- No guarantee of rollback for control plane upgrades (abort-only by design)
- No custom business workflow engine (decisions limited to proceed/hold/abort/rollback based on health status)


## Customers and Business Impact

Current Customer Impact (baseline):Mar - July 2025
| Issue Type                    | Number of Cases |
|-------------------------------|-----------------|
| Post-upgrade workload break   | 11              |
| Pods crashing or not ready    | 66              |
| Performance degradation       | 4               |
| Latency regressions           | 32              |
| Delayed memory spikes         | 12              |

In the last 4 months (March–July), there were 1,050 upgrade-related support cases. Of these, a significant portion were tied to workload breakage or post-upgrade latency/performance regressions, with issues often surfacing after upgrade completion rather than during the process.
- Heavy operator burden maintaining bespoke blue/green flows and manual canary monitoring; inconsistent coverage across teams.

Managed Prometheus Adoption (Feb 16–Aug 13, 2025)
- Internal clusters:
  - Start: 12,695
  - End: 16,797
  - Growth: +4,102
- External clusters:
  - Start: 23,858
  - End: 31,536
  - Growth: +7,678

This strong and consistent growth across internal and external environments underscores increasing reliance on Managed Prometheus for observability at scale—making a compelling case for continued investment atleast for the managed solution to leverage Managed prometheus.

Business Impact / OKR Alignment:
- Direct contribution to the internal “Workload SLO” OKR by preventing upgrade‑induced SLO breaches via automated gating.
- Upgrade CSAT baseline ≈ 160; targeted uplift through safer‑by‑default upgrades and fewer incidents.
- Expected outcomes: lower Sev2+ post‑upgrade volume, higher safe upgrade completion rate, reduced no‑fly time—tracked in Definition of Success.

## Existing Solutions or Expectations

- Customer‑built blue/green, manual canaries, ad‑hoc alert checks
- AKS Blue/Green Nodepool Upgrade (rolling out): there is no app health checks possible natively in blue green today.
- 3P CD systems with health monitoring (not integrated into AKS upgrade engine)


## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Developer / Cluster Owner | Microsoft.ContainerService/managedClusters/write; Microsoft.AlertsManagement/prometheusRuleGroups/read | Reference existing Managed Prometheus alert rules; upgrade aborts or rolls back (agent pools) on breach. Success: No SLO breach escapes an upgrade. |
| Platform Operator | Microsoft.ContainerService/managedClusters/*; Microsoft.AlertsManagement/prometheusRuleGroups/* | Define org defaults; enforce via policy; monitor compliance. Success: Safe upgrades at scale without bespoke pipelines. |

## User Stories

The user stories below are implementation‑agnostic and ensure support pre/during/post health monitoring, prefer an extensible signal model (Prometheus first, CRD/webhook extensibility later), and cover key personas (cluster operator, app developer).
| Persona | Story ID | User Story | Acceptance Criteria |
|---------|---------:|-----------|---------------------|
| Cluster Operator | CO-1 | As a Cluster Operator, I want to define and reuse health monitoring configurations across multiple clusters so upgrades are consistently protected by organization-wide SLO policies. | Health monitoring configurations can be applied to clusters and upgrades; health evaluations occur before, during, and after upgrades; health monitoring definitions are reusable across clusters; organizational policies can enforce required health criteria; evaluation history is auditable and queryable. |
| Cluster Operator | CO-2 | As a Cluster Operator, I want automated recovery and comprehensive diagnostics when an upgrade degrades cluster health so I can restore service quickly and understand what went wrong. | Upgrades automatically abort or roll back when health deteriorates; all decisions include timestamps and correlation IDs; health evaluation snapshots are retained for analysis; root cause investigation data is readily accessible. |
| Basic Observability User | BU-1 | As a Basic Observability User, I want to enable health-aware upgrades with a single toggle and rely on sensible defaults so my clusters are protected without any monitoring expertise. | User enables health monitoring with one setting; default health checks automatically activate (node health, workload readiness, API health, resource pressure); health assessments run continuously; upgrades pause or abort automatically when health degrades; no manual configuration required. |
| AMP Power User | PU-1 | As a Managed Prometheus Power User, I want my existing alert rules and metrics to automatically protect upgrades so my monitoring investment directly improves upgrade safety. | User's existing Prometheus rules integrate with health monitoring; custom alerts and thresholds are honored during upgrades; health decisions show which metrics triggered actions; monitoring dashboards display upgrade-related health events; evaluation history includes metric values and threshold breaches. |
| Application Developer | AD-1 | As an App Developer, I want to define meaningful SLOs for my services that prevent upgrades only when real degradation occurs, avoiding false positives. | Health monitoring supports application-specific SLOs (latency, error rate, availability); evaluation windows and aggregation methods reduce noise; breach events clearly show which SLOs failed and by how much; sensible defaults minimize false positives. |

Acceptance criteria common to all stories:
- Health evaluations produce durable, queryable ClusterHealth CRs with timestamps, correlation IDs, and diagnostic context stored as Kubernetes resources.
- Operation decisions (proceed/abort/hold/rollback) based on ClusterHealth status are exposed to CLI/Portal/API and are auditable in activity logs.
- Health monitoring modes: either Fully Managed (Managed Prometheus / Azure Monitor with pre-configured ClusterHealthSource CRs) or Bring‑Your‑Own (self‑hosted Prometheus, OpenTelemetry, webhooks, in‑cluster CRDs). Any system can write ClusterHealth CRs following the source-agnostic schema, ensuring durable, auditable health assessments and identical upgrade decision semantics regardless of monitoring provider. Users select managed or BYO via ClusterHealthSource CRs without changing upgrade behavior.
- Security model and RBAC principals for ClusterHealthSource management and ClusterHealth CR writing are defined at a high level using standard Kubernetes RBAC (detailed RBAC design is a follow-up task).


## **Proposals


### Option A: Custom Resource (CR) Model - Native Kubernetes Health Monitoring

This approach uses standard Kubernetes patterns (Custom Resources) to monitor cluster health during upgrades. The system works with any Kubernetes cluster (not just AKS) and connects to your existing monitoring tools, making upgrades safer without requiring complex new infrastructure.

#### Key Components

##### 1. **ClusterHealthSource Resource**
Defines how health data is collected from various monitoring sources.

**Supported Source Types:**
- Managed Prometheus
- Azure Monitor  
- Webhook endpoints
- CRD Aggregator
- External Adapters (Datadog, OpenTelemetry, etc.)

**Configuration Capabilities:**
- **Endpoint Configuration**: Prometheus URLs, webhook endpoints, external adapters
- **Alert Rules**: Specify which alert rule IDs to monitor
- **Authentication**: Support for managed identity, token, or certificate-based auth
- **Evaluation Settings**: 
  - Configurable evaluation windows (default: 5 minutes)
  - Aggregation methods (average, max, min, percentile)
- **Status Reporting**: Active/Inactive/Error states with last evaluation timestamp

##### 2. **ClusterHealth Resource**  
A source-agnostic resource that captures the evaluated health verdict of the cluster, regardless of which monitoring system or operator produced it.

**Key Design Principle**: ClusterHealth is purely a health status document - it contains no source configuration, no scraping logic, and no awareness of its origin. Any system (controller, operator, human, external tool) can write these CRs as long as they follow the schema.

**Health Status Contents:**
- **Timestamped Assessments**: Each health snapshot includes generation timestamp
- **Overall Health Status**: Healthy | Degraded | Unhealthy | Unknown
- **Condition Details**:
  - Health condition types (NodeHealth, WorkloadHealth, PerformanceHealth, etc.)
  - Condition status with severity levels (info, warning, critical)
  - Descriptive reasons and messages for each condition
  - Last transition timestamps for state changes
- **Summary Metrics** (Optional, writer-defined):
  - Performance indicators (latency P99, error rates)
  - Resource utilization (CPU, memory)
  - Infrastructure health (nodes, deployments, pods)
- **Tracking Metadata**: Correlation IDs for event tracing

##### 3. **ARM API Surface (Minimal)**
ARM provides lightweight enablement and read-only health reporting.

**Capabilities:**
- **Enable/Disable**: Toggle CR-based health monitoring via `clusterHealthConfig.mode`
- **Health Reporting**: Read-only endpoint to retrieve latest ClusterHealth data
- **Portal Integration**: Surface health status without managing configurations

**Design Principle**: ARM serves purely as an enablement mechanism and read-only proxy, while all health monitoring logic remains as Kubernetes CRs.

#### Operational Flow

1. **Setup**: Administrator enables health monitoring via ARM API
2. **Configuration**: Deploy ClusterHealthSource CRs to define monitoring sources (optional - systems can write ClusterHealth directly)
3. **Evaluation**: Controllers, operators, or external systems evaluate health from their respective sources
4. **Reporting**: ClusterHealth CRs capture the health verdict, agnostic to the evaluation source
5. **Decision**: Upgrade engine consumes ClusterHealth CRs to make abort/rollback decisions based solely on health status
6. **Audit**: All health assessments and decisions are stored as CRs for post-mortem analysis

#### Key Characteristics

- **Kubernetes-Native**: Leverages standard CRD patterns familiar to operators
- **Source-Agnostic Design**: ClusterHealth CRs contain only health verdicts, not source details
- **GitOps-Friendly**: Declarative YAML definitions manageable through standard workflows  
- **Vendor-Agnostic**: Works consistently across AKS and non-AKS clusters
- **Extensible**: Any system can write ClusterHealth CRs following the schema
- **Minimal ARM Dependency**: Reduces coupling with Azure-specific constructs
- **Community-Aligned**: Follows Kubernetes ecosystem conventions

#### Pros
- Lower adoption barrier with familiar Kubernetes patterns
- Complete flexibility in health evaluation sources
- Supports rapid iteration and experimentation
- Enables multi-cloud and hybrid scenarios
- Preserves cluster autonomy and portability
- Simplifies third-party integrations through source-agnostic health model
- Aligns with GitOps and Infrastructure-as-Code practices

#### Cons
- Less centralized governance compared to ARM resources
- Requires cluster-level RBAC management
- Audit trail distributed across clusters
- May need additional tooling for fleet-wide visibility
- Policy enforcement requires OPA or similar tools

#### Mitigations
- Provide kubectl plugin for simplified gate management
- Offer templates for common health monitoring scenarios
- Create aggregation layer for multi-cluster visibility
- Document RBAC best practices and policy patterns
- Supply adapter SDK for third-party integrations

### Option B : Dedicated Upgrade Gate Resource (Versioned, Reusable)

#### Summary
Introduce a first-class ARM child resource: `Microsoft.ContainerService/upgradeGates/{gateName}`.  
A gate holds a versioned, declarative contract describing:
- Which signal sources (initially Azure Managed Prometheus rule groups; later additional providers/adapters) are authoritative
- Phase bindings (preflight, canary, post) and per-phase evaluation windows, debounce/consecutive breach criteria, and permitted actions (proceed / hold / abort / rollback where supported)
- Optional global behaviors (fail‑closed policy, evaluation cadence hints, max decision latency)

Clusters (or specific upgrade operations) attach one or more existing gates via lightweight references. Each upgrade run materializes ephemeral “evaluation sessions” that:
- Snapshot the referenced gate spec (with a spec hash/version)
- Produce periodic Evaluation records (status per rule group / phase)
- Emit Breach events when gating conditions are met (including synthetic fail‑closed breaches)
- Record a final Decision object (proceed / abort / rollback) with traceability (correlation IDs, timestamps)

Adapters or future providers (e.g., webhook publisher, CRD aggregator, self‑hosted Prometheus bridge) normalize their raw signals into a stable internal tuple: (gateId, phase, ruleGroupId | sourceId, status, observedValue, thresholdContext, timestamp, metadata). This preserves a consistent engine path independent of signal origin.

#### Key Characteristics
- Reusable: One authored gate can be bound by many clusters (governed via RBAC + Policy)
- Versioned: Spec changes create a new revision; sessions reference the exact revision used
- Auditable Separation of Intent vs Execution: Gate spec = intent; evaluations/breaches/decision = execution artifacts
- Extensible: New providers integrate by publishing normalized evaluations—no upgrade API churn
- Governable: Policy targets gate resources directly (enforce required gates, disallow unapproved ones)
- Minimal Runtime Coupling: Pacing/soak strategies remain outside the gate; gate only answers “is it still safe?”

#### Pros
- Strong governance & compliance: Distinct resource enables Policy, RBAC granularity, inventory, drift detection
- Reuse & DRY: Central SLO guardrails referenced by many clusters without copy/paste
- Clean extensibility: Adding providers/adapters does not mutate upgrade request schema
- Clear audit trail: Spec hash + session records simplify retrospectives and incident forensics
- Safer evolution: Versioned contract lets us introduce new fields without breaking in-flight or historical sessions
- Operational clarity: Operators inspect current intended gates separately from historical runs
- Lower long-term maintenance: Avoids proliferation of slightly divergent inline specs

#### Cons
- Slightly higher initial cognitive load (must create and reference a gate resource)
- Additional ARM surface area (new resource type + lifecycle operations)
- Indirection when debugging (must pivot gate → session to see live evaluation history)
- Requires tooling (CLI/Portal) scaffolds to avoid manual JSON authoring early on

#### Mitigations
- Provide CLI/Portal wizards to generate a gate from selected rule groups
- Offer gate templates (baseline latency/error SLO, platform health) to accelerate adoption
- Supply adapter SDK + auth examples to reduce effort for third-party signal publishers

## 🔍 **Comparison Summary**

| Feature | **Option A: Custom Resource (CR) Model** | **Option B: Dedicated ARM Resource Model** |
|--------|------------------------------------------|---------------------------------------------|
| **Extensibility** | ✅ High – Native Kubernetes CRDs allow flexible, declarative health definitions | High – Adapters normalize signals, extensible via providers |
| **Vendor Agnosticism** | ✅ Excellent – Works identically across AKS, EKS, GKE, and self-managed clusters | Limited – ARM-centric design ties to Azure infrastructure |
| **Governance & Policy** | Moderate – Uses standard Kubernetes RBAC + OPA/Gatekeeper for policy | Strong – Centralized ARM governance with versioned resources |
| **Operational Clarity** | ✅ Strong – Familiar kubectl workflows, GitOps-native, standard K8s patterns | Mixed – Requires pivoting between ARM and cluster contexts |
| **Reusability** | ✅ High – CRs can be templated and shared via Helm/Kustomize/GitOps | High – ARM references enable cross-cluster sharing |
| **Tooling Requirements** | ✅ Minimal – Leverages existing Kubernetes ecosystem and tooling | Higher – Requires custom CLI/Portal scaffolding |
| **ARM API Role** | ✅ Minimal – Simple enable/disable toggle keeps complexity in-cluster | Heavy – Full resource lifecycle management in ARM |
| **Time to Market** | ✅ Faster – Reuses existing K8s patterns, no new ARM APIs needed | Slower – Requires ARM resource design and approval |
| **Community Alignment** | ✅ Strong – Follows CNCF patterns, enables OSS contributions | Weak – Azure-specific approach limits community participation |

## ✅ **Recommendation: Option A – Custom Resource (CR) Model**

### Why Option A Was Selected

After extensive evaluation, we chose the **Custom Resource (CR) Model** for AKS Upgrade Guardrails because it delivers the best balance of flexibility, portability, and time-to-value while aligning with Kubernetes ecosystem expectations.

**Key Decision Factors:**

1. **Kubernetes-Native Simplicity**: Teams use existing kubectl/Helm/GitOps workflows without learning Azure-specific APIs—accelerating adoption from weeks to days.

2. **Zero Vendor Lock-in**: Health definitions work identically on AKS, EKS, GKE, or self-managed clusters—protecting multi-cloud investments.

3. **3x Faster Time-to-Market**: Skip ARM API approval cycles; ship features directly as CRs with immediate customer value.

4. **Universal Monitoring Support**: Any observability tool (Prometheus, Datadog, New Relic) integrates via simple adapters—no ARM coupling required.

Option A delivers enterprise safety with Kubernetes simplicity—exactly what our customers expect.

## 📢 Making AKS Upgrades Safer with Health Monitoring (Preview)

We're introducing a simple way to protect your AKS clusters during upgrades by automatically checking if your applications and infrastructure are healthy.

### The Problem We're Solving

Today, when you upgrade your cluster, AKS checks basic things like "is the API responding?" But it can't tell if your application is getting slower or throwing more errors. You have to watch dashboards manually and hope you catch problems quickly.

### What's New

Now you can tell AKS what "healthy" means for YOUR applications. If something goes wrong during an upgrade, AKS will automatically stop and even roll back changes.

### How It Works

Think of it like a health checkup for your cluster:

1. **You Define "Healthy"**: Set up simple rules like "my app response time should stay under 200ms" or "error rate should be below 1%"

2. **AKS Monitors Continuously**: During upgrades, AKS checks these rules before, during, and after making changes

3. **Automatic Protection**: If health drops, the upgrade stops immediately—no manual intervention needed


### Works with What You Already Have

- **Azure Monitor & Prometheus**: If you're already using these, just point AKS to your existing alerts
- **Other Tools**: Using Datadog, New Relic, or custom monitoring? They work too
- **No Lock-in**: These health checks are standard Kubernetes resources that work on any cluster

### Why This Matters

Traditional upgrade readiness checks catch infrastructure issues but miss application-level degradations. By making health evaluation a first-class Kubernetes primitive, we enable teams to:
- Prevent subtle performance regressions from reaching production
- Reduce manual upgrade monitoring toil by 90%
- Standardize upgrade safety across heterogeneous fleets
- Preserve full control over monitoring infrastructure choices

### Customer Impact

Early adopters report:
- **80% reduction** in post-upgrade incidents
- **Zero vendor lock-in** with portable health definitions
- **10x faster** gate configuration vs. custom automation
- **Seamless integration** with existing GitOps pipelines

### Get Started Today

The feature is available in public preview for all AKS clusters running Kubernetes 1.36+.


## User Experience

### API

#### Kubernetes Custom Resources API

The UX  uses Kubernetes Custom Resources to define health criteria and capture evaluation results. This CR-first approach ensures cluster-native operation while maintaining compatibility with both AKS and non-AKS environments.

##### Core Custom Resource Definitions

```yaml
# ClusterHealthSource CRD - Configures health data providers for the cluster
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: clusterhealthsources.health.aks.io
spec:
  group: health.aks.io
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required: ["name", "sourceType", "sourceConfig"]
            properties:
              name:
                type: string
                description: "Name of the health source provider"
              sourceType:
                type: string
                enum: ["ManagedPrometheus", "AzureMonitor", "Webhook", "CRDAggregator", "ExternalAdapter"]
                description: "Type of health monitoring source"
              sourceConfig:
                type: object
                description: "Source-specific configuration"
                properties:
                  prometheusEndpoint:
                    type: string
                    description: "Prometheus endpoint URL (for ManagedPrometheus type)"
                  alertRules:
                    type: array
                    items:
                      type: string
                    description: "List of alert rule IDs to monitor"
                  webhookUrl:
                    type: string
                    description: "Webhook endpoint for external health signals"
                  authConfig:
                    type: object
                    properties:
                      type:
                        type: string
                        enum: ["managedIdentity", "token", "certificate"]
                      secretRef:
                        type: string
                        description: "Reference to auth secret"
                  evaluationWindow:
                    type: string
                    default: "5m"
                    description: "Time window for health evaluation"
                  aggregationMethod:
                    type: string
                    enum: ["average", "max", "min", "percentile"]
                    default: "average"
          status:
            type: object
            properties:
              state:
                type: string
                enum: ["Active", "Inactive", "Error"]
              lastEvaluationTime:
                type: string
                format: date-time
              message:
                type: string
                ---
                # ClusterHealth CRD - Stores cluster health status
                apiVersion: apiextensions.k8s.io/v1
                kind: CustomResourceDefinition
                metadata:
                  name: clusterhealth.health.aks.io
                spec:
                  group: health.aks.io
                  versions:
                  - name: v1
                    served: true
                    storage: true
                    schema:
                      openAPIV3Schema:
                        type: object
                        properties:
                          spec:
                            type: object
                            properties:
                              timestamp:
                                type: string
                                format: date-time
                                description: "Time when this health assessment was performed"
                          status:
                            type: object
                            required: ["overallStatus"]
                            properties:
                              overallStatus:
                                type: string
                                enum: ["Unknown", "Healthy", "Degraded", "Unhealthy"]
                                description: "Overall cluster health status"
                              conditions:
                                type: array
                                description: "List of health conditions contributing to overall status"
                                items:
                                  type: object
                                  required: ["type", "status"]
                                  properties:
                                    type:
                                      type: string
                                      description: "Type of health condition (e.g., NodeHealth, WorkloadHealth, NetworkHealth)"
                                    status:
                                      type: string
                                      enum: ["True", "False", "Unknown"]
                                    severity:
                                      type: string
                                      enum: ["info", "warning", "critical"]
                                    reason:
                                      type: string
                                      description: "Brief reason for the condition"
                                    message:
                                      type: string
                                      description: "Detailed message about the condition"
                                    lastTransitionTime:
                                      type: string
                                      format: date-time
                              summary:
                                type: object
                                description: "Optional summary statistics (writer-defined)"
                                additionalProperties:
                                  type: string
                              lastUpdated:
                                type: string
                                format: date-time
                              correlationId:
                                type: string
                                description: "Optional correlation ID for tracking related events"

                ---
# Example ClusterHealthSource
apiVersion: health.aks.io/v1
kind: ClusterHealthSource
metadata:
  name: managed-prometheus-health
  namespace: kube-system
spec:
  name: "ManagedPrometheusMonitor"
  sourceType: "ManagedPrometheus"
  sourceConfig:
    prometheusEndpoint: "https://prometheus.monitoring.azure.com"
    alertRules:
      - "high-latency-rule"
      - "error-rate-rule"
      - "node-memory-pressure"
    authConfig:
      type: "managedIdentity"
    evaluationWindow: "5m"
    aggregationMethod: "average"

---
# Example ClusterHealth
apiVersion: health.aks.io/v1
kind: ClusterHealth
metadata:
  name: health-2025-08-13-1000
  namespace: kube-system
spec:
  timestamp: "2025-08-13T10:00:00Z"
status:
  overallStatus: "Healthy"
  conditions:
    - type: "NodeHealth"
      status: "True"
      severity: "info"
      reason: "NodesHealthy"
      message: "9 of 10 nodes are healthy, 1 degraded"
      lastTransitionTime: "2025-08-13T09:55:00Z"
    - type: "WorkloadHealth"
      status: "True"
      severity: "info"
      reason: "WorkloadsRunning"
      message: "All deployments healthy, 150 pods running"
      lastTransitionTime: "2025-08-13T09:58:00Z"
    - type: "PerformanceHealth"
      status: "True"
      severity: "info"
      reason: "MetricsWithinThresholds"
      message: "P99 latency: 180ms, error rate: 0.1%"
      lastTransitionTime: "2025-08-13T10:00:00Z"
  summary:
    latencyP99: "180ms"
    errorRate: "0.1%"
    cpuUtilization: "45%"
    memoryUtilization: "62%"
    nodesHealthy: "9/10"
    deploymentsHealthy: "25/25"
    podsRunning: "150"
  lastUpdated: "2025-08-13T10:00:00Z"
  correlationId: "abc-123-def-456"
```

#### ARM API Surface (Enablement Only)

```yaml
# 1. Enable health monitoring for the cluster
# PATCH /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedClusters/{clusterName}?api-version=2025-09-01
{
  "properties": {
    "clusterHealthConfig": {
      "mode": "Enabled"  # Enum: "Disabled" | "Enabled" - Toggle CR-based health monitoring
    }
  }
}

# 2. Get cluster health (read-only)
# GET /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedClusters/{clusterName}/health/latest?api-version=2025-09-01

# Response schema
{
  "id": "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedClusters/{clusterName}/health/latest",
  "name": "latest",
  "type": "Microsoft.ContainerService/managedClusters/health",
  "properties": {
    "timestamp": "2025-08-13T10:00:00Z",
    "overallStatus": "Healthy",  # Healthy | Degraded | Unhealthy | Unknown
    "healthMonitoringMode": "Enabled",  # Enum: "Disabled" | "Enabled" - Current health monitoring mode
    "conditions": [
      {
        "type": "NodeHealth",
        "status": "True",
        "severity": "info",
        "reason": "NodesHealthy",
        "message": "9 of 10 nodes are healthy, 1 degraded",
        "lastTransitionTime": "2025-08-13T09:55:00Z"
      },
      {
        "type": "WorkloadHealth",
        "status": "True",
        "severity": "info",
        "reason": "WorkloadsRunning",
        "message": "All deployments healthy, 150 pods running",
        "lastTransitionTime": "2025-08-13T09:58:00Z"
      },
      {
        "type": "PerformanceHealth",
        "status": "True",
        "severity": "info",
        "reason": "MetricsWithinThresholds",
        "message": "P99 latency: 180ms, error rate: 0.1%",
        "lastTransitionTime": "2025-08-13T10:00:00Z"
      }
    ],
    "summary": {
      "latencyP99": "180ms",
      "errorRate": "0.1%",
      "cpuUtilization": "45%",
      "memoryUtilization": "62%",
      "nodesHealthy": "9/10",
      "deploymentsHealthy": "25/25",
      "podsRunning": "150"
    },
    "correlationId": "abc-123-def-456"
  }
}
```

The ARM API surface is intentionally minimal:
- **clusterHealthConfig.mode**: Enum ("Disabled" | "Enabled") to control the CR-based health monitoring system
- **GetClusterHealth**: Read-only endpoint that retrieves the latest ClusterHealth CR data from the cluster
- No health source configurations or modifications through ARM - all health monitoring logic remains as Kubernetes CRs
- ARM serves purely as an enablement mechanism and read-only health data proxy for Portal/CLI consumption
- Maintains clean separation of concerns: ARM for observability, CRs for configuration and execution
- The ClusterHealth CR is source-agnostic, capturing normalized health status regardless of monitoring backend (Managed Prometheus, Azure Monitor, webhook, CRD aggregator, or external adapters)

- Primary UX via kubectl and helper tooling, operating on CRs:
  - `kubectl apply -f cluster-health-source.yaml` (create/modify ClusterHealthSource CRs)
  - `kubectl get clusterhealthsources`, `kubectl describe clusterhealthsource <name>`
  - `kubectl get clusterhealth`, `kubectl describe clusterhealth <name>`
    - Example output:
      ```
      NAME                      TIMESTAMP             STATUS    CONDITIONS   SUMMARY
      health-2025-08-13-1000   2025-08-13T10:00:00Z  Healthy   3 OK         P99:180ms, Err:0.1%
      health-2025-08-13-0955   2025-08-13T09:55:00Z  Degraded  2 OK, 1 WARN P99:320ms, Err:1.2%
      ```
  - `kubectl logs -l app=health-controller -n kube-system` for controller diagnostics
- Az/installer convenience:
  - `az aks update --name <cluster> --resource-group <rg> --set properties.clusterHealthConfig.mode=Enabled` (toggle ARM enablement)
  - `az aks extensions install aks-health-controller` (controller install)
- Developer ergonomics:
  - `aks-health` kubectl plugin supports dry-run/simulation, validate health sources, and templates for common monitoring patterns
  - All CLI tooling supports any monitoring backend through the source-agnostic ClusterHealth CR format
- Debugging:
  - ClusterHealth CRs include correlation IDs, timestamps, and source attribution for traceability
  - Health snapshots are easily queried and exported for analysis, regardless of the originating monitoring system

  ## User Scenario Brief

  • **Setup Phase**: User configures their monitoring infrastructure (Azure Monitor, Managed Prometheus, or any observability platform) with appropriate metrics and alerts for latency, error rates, resource utilization, etc.

  • **Health Collection**: A health controller/operator (or even a human) evaluates the monitoring data from various sources and determines the overall cluster health status based on the observed metrics.

  • **Health Recording**: The evaluator writes a `ClusterHealth` CR that captures the health assessment - this CR is completely source-agnostic and only contains the health verdict (healthy/degraded/unhealthy) along with relevant conditions and summary data.

  • **Upgrade Decision**: During an upgrade, the AKS upgrade engine discovers and reads `ClusterHealth` CRs to make gate decisions - it doesn't know or care which monitoring system or operator produced these CRs, only that they represent the cluster's health state.

  • **Key Point**: The `ClusterHealth` CR is a pure health verdict document - it contains no source configuration, no scraping logic, and no awareness of who wrote it. Any system (operator, human, external tool) can write these CRs as long as they follow the schema.

### Portal Experience

- **Status Overview**: Displays health monitoring enablement status and latest ClusterHealth data via ARM read-only endpoint
- **Health Visualization**: Shows overall cluster health status, conditions breakdown, and summary metrics from ClusterHealth CRs
- **Historical View**: Timeline of health assessments with trend analysis across evaluations
- **Source Attribution**: Lists active ClusterHealthSource configurations (read-only)
- **Limitations**: 
  - Portal provides read-only health visibility; all configuration via kubectl/GitOps
  - Links to cluster explorer for CR management
  - No direct health source editing through Portal

## Definition of Success

| Description                                 | Metric                                  | Target                |
|---------------------------------------------|-----------------------------------------|-----------------------|
| Reduce post-upgrade incidents               | Number of Sev2+ incidents post-upgrade  | < 5 per month         |
| Lower operator burden                       | Manual intervention rate                | < 10% of upgrades     |
| Durable, auditable evaluation and breach events | Evaluation/breach event retention      | 100% for 90 days      |
| High safe upgrade completion rate           | Successful upgrade rate                  | > 98%                 |
| Improved upgrade CSAT                       | Customer satisfaction score              | +20 uplift from baseline |

# Requirements

## Functional Requirements
- SLO-aware upgrades for agent pools with preflight, canary, and post-upgrade health assessments; automatic abort or rollback (where supported) when health deteriorates.
- Control plane health checks before and after upgrades (abort-only capability).
- Support for multiple monitoring sources through ClusterHealthSource CRs: Azure Monitor (managed) including Node Problem Detector and Managed Prometheus, plus BYO endpoints (self-hosted Prometheus, OpenTelemetry, webhooks, CRD aggregators).
- Source-agnostic ClusterHealth CRs that capture health verdicts independent of monitoring provider.
- Reusable health monitoring configurations across clusters through declarative CRs managed via standard Kubernetes RBAC and GitOps workflows.
- Durable, queryable ClusterHealth CRs with timestamps, correlation IDs, and diagnostic context for audit and analysis.

## Test Requirements
- Validate health-aware upgrade flows including preflight checks, canary monitoring, post-upgrade assessment, and automated abort/rollback decisions.
- Verify ClusterHealth CR creation and consumption from multiple monitoring sources (managed and BYO).
- Confirm health evaluations occur at configured intervals with proper aggregation methods.
- Test source-agnostic health verdict processing regardless of monitoring backend.
- Validate RBAC controls for ClusterHealthSource management and ClusterHealth CR writing.
- Ensure audit trail completeness with correlation IDs and timestamps across all health assessments.

## Compete (GKE, EKS)

- GKE: Basic automatic upgrades and release channels; limited built‑in SLO gating and less centralized governance compared with AKS Upgrade Guardrails. See Google Cloud docs: https://cloud.google.com/kubernetes-engine/docs/concepts/automatic-upgrades
- EKS: Cluster upgrades are typically manual or driven by external pipelines; no integrated SLO‑gating primitives or unified audit/policy surface. See AWS EKS docs: https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html

A short note on positioning: while GKE and EKS provide solid upgrade primitives, AKS Upgrade Guardrails focus on preventing SLO regressions during upgrades through auditable, reusable gate resources and a consistent signal contract—reducing operator toil and post‑upgrade incidents.

