---
title: Managed Mesh Observability — MCP Control Plane Metrics MVP
wiki: ""
pm-owners: [Chase]
feature-leads: []
authors: [Chase]
stakeholders: [Shashank, Ahmed, Jorge, Fuyuan, Aritra]
approved-by: []
---

# Overview

This MVP gives AppLink customers unified, standards-based visibility into their service mesh by bringing Istio control plane (MCP) metrics into the same monitoring workspace as cluster data plane metrics. Customers can securely scrape control plane metrics and consume them in Azure Monitor or any Prometheus-compatible solution.

## Scope

This PRD defines the MVP for MCP control plane observability. It focuses on three capabilities:  
- Unified metrics: control plane and data plane metrics available in the same Azure Monitor workspace.  
- Secure scraping: authenticated endpoints to scrape Istio control plane metrics.  
- Prometheus compatibility: control plane metrics exposed in standard Prometheus format for use with Azure Monitor or BYO Prometheus collectors.  

Out of scope for MVP: portal UI for control plane metrics, customer-managed alert/recording rules, or extensibility of scrape targets.

## Glossary

| Term | Definition |
|------|------------|
| MCP (Mesh Control Plane) | Azure-hosted environment running Istio control plane (Istiod) for AppLink, isolated from customer clusters. |
| Data Plane | Istio dataplane (ztunnel, Istio CNI) running inside customer clusters. |
| VMAgent | Prometheus-compatible agent for metrics scraping and remote write. |
| VMSingle | Lightweight metrics storage and federation service used to persist Istio control plane metrics. |
| Auth Proxy | Authentication and rate-limiting layer validating OIDC tokens before granting access to control plane metrics. |

## Problem Statement / Motivation

AppLink runs Istio with an external control plane: Istiod operates in the MCP, while the data plane runs in customer clusters. Azure Monitor Metrics already covers the data plane, but customers have no visibility into MCP control plane health and performance. This gap impedes incident triage, upgrade validation, and end-to-end correlation. The MVP resolves this by exposing authenticated, Prometheus-format Istiod metrics from MCP into the same workspace as data plane metrics, consumable by Azure Monitor and BYO Prometheus.

## Goals / Non-Goals

### Functional Goals
- Enable control plane and data plane metrics in the same Azure Monitor workspace.  
- Enable customers to scrape Istio control plane metrics through authenticated endpoints.  
- Expose control plane metrics in standard Prometheus format consumable by any Prometheus-compatible collector.  

### Non-Functional Goals
- Ensure low-latency metrics availability (≤30s scrape interval).  
- Enforce per-client rate limits for stability and abuse prevention.  
- Provide reliable authentication and authorization without requiring Azure resource integration.  

### Non-Goals
- Portal visualization or dashboards specific to control plane metrics.  
- Prometheus-based alerting or recording rules for control plane metrics.  
- Fine-grained access control (per-metric or per-namespace).  
- Customer ability to extend scrape targets beyond Istiod.  

## Narrative / Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Platform Engineer | Microsoft.AppLink/appLinkMembers/* | Scrapes Istiod metrics into existing Grafana dashboards alongside data plane metrics. Success = can see unified mesh health signals. |
| SRE | Microsoft.AppLink/appLinkMembers/read | Queries Azure Monitor workspace and confirms Istiod health/latency trends. Success = can correlate control plane issues with data plane behavior. |

## Customers and Business Impact

- Improves trust by giving customers visibility into MCP control plane health.  
- Reduces support escalations by enabling self-diagnosis of control plane issues.  
- Simplifies monitoring by unifying control and data plane metrics in one workspace.  

## Existing Solutions or Expectations

- Shoebox metrics (Geneva) surface platform-level signals in a separate blade with limited queryability and formatting differences from Istio, creating a split experience from Azure Monitor Workspace where data plane metrics live.  
- AKS CCP metrics are scraped by a control-plane collector tied to Managed Prometheus and configured per cluster; this doesn’t apply to AppLink’s separate MCP and limits BYO scenarios.  
- Net: customers lack a direct, authenticated, Prometheus-format view of AppLink MCP control plane metrics.

## Proposal

- Deliver a secure, simple customer surface for MCP control plane metrics:  
  - **Surface:** `/metrics` endpoint on MCP ingress exposes Istio control plane metrics in Prometheus format.  
  - **Security:** Authenticated access using OIDC-issued Kubernetes service account tokens; per-client rate limits applied.  
  - **Compatibility:** Works with Azure Monitor Managed Prometheus and BYO Prometheus collectors without special adapters.  
  - **Operability:** No new portal UI in MVP; future CLI enable/disable for member metrics may be added.  

## User Experience

- Configure Prometheus (Azure Monitor Managed Prometheus or BYO) to scrape `<mcp-fqdn>/metrics` with a Kubernetes service account token from the member cluster.  
- No additional cluster permissions are required beyond obtaining the token.  
- Customers view unified dashboards with MCP control plane and cluster data plane metrics in one workspace.  

Sample scrape job:

```yaml
- job_name: 'applink-control-plane'
  static_configs:
    - targets: ['<mcp-fqdn>']
  metrics_path: '/metrics'
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
```

Operations note (non-goal for customers, for SREs only): minimum health signals include auth success/fail rates, rate-limit violations, scrape/write latencies, and storage saturation.

## Definition of Success

| No. | Outcome | Measure | Target | Priority |
|-----|---------|---------|--------|----------|
| 1 | Unified observability | Control plane + data plane metrics visible in Azure Monitor workspace | 100% | High |
| 2 | Managed/Grafana visibility | Istiod metrics visible in Managed Prometheus or Grafana dashboards | 100% | High |
| 3 | BYO compatibility | BYO Prometheus collectors authenticate and scrape successfully | 100% | High |
| 4 | Security | Authentication success rate, rate limiting enforced | ≥99% | High |

## Requirements

### Functional Requirements

| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | Expose Istiod metrics from MCP via Prometheus format | High |
| 2 | Provide OIDC-based JWT authentication | High |
| 3 | Enforce per-client rate limiting | High |
| 4 | Support Azure Monitor workspace integration | High |
| 5 | Support BYO Prometheus collectors | Medium |

### Test Requirements

| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | Verify Azure Monitor ingestion of Istiod metrics | High |
| 2 | Validate BYO Prometheus scraping via OIDC | High |
| 3 | Confirm rate limiting behavior | Medium |
| 4 | Negative tests: invalid token, expired token → 401 | Medium |

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

### Differentiation (MVP)
- Unified data plane + MCP control plane observability in the same workspace.  
- Secure, OIDC-based scraping endpoints consumable by Azure Monitor or BYO Prometheus.  
- Clear rate-limited, authenticated surface without requiring Azure resource permissions.