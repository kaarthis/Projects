---
title: Managed Mesh Observability - Control Plane and Data Plane Metrics for Public Preview
wiki: ""
pm-owners: [Chase]
feature-leads: []
authors: [Chase]
stakeholders: [Shashank, Ahmed, Jorge, Fuyuan, Aritra]
approved-by: []
---

# Overview

This public preview delivers a unified observability experience for Applink customers that mirrors the AKS monitoring model. Customers get comprehensive visibility into both Mesh control plane (MCP) and data plane metrics through Azure Monitor Managed Prometheus, aligning with the familiar AKS customer experience. Both metric types are available in the same Azure Monitor workspace in raw Prometheus format, enabling seamless correlation and troubleshooting of their service mesh.

## Scope

This PRD defines the public preview for Applink observability covering both control plane and data plane metrics. It focuses on delivering an AKS-aligned customer experience through:

- **Unified metrics collection**: Both Mesh control plane (MCP) and data plane (ztunnel, CNI) metrics collected and available in the same Azure Monitor workspace via Managed Prometheus
- **AKS-aligned experience**: Customers configure observability using the same Azure Monitor Managed Prometheus integration pattern familiar to AKS users via configmaps
- **Standard Prometheus format**: All metrics exposed in standard Prometheus format, compatible with Azure Monitor and BYO Prometheus collectors. (BYO Prometheus collectors are out of scope for this PRD and will be addressed in a separate workstream)

**Out of scope for public preview**: 
- Portal UI for control plane-specific metrics
- Custom alert/recording rules
- Extensibility of scrape targets beyond Managed Mesh components
- BYO Prometheus experience
- Hosted or BYO mesh visualization tools such as kiali
- Multi-cluster experience
- Waypoint proxy metrics

## Glossary

| Term | Definition |
|------|------------|
| **MCP (Mesh Control Plane)** | Azure-hosted environment running the Istio control plane (**istiod**), isolated from customer clusters |
| **Ambient Mesh** | Istio's sidecar-less service mesh mode that uses ztunnel for L4 and optional waypoint proxies for L7 capabilities. AppLink supports ambient mode only |
| **Data Plane** | Istio dataplane components (such as **ztunnel**, **Waypoint Proxy**, and **Istio CNI**) running inside customer clusters to handle service-to-service communication |
| **istiod** | The core Istio control plane component responsible for service discovery, configuration distribution, and certificate management for the mesh |
| **ztunnel** | Lightweight Layer-4 proxy that manages secure, zero-trust connections between workloads in Ambient Mesh |
| **Waypoint Proxy** | Layer-7 Envoy proxy deployed per namespace or ServiceAccount to enforce policies and collect telemetry for HTTP/gRPC traffic |
| **Istio CNI** | The CNI (Container Network Interface) plugin used by Istio to set up pod networking and traffic redirection without requiring an init container for iptables |

## Problem Statement / Motivation

AKS customers monitor their clusters through a unified experience: all operational telemetry lands in one place by default, making it straightforward to understand cluster health and diagnose issues. Applink extends AKS clusters with a managed service mesh, but the mesh control plane (Istiod) runs in an Azure-hosted environment separate from the customer's cluster. If AppLink telemetry doesn't integrate into the same monitoring flow, customers lose the unified cluster operations view they rely on.

Without this integration, customers face:

- **Fragmented cluster visibility**: Mesh metrics separated from cluster metrics breaks the single view of what's running in their cluster, making it hard to answer "is it the mesh or the app?"
- **Incomplete mesh observability**: Difficult to see both control plane (Istiod in Azure) and data plane (ztunnel, CNI in-cluster) health together, slowing incident diagnosis
- **Monitoring workflow disruption**: Deviates from the experience customers already use for AKS, requiring custom scrapes, duplicate dashboards, and parallel pipelines

Customers need a unified observability solution that integrates AppLink control plane and data plane metrics into their existing cluster monitoring experience, preserving the operational simplicity they expect from AKS.

This public preview delivers comprehensive mesh observability through Azure Monitor Managed Prometheus, providing access to both control plane and data plane metrics in a unified workspace, aligned with the AKS customer experience.

