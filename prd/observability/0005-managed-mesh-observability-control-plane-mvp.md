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

This public preview delivers a unified observability experience for AppLink customers that mirrors the AKS monitoring model. Customers get comprehensive visibility into both Istio control plane (MCP) and data plane metrics through Azure Monitor Managed Prometheus, aligning with the familiar AKS customer experience. Both metric types are available in the same Azure Monitor workspace, enabling seamless correlation and troubleshooting of their service mesh.

## Scope

This PRD defines the public preview for AppLink observability covering both control plane and data plane metrics. It focuses on delivering an AKS-aligned customer experience through:  
- **Unified metrics collection**: Both Istio control plane (MCP) and data plane (ztunnel, CNI) metrics collected and available in the same Azure Monitor workspace via Managed Prometheus.  
- **AKS-aligned experience**: Customers configure observability using the same Azure Monitor Managed Prometheus integration pattern familiar to AKS users.  
- **Secure access**: Authenticated endpoints for scraping control plane metrics using OIDC-based tokens.  
- **Standard Prometheus format**: All metrics exposed in standard Prometheus format, compatible with Azure Monitor and BYO Prometheus collectors.  

Out of scope for public preview: portal UI for control plane-specific metrics, custom alert/recording rules, or extensibility of scrape targets beyond Istio components.

## Glossary

| Term | Definition |
|------|------------|
| MCP (Mesh Control Plane) | Azure-hosted environment running Istio control plane (Istiod) for AppLink, isolated from customer clusters. |
| Data Plane | Istio dataplane (ztunnel, Istio CNI) running inside customer clusters. |
| VMAgent | Prometheus-compatible agent for metrics scraping and remote write. |
| VMSingle | Lightweight metrics storage and federation service used to persist Istio control plane metrics. |
| Auth Proxy | Authentication and rate-limiting layer validating OIDC tokens before granting access to control plane metrics. |

## Problem Statement / Motivation

AppLink runs Istio with an external control plane: Istiod operates in the MCP, while the data plane (ztunnel, CNI) runs in customer clusters. While data plane components run in the cluster, customers need a unified observability solution that provides visibility into both control plane and data plane metrics, matching the integrated monitoring experience AKS customers expect.

Without this unified experience, customers face:
- **Fragmented visibility**: No single pane of glass for mesh health across control and data plane components
- **Complex troubleshooting**: Inability to correlate control plane decisions with data plane behavior
- **AKS experience gap**: Monitoring pattern differs from established AKS Managed Prometheus workflows

This public preview delivers comprehensive mesh observability through Azure Monitor Managed Prometheus, providing authenticated access to both control plane and data plane metrics in a unified workspace, aligned with the AKS customer experience.

## Goals / Non-Goals

### Functional Goals
- Deliver unified control plane and data plane metrics in the same Azure Monitor workspace via Managed Prometheus.  
- Align the customer configuration experience with AKS Managed Prometheus patterns.  
- Enable customers to scrape both Istio control plane and data plane metrics through authenticated endpoints.  
- Expose all mesh metrics in standard Prometheus format consumable by Azure Monitor Managed Prometheus or BYO Prometheus collectors.  

### Non-Functional Goals
- Ensure low-latency metrics availability (≤30s scrape interval).  
- Enforce per-client rate limits for stability and abuse prevention.  
- Provide reliable authentication and authorization without requiring Azure resource integration.  

### Non-Goals
- Portal visualization or custom dashboards specific to mesh metrics (customers use Azure Monitor workspace query/visualization).  
- Pre-configured alerting or recording rules for mesh metrics.  
- Fine-grained access control (per-metric or per-namespace).  
- Customer ability to extend scrape targets beyond Istio control plane and data plane components.  
- Shoebox (Geneva) metrics integration or migration (out of scope for this PRD; will be addressed separately).  

## Narrative / Personas

### Sarah Chen - Platform Engineer

**The Black Box Problem**

As a platform engineer, I roll out AppLink's managed mesh on AKS and must prove it is production-ready. I see data plane metrics (ztunnel, CNI) in-cluster, but the control plane (Istiod in Azure) is opaque. During deploys, config sync delays occur and I cannot tell whether the problem is in the data plane or the control plane. I stitch timestamps from disconnected systems while leadership asks, "Is the mesh or the app broken?" I cannot answer because half the picture is missing.

**The Monitoring Fragmentation**

I already use Azure Monitor Managed Prometheus for AKS. For AppLink mesh, I build custom data plane scrapes, and control plane metrics are unavailable. I cannot create one dashboard for full mesh health, and every reliability report comes with caveats. I need the AKS experience: control and data plane metrics in my existing workspace, configured once and queryable everywhere.

### Marcus Rodriguez - Site Reliability Engineer

**The 3 AM Escalation**

As an SRE, I get paged when things break. At 3 AM, payments timed out. Tracing pointed to the mesh, but proxies looked healthy. Without control plane metrics, I could not see if stale config, control plane latency, or cert issues were to blame. I escalated and waited, missed SLOs, and a minutes-long diagnosis became two hours.

**The Root Cause Guessing Game**

When incidents hit, I must locate the fault fast. In AKS I can isolate app, node, or Kubernetes control plane. In AppLink mesh I am guessing: is Istiod keeping up, are cert rotations succeeding, is the control plane overloaded? I need immediate metrics: config push latency, proxy connection success, and control plane resource use, shown alongside ztunnel errors on the same dashboard.

### Priya Sharma - Application Developer

**The Configuration Mystery**

As a developer, I want the mesh to just work. I deploy a canary to shift 10% to v2, but traffic does not move. Pods are healthy and the VirtualService looks right. I cannot confirm whether the control plane received, validated, and pushed my config. I waste hours on app code when the issue may be propagation delay. This opacity makes me hesitant to use mesh features.

**The Performance Black Hole**

After enabling mesh features, response times climb. Is latency in my code, proxies, or the control plane? Data plane metrics show request durations, but control plane delays in pushing routes are invisible. I need end-to-end metrics to rule out the mesh quickly and refocus on my service.

## Customers and Business Impact

- **Reduces friction for AKS customers**: Familiar Managed Prometheus configuration pattern accelerates AppLink adoption.  
- **Improves trust**: Comprehensive visibility into both control plane and data plane health builds confidence in the managed service.  
- **Reduces support load**: Unified observability enables customers to self-diagnose issues across the full mesh stack.  
- **Accelerates troubleshooting**: Correlation between control plane and data plane metrics reduces MTTR for incidents.  

## Existing Solutions or Expectations

- **AKS Managed Prometheus pattern**: AKS customers configure Azure Monitor Managed Prometheus to collect cluster metrics (including control plane metrics for managed clusters) in a unified workspace. AppLink customers expect the same streamlined experience.  
- **Current AppLink gap**: Data plane metrics require manual configuration, and control plane metrics are not exposed in Prometheus format. No unified collection mechanism exists.  
- **Shoebox metrics**: Geneva-based platform metrics exist in a separate blade with limited queryability and no Prometheus compatibility. **Note:** Shoebox metrics integration/migration is out of scope for this PRD and will be addressed in a separate workstream.  
- **Customer expectation**: AppLink monitoring should mirror the AKS experience: simple Managed Prometheus integration that captures both control plane and data plane metrics in one workspace.

## Proposal

- Deliver unified mesh observability aligned with the AKS Managed Prometheus experience:  
  - **Control Plane Metrics:** `/metrics` endpoint on MCP ingress exposes Istio control plane metrics in Prometheus format with OIDC-based authentication.  
  - **Data Plane Metrics:** Prometheus scrape targets for data plane components (ztunnel, CNI) discoverable and scrapable from customer clusters.  
  - **Unified Configuration:** Customers configure a single Azure Monitor Managed Prometheus instance to collect both control plane and data plane metrics, mirroring the AKS setup pattern.  
  - **Security:** Authenticated access using OIDC-issued Kubernetes service account tokens; per-client rate limits applied.  
  - **Compatibility:** Works seamlessly with Azure Monitor Managed Prometheus (primary path for public preview) and BYO Prometheus collectors.  
  - **Public Preview Scope:** Focus on Azure Monitor Managed Prometheus integration; no custom portal UI or alerting.  

## User Experience

### Configuration (AKS-Aligned Pattern)

Customers follow the familiar AKS Managed Prometheus setup:

1. **Enable Azure Monitor Managed Prometheus** on their Azure Monitor workspace (same workspace used for AKS clusters if applicable).
2. **Configure scraping for AppLink member cluster**:  
   - Data plane components (ztunnel, CNI) are auto-discovered via Kubernetes service discovery.  
   - Control plane endpoint `<mcp-fqdn>/metrics` is added as a static scrape target with OIDC authentication.