## Goals / Non-Goals

### Functional Goals

- Integrate AppLink mesh metrics into customers' existing cluster monitoring workspace, preserving the unified AKS observability experience
- Provide visibility into both control plane and data plane mesh health within the same workspace customers use for cluster operations
- Align the customer configuration experience with AKS Managed Prometheus patterns
- Expose all mesh metrics in standard Prometheus format consumable by Azure Monitor Managed Prometheus.

### Non-Functional Goals

- Ensure metrics are available with minimal latency 
- Maintain system stability and reliability

### Non-Goals

- Portal visualization or custom dashboards specific to mesh metrics (customers use Azure Monitor workspace query/visualization)
- Pre-configured alerting or recording rules for mesh metrics
- Fine-grained access control (per-metric or per-namespace)
- Customer ability to extend scrape targets beyond Istio control plane and data plane components
- Shoebox (Geneva) metrics integration or migration (out of scope for this PRD; will be addressed separately)
- Waypoint proxy metrics (will be addressed in later releases)
- Multi-cluster experience (out of scope for this PRD and will be addressed in separately)

## Narrative / Personas

### Penny - Platform Engineer

**The Black Box Problem**

As a platform engineer, I roll out Applink's managed mesh on AKS and must prove it is production-ready. When I enable the mesh, none of the telemetry shows up in my cluster monitoring workspace. The control plane (Istiod in Azure) is completely opaque, and data plane components (ztunnel, CNI) aren't integrated into my existing observability flow. During deploys, config sync delays occur and I cannot tell whether the problem is in the mesh or my app. Leadership asks, "Is it production-ready?", and I can't answer because I have no visibility into what's happening.

**The Monitoring Fragmentation**

I already use Azure Monitor Managed Prometheus for my AKS cluster—everything from node health to workload metrics lands in one workspace. When I enable Applink mesh, I expect mesh telemetry to show up there too. Instead, control plane metrics are unavailable, and I have to build custom scrapes for data plane components. My unified cluster view is broken. I need mesh metrics in my existing workspace, configured the same way, so I can see the full picture of what's running in my cluster.

### Sam - Site Reliability Engineer

**The 3 AM Escalation**

As an SRE, I get paged when things break. At 3 AM, payments timed out. Tracing pointed to the mesh, but proxies looked healthy. Without control plane metrics, I could not see if stale config, control plane latency, or cert issues were to blame. I escalated and waited, missed SLOs, and a minutes-long diagnosis became two hours.

**The Root Cause Guessing Game**

When incidents hit, I must locate the fault fast. In AKS I can query one workspace to isolate app, node, or Kubernetes control plane issues. With Applink mesh, I lose that unified view: is Istiod keeping up, are cert rotations succeeding, is the control plane overloaded? I need mesh metrics—config push latency, proxy connection success, control plane resource use—in the same workspace as my cluster metrics so I can correlate and diagnose quickly.

### Andrew - Application Developer

**The Configuration Mystery**

As a developer, I want the mesh to just work. I deploy a canary to shift 10% to v2, but traffic does not move. Pods are healthy and the VirtualService looks right. Without mesh telemetry in my monitoring tools, I cannot confirm whether the control plane received, validated, and pushed my config. I waste hours debugging my app code when the issue might be mesh configuration propagation. This lack of visibility makes me hesitant to use mesh features.

**The Performance Black Hole**

After enabling mesh features, response times climb. Is latency in my code, the mesh, or something else? I check my usual monitoring workspace, but there's no mesh telemetry there to help me rule out the service mesh. I can't quickly isolate whether the problem is mine or the platform's, so incident diagnosis drags on and I lose confidence in the mesh.

## Customer and Business Impact

### Customer Impact

- **Preserves operational simplicity**: Mesh metrics integrate into existing cluster monitoring workflows without introducing new tools or configuration patterns
- **Maintains unified cluster visibility**: Customers retain the single-workspace experience they rely on for cluster operations, now extended to include mesh health
- **Enables faster troubleshooting**: Correlation between cluster, control plane, and data plane metrics in one place reduces time spent diagnosing incidents
- **Builds confidence in the mesh**: Complete visibility into control plane and data plane health enables self-service troubleshooting and reduces uncertainty

### Business Impact

- **Accelerates AppLink adoption**: Familiar monitoring patterns reduce friction for AKS customers evaluating and deploying managed mesh
- **Drives AKS platform usage**: Improves adoption of Azure Monitor Managed Prometheus and establishes a clear path to other AKS solutions like Managed Grafana
- **Reduces support load**: Unified observability enables customers to self-diagnose mesh issues, lowering escalations and support costs
- **Strengthens competitive position**: Delivers integrated mesh observability that competitors with fragmented control plane visibility cannot match

## Existing Solutions or Expectations

- **AKS Managed Prometheus pattern**: AKS customers configure Azure Monitor Managed Prometheus to collect cluster metrics (including control plane metrics for managed clusters) in a unified workspace. Applink customers expect the same streamlined experience
- **Alternative service mesh experiences**:
Customers running self-hosted Ambient Mesh or using the Istio Add-on are responsible for deploying and maintaining their own observability stack. They must manually configure Prometheus or OpenTelemetry collectors to scrape metrics from data plane components such as ztunnels and waypoints, and from the mesh control plane itself. These setups operate independently of AKS’ managed monitoring experience, requiring separate configuration, alerting, and visualization pipelines.
- **Shoebox metrics**: Geneva-based platform metrics exist in a separate blade with limited queryability and no Prometheus compatibility. **Note:** Shoebox metrics integration/migration is out of scope for this PRD and will be addressed in a separate workstream
- **Customer expectation**: Applink monitoring should mirror the AKS experience: mesh metrics automatically integrated into the cluster workspace using the same configuration pattern, without manual scraping or manual parallel monitoring infrastructure

## Proposal

Integrate AppLink mesh telemetry into the existing AKS cluster monitoring experience:

- **Unified workspace integration:** Both control plane (Istiod) and data plane (ztunnel, CNI) metrics land in the same Azure Monitor workspace customers already use for cluster operations
- **AKS-aligned configuration:** Customers configure mesh metrics using the same pattern they use for AKS cluster monitoring, preserving operational simplicity
- **Standard Prometheus format:** All metrics exposed in standard Prometheus format, compatible with Azure Monitor Managed Prometheus.
- **Public Preview Scope:** Focus on Azure Monitor Managed Prometheus integration; no custom portal UI or alerting 

For in-depth technical details, please refer to the [design document](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/personalplayground/871992/-Design-Applink-Observability-Data-Plane-and-Control-Plane-Metrics).

## User Experience

AKS customers enable cluster monitoring by installing the Azure Monitor Managed Prometheus add-on (`ama-metrics`), which automatically begins collecting standard cluster metrics (kubelet, Kubernetes control plane components, etc.) and sends them to a configured workspace. Customers then tune what gets collected using a simple configmap in their cluster.

AppLink mesh metrics follow this same pattern. However, mesh metric collection is **off by default** and customers must explicitly enable the AppLink targets they want. This gives customers control over ingestion costs while preserving the familiar AKS configuration workflow.

### Enable cluster monitoring