3. **View unified metrics**: Both control plane and data plane metrics appear in the Azure Monitor workspace, queryable via PromQL in Grafana or Azure Monitor query interface.

### Sample Prometheus Configuration

```yaml
# Data plane scraping (Kubernetes service discovery)
- job_name: 'applink-data-plane'
  kubernetes_sd_configs:
    - role: pod
      namespaces:
        names: ['kube-system', 'aks-istio-system']
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_label_app]
      regex: ztunnel|istio-cni
      action: keep

# Control plane scraping (authenticated endpoint)
- job_name: 'applink-control-plane'
  static_configs:
    - targets: ['<mcp-fqdn>']
  metrics_path: '/metrics'
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
```

### Customer Benefits
- **Familiar workflow**: Same configuration experience as AKS cluster monitoring.
- **Unified workspace**: All mesh metrics (control plane + data plane) in one queryable location.
- **Standard tools**: Use Grafana dashboards, PromQL queries, and Azure Monitor features.

Operations note (non-goal for customers, for SREs only): minimum health signals include auth success/fail rates, rate-limit violations, scrape/write latencies, and storage saturation.

## Definition of Success

| No. | Outcome | Measure | Target | Priority |
|-----|---------|---------|--------|----------|
| 1 | Unified observability | Control plane + data plane metrics visible in Azure Monitor workspace | 100% | High |
| 2 | AKS-aligned experience | Customers report setup similar to AKS Managed Prometheus | ≥90% satisfaction | High |
| 3 | Managed Prometheus integration | Both metric types visible in Azure Monitor Managed Prometheus workspace | 100% | High |
| 4 | BYO compatibility | BYO Prometheus collectors authenticate and scrape successfully | 100% | Medium |
| 5 | Security | Authentication success rate, rate limiting enforced | ≥99% | High |

## Requirements

### Functional Requirements

| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | Expose Istio control plane (Istiod) metrics from MCP via Prometheus format | High |
| 2 | Enable data plane metrics collection (ztunnel, CNI) via Kubernetes service discovery | High |
| 3 | Provide OIDC-based JWT authentication for control plane endpoint | High |
| 4 | Enforce per-client rate limiting | High |
| 5 | Support Azure Monitor Managed Prometheus workspace integration (primary path) | High |
| 6 | Support BYO Prometheus collectors | Medium |
| 7 | Align configuration experience with AKS Managed Prometheus patterns | High |

### Test Requirements

| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | Verify Azure Monitor Managed Prometheus ingestion of control plane metrics | High |
| 2 | Verify Azure Monitor Managed Prometheus ingestion of data plane metrics | High |
| 3 | Validate correlation queries across control plane and data plane metrics | High |
| 4 | Validate BYO Prometheus scraping via OIDC | High |
| 5 | Confirm rate limiting behavior | Medium |
| 6 | Negative tests: invalid token, expired token → 401 | Medium |
| 7 | Validate configuration matches AKS Managed Prometheus patterns | High |

## Dependencies and Risks

| No. | Requirement or Deliverable | Giver Team / Contact |
|-----|----------------------------|-----------------------|
| 1 | MCP namespace deployments (Istiod) | Managed Mesh Platform |
| 2 | VMAgent/VMSingle deployment artifacts | Observability Platform |
| 3 | OIDC-enabled AppLink member clusters | AppLink RP |

**Risks**:  
- Performance of VMSingle under high load.  
- Authentication drift if member cluster OIDC misconfigured.  
- Latency introduced by federation path.  

## Compete

### AWS (EKS + App Mesh / VPC Lattice)
- EKS App Mesh provides service mesh observability but does not expose centralized MCP metrics in Prometheus format with customer authentication.  
- VPC Lattice observability focuses on network metrics, not Istio control plane health.  

### Google Cloud (Anthos Service Mesh)
- Provides managed observability but with limited visibility into managed control plane internals.  
- No explicit control plane metrics endpoint with customer authentication.  

### Differentiation (Public Preview)
- **AKS-aligned experience**: Unified control plane + data plane observability using the familiar Managed Prometheus pattern.  
- **Comprehensive mesh visibility**: Single workspace for all Istio metrics, enabling full-stack correlation.  
- **Secure, standards-based**: OIDC-authenticated endpoints with standard Prometheus format.  
- **Simplified onboarding**: Configuration mirrors AKS setup, reducing learning curve for existing Azure customers.