Customers enable Azure Monitor Managed Prometheus on their AKS cluster using the Azure CLI. See the [official documentation](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli#enable-prometheus-and-grafana) for complete details and additional options.

```bash
### Use default Azure Monitor workspace
az aks create/update --enable-azure-monitor-metrics --name <cluster-name> --resource-group <cluster-resource-group>

### Use existing Azure Monitor workspace
az aks create/update --enable-azure-monitor-metrics --name <cluster-name> --resource-group <cluster-resource-group> --azure-monitor-workspace-resource-id <workspace-name-resource-id>

### Use an existing Azure Monitor workspace and link with an existing Grafana workspace
az aks create/update --enable-azure-monitor-metrics --name <cluster-name> --resource-group <cluster-resource-group> --azure-monitor-workspace-resource-id <azure-monitor-workspace-name-resource-id> --grafana-resource-id <grafana-workspace-name-resource-id>

### Use optional parameters
az aks create/update --enable-azure-monitor-metrics --name <cluster-name> --resource-group <cluster-resource-group> --ksm-metric-labels-allow-list "namespaces=[k8s-label-1,k8s-label-n]" --ksm-metric-annotations-allow-list "pods=[k8s-annotation-1,k8s-annotation-n]"
```

Once enabled, the `ama-metrics` add-on is installed and begins collecting standard AKS cluster metrics into the configured workspace.

### Metrics Configuration via ConfigMap

Customers configure AppLink observability using the same **ama-metrics-settings-configmap** pattern they use for AKS cluster monitoring.    
**Prerequisites**: Azure Monitor Managed Prometheus must be enabled on the cluster with the `ama-metrics` add-on installed.    
The Azure Monitor Managed Prometheus add-on reads this configuration to enable/disable metric collection for both control plane and data plane components.

#### Default Configuration

For customers with Managed Prometheus enabled, the following Applink targets are configured by default:

```diff
default-scrape-settings-enabled: |-
    kubelet = true
    coredns = false
    cadvisor = true
    kubeproxy = false
    controlplane-apiserver = true
    controlplane-kube-controller-manager = false
    controlplane-kube-scheduler = false
    controlplane-etcd = true
    controlplane-cluster-autoscaler = false
    kubestate = true
    
+   ztunnel = false
+   istio-cni = false
+   controlplane-istiod = false
+   waypoint-proxy = false
```

**Available Applink targets:**

- **ztunnel**: Ambient mesh data plane metrics (traffic telemetry, connection stats)
- **istio-cni**: CNI plugin metrics (enable for CNI-specific troubleshooting)
- **controlplane-istiod**: Mesh control plane metrics (pilot metrics, configuration state)
- **waypoint-proxy**: L7 gateway proxy metrics (traffic processing, security policy enforcement)

### Configuration Levels

Applink metrics support three configuration levels in increasing order of granularity, matching the AKS observability model:

#### 1. Off

No metrics collected from a specific component. This is the **default state** for all Applink targets. Customers must explicitly enable targets in the scrape configuration.

```yaml
default-scrape-settings-enabled: |-
    ztunnel = false
    istio-cni = false
    controlplane-istiod = false
    waypoint-proxy = false
```

#### 2. Essential Metrics (Minimal Ingestion Profile)

Customers receive curated metrics for common observability and debugging scenarios with optimized cost. This is the default behavior when a target is enabled.
To enable essential metrics, set the corresponding component to true and ensure minimal ingestion is enabled:

```yaml
default-scrape-settings-enabled: |-
    ztunnel = true
    istio-cni = true
    controlplane-istiod = true
    waypoint-proxy = true

minimal-ingestion-profile: |-
    true
```

#### 3. All Metrics

Customers receive all available metrics from the corresponding component without filtering. Set `minimal-ingestion-profile = false` and enable the target:

```yaml
minimal-ingestion-profile: |-
    false

default-scrape-settings-enabled: |-
    ztunnel = true
    istio-cni = true
    controlplane-istiod = true
    waypoint-proxy = true
```

### Custom Metric Selection

In both Essential Metrics and All Metrics modes, customers can scrape additional specific metrics by adding them to the `default-metrics-keep-list`:

```yaml
minimal-ingestion-profile: |-
    true

default-metrics-keep-list: |-
    istio_request_bytes_bucket
    istio_agent_pilot_xds_expired_nonce

default-scrape-settings-enabled: |-
    ztunnel = true
    controlplane-istiod = true
    waypoint-proxy = true
```

### Cluster Label Alignment

The implementation respects the **cluster-alias** setting in the configmap. If no cluster alias is specified, Applink metrics use the same cluster label as existing Azure Monitor metrics, ensuring consistent labeling across all metrics in the workspace for seamless querying and correlation.

### Minimal Ingestion Profiles

#### Ztunnel Minimal Profile

When `ztunnel = true` and `minimal-ingestion-profile = true`, the following metrics are collected:

| Metric | Purpose |
|--------|---------|
| `istio_build` | Version and build information for support and compatibility verification |
| `istio_xds_connection_terminations_total` | XDS connection health monitoring; expected to spike every ~30min per instance |
| `istio_xds_message_total` | XDS push frequency by resource type (Workloads, Addresses, Authorizations, DNS Tables) |
| `istio_tcp_connections_opened_total` | TCP connection establishment rate |
| `istio_tcp_connections_closed_total` | TCP connection closure rate |
| `istio_tcp_sent_bytes_total` | Outbound traffic volume |
| `istio_tcp_received_bytes_total` | Inbound traffic volume |
| `istio_dns_requests_total` | DNS query rate through ztunnel |
| `workload_manager_active_proxy_count` | Number of active proxies managed by ztunnel |
| `workload_manager_pending_proxy_count` | Number of proxies pending configuration (expected to converge to zero) |

**Coverage**: These metrics support community dashboards and provide visibility into:

- Control plane connectivity health (XDS)
- Traffic flow patterns (TCP connections and throughput)
- DNS resolution activity
- Workload lifecycle management

#### Istio CNI Minimal Profile

When `istio-cni = true` and `minimal-ingestion-profile = true`, the following metrics are collected:

| Metric | Purpose |
|--------|---------|
| `istio_cni_install_ready` | CNI plugin installation readiness status |
| `istio_cni_installs_total` | Count of CNI installation attempts and outcomes |
| `nodeagent_reconcile_events_total` | Node agent reconciliation loop health |
| `ztunnel_connected` | Ztunnel connectivity status from CNI perspective |

**Coverage**: These metrics provide essential visibility into:

- CNI plugin installation and health
- Node agent operational status
- Ztunnel-CNI integration health

#### Istiod (Control Plane) Minimal Profile

When `controlplane-istiod = true` and `minimal-ingestion-profile = true`, the following metrics are collected:

| Metric | Purpose |
|--------|---------|
| `istio_build` | Version and build information for control plane |
| `pilot_xds_pushes` | XDS push rate by resource type (CDS, EDS, LDS, RDS, etc.) |
| `pilot_xds` | Total number of connected proxies to the control plane |
| `pilot_total_xds_rejects` | Configuration rejections by type; indicates invalid or incompatible config |
| `pilot_total_xds_internal_errors` | Internal push errors; potential control plane issues requiring investigation |
| `pilot_xds_push_time_bucket` | Push latency histogram; critical for diagnosing control plane performance |
| `galley_validation_passed` | Successful webhook validations |
| `galley_validation_failed` | Failed webhook validations; indicates configuration issues |

**Coverage**: These metrics support community dashboards and provide visibility into:

- Control plane health and version
- Configuration distribution performance
- Proxy connectivity status
- Configuration validation and errors

**Note**: Ambient mode specific - sidecar injection metrics are excluded as they are not applicable.

#### [waypoint-proxy] Waypoint Proxy Minimal Profile
When `waypoint-proxy = true` and `minimal-ingestion-profile = true`, the following metrics are collected:
| Metric | Purpose |
|--------|---------|
| `istio_build` | Version and build information for waypoint proxy |
| `istio_requests_total` | Total number of requests processed by the waypoint proxy |
| `istio_request_duration_milliseconds_sum` | Sum of request durations for calculating average latency |
| `istio_request_duration_milliseconds_count` | Count of requests for calculating average latency |
| `envoy_cluster_upstream_cx_active` | Number of active upstream connections |
| `envoy_cluster_upstream_cx_connect_fail` | Number of failed upstream connection attempts |
| `envoy_server_memory_allocated` | Memory allocated by the Envoy proxy |
 
**Coverage**: These metrics provide essential visibility into:

- Waypoint proxy health and version
- L7 traffic processing performance
- Connection management and failures
- Resource utilization
- Request latency patterns

#### Cost Optimization

The minimal ingestion profiles exclude:

- **Resource metrics**: CPU, memory usage, goroutines, heap allocations of control and data plane components
- **Detailed event metrics**: Kubernetes registry events, config events, push triggers
- **Push size histograms**: Detailed size distributions
- **Debug counters**: Internal implementation details
- **Client-reported metrics**: Redundant metrics available from server-side perspective
- **Sidecar injection metrics**: Not applicable in ambient mode

Customers requiring additional metrics can add them to `default-metrics-keep-list` or set `minimal-ingestion-profile = false`.

#### Cardinality Considerations

The minimal ingestion profile is designed to keep cardinality manageable:
- An ambient mesh cluster typically emits ~8-12k time series with minimal profile enabled
- Well below the 1 million time series limit for Azure Monitor Managed Prometheus
- Cardinality scales with number of ztunnel replicas and custom resource definitions, not with pod count
- Customers with high CRD counts should monitor their ingestion costs

### Applying Configuration Changes

1. Edit the **ama-metrics-settings-configmap** in the `kube-system` namespace
2. Apply the changes: `kubectl apply -f ama-metrics-settings-configmap.yaml`
3. Configuration updates are detected automatically within 2-3 minutes
4. No pod restarts required

### Customer Benefits

- **Familiar workflow**: Same configuration experience as AKS cluster monitoring.
- **Unified workspace**: All mesh metrics (control plane + data plane) in one queryable location.
- **Standard tools**: Use Grafana dashboards, PromQL queries, and Azure Monitor features.

## Definition of Success

| No. | Outcome | Measure | Target | Priority |
|-----|---------|---------|--------|----------|
| 1 | Unified observability | Control plane + data plane metrics visible in Azure Monitor workspace | 100% | High |
| 2 | AKS-aligned experience | Customers report setup similar to AKS Managed Prometheus | ≥90% satisfaction | High |
| 3 | Managed Prometheus integration | Both metric types visible in Azure Monitor Managed Prometheus workspace | 100% | High |
| 4 | Security and Reliability | Secure access maintained, system stability preserved | ≥99% uptime | High |

## Requirements

### Functional Requirements

| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | Expose Applink control plane (Istiod) metrics from MCP in Prometheus format | High |
| 2 | Enable data plane metrics collection (ztunnel, CNI) via Kubernetes service discovery | High |
| 3 | Ensure system stability and prevent abuse | High |
| 4 | Support Azure Monitor Managed Prometheus workspace integration (primary path) | High |
| 5 | Support BYO Prometheus collectors | Medium |
| 6 | Align configuration experience with AKS Managed Prometheus patterns | High |

### Test Requirements

| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | Verify Azure Monitor Managed Prometheus ingestion of control plane metrics | High |
| 2 | Verify Azure Monitor Managed Prometheus ingestion of data plane metrics | High |
| 3 | Validate correlation queries across control plane and data plane metrics | High |
| 4 | Verify minimal ingestion profile collects only specified metrics | High |
| 5 | Validate configuration changes via configmap are applied correctly | High |

## Dependencies and Risks

### Dependencies

| No. | Requirement or Deliverable | Giver Team / Contact |
|-----|----------------------------|----------------------|
| 1 | MCP namespace deployments (Istiod) | Managed Mesh Platform |


### Risks

- **Control plane metrics collection performance**: Mitigation through capacity planning and monitoring
- **Metrics availability latency**: Mitigation through optimization and monitoring of collection pipeline

## Compete

### AWS (EKS + App Mesh / VPC Lattice)
- EKS App Mesh provides service mesh observability but does not integrate control plane metrics into the standard EKS cluster monitoring experience
- VPC Lattice observability focuses on network metrics, not comprehensive mesh control plane health
- Customers must set up separate monitoring infrastructure for mesh telemetry

### Google Cloud (Anthos Service Mesh)
- Provides managed observability but with limited visibility into managed control plane internals
- Mesh metrics do not automatically integrate into the standard GKE cluster monitoring workspace
- Customers configure mesh observability separately from cluster monitoring

### Differentiation (Public Preview)
- **Preserves AKS operational model**: Mesh metrics integrate into the existing cluster monitoring workspace and configuration pattern—no new tools, workflows, or separate monitoring infrastructure
- **True unified workspace**: Both control plane and data plane metrics land in the same workspace customers use for cluster operations, enabling seamless correlation
- **Cost-optimized minimal profiles**: Pre-configured essential metric sets aligned with official Istio dashboards reduce ingestion costs by 60-80% versus full metric collection
- **Managed experience at preview**: Automatic collection and integration of mesh telemetry with zero custom scraping or pipeline setup required