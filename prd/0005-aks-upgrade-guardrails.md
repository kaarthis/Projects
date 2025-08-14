---
title: AKS Upgrade Guardrails: SLO‑Gated, Metric‑Aware Upgrades
wiki: ""
pm-owners: [kaarthis]
feature-leads: []
authors: [kaarthis]
stakeholders: []
approved-by: []
status: Draft
last-updated: 2025-08-13
---

# Overview

Before this feature, AKS customers had to hand‑craft blue/green flows and stitch alerts to decide whether to proceed or stop upgrades. Now, AKS customers can declare application SLO guardrails using Azure Managed Prometheus rule groups that the upgrade process enforces with canary and soak checks to automatically pause or abort on anomalies.

## Problem Statement / Motivation

AKS upgrades validate readiness signals (PDBs, probes, API breaks) but miss nuanced, post‑upgrade degradations that do not flip pod readiness immediately: latency regressions, error‑rate spikes, delayed OOMs after node moves, and cascading issues that surface over time. Customers either run quasi‑manual blue/green orchestrations with custom gates or rely on AKS Blue/Green nodepool upgrades rolling out later this year, which simplify cutover but are nodepool‑only and do not evaluate application SLO signals. Many lack the platform automation and observability maturity to do this reliably. We need upgrade‑integrated mechanisms to detect these problems and stop the operation.

Examples observed:
- Added application latency after an upgrade
- Increased error rate after version/image change
- Pods crashing/oomkilling minutes or hours after moving to upgraded nodes
- Cascading issues that manifest progressively across components

## Goals/Non-Goals

### Functional Goals
- Declare SLO guardrails via existing monitoring investments:
  - Prometheus (Azure Managed Prometheus rule groups) via rule names
- Support preflight (checks before upgrade), canary (limited early upgrade phase—upgrade a subset of nodes/pods to catch issues before full rollout), and post-upgrade soak windows (monitoring after upgrade to detect delayed problems)
- On breach: pause or abort; optionally trigger agent pool rollback when available
- Log gating decisions/breaches for audit and diagnostics
- Azure Policy enablement to require guardrails in production
- Scope: Applies to regular rolling upgrades and to Blue/Green agent pool upgrades when available
- Node pool coverage: Supported for VMSS and VM‑based node pools

### Non-Functional Goals
- Guard decision loop P95 ≤ 2 minutes
- Security: platform-native integration with Azure Monitor Managed Prometheus; no customer secrets or external endpoints required
- Reliability: guard evaluation availability ≥ 99.9% during upgrades
- Telemetry: adoption, latency, breach precision/false‑positive rate

### Non-Goals
- Signal sources: v1 supports Azure Managed Prometheus only; Azure Monitor alert rules and self‑hosted/external Prometheus are out of scope and deferred to a later phase
- No fleet-wide or multi-cluster orchestration
- No full blue/green traffic orchestration
- No control plane rollback (unsupported); agent pool rollback only when available
- No auto‑remediation of applications

## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Developer / Cluster Owner | Microsoft.ContainerService/managedClusters/write; Microsoft.AlertsManagement/prometheusRuleGroups/read | Reference existing Managed Prometheus alert rules; upgrade pauses/aborts on breach. Success: No SLO breach escapes an upgrade. |
| Platform Operator | Microsoft.ContainerService/managedClusters/*; Microsoft.AlertsManagement/prometheusRuleGroups/* | Define org defaults; enforce via policy; monitor compliance. Success: Safe upgrades at scale without bespoke pipelines. |

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
- Heavy operator burden maintaining bespoke blue/green flows and manual canary gates; inconsistent coverage across teams.

Business Impact / OKR Alignment:
- Direct contribution to the internal “Workload SLO” OKR by preventing upgrade‑induced SLO breaches via automated gating.
- Upgrade CSAT baseline ≈ 160; targeted uplift through safer‑by‑default upgrades and fewer incidents.
- Expected outcomes: lower Sev2+ post‑upgrade volume, higher safe upgrade completion rate, reduced no‑fly time—tracked in Definition of Success.

## Existing Solutions or Expectations

- Customer‑built blue/green, manual canaries, ad‑hoc alert checks
- AKS Blue/Green Nodepool Upgrade (rolling out): native nodepool cutover; nodepool‑only; no app SLO gating; control plane unchanged
- 3P CD systems with health gates (not integrated into AKS upgrade engine)
- Gaps: fragmentation, high ops cost, no uniform governance, inconsistent quality

## What will the announcement look like?

Announcing SLO‑Gated, Metric‑Aware Upgrades for AKS

AKS upgrades can now honor your application SLOs. Reference Azure Managed Prometheus rule names, configure canary/soak windows, and AKS will pause or abort upgrades on anomalies—no bespoke pipelines required. Public preview for agent pool upgrades this release; GA to follow after feedback.

**Addressing Key Challenges**
- Nuanced regressions (latency, error rate, delayed OOMs) missed by readiness checks
- High operational cost of bespoke blue/green pipelines; lack of governance
- Noise/false positives when alerts aren’t evaluated with warm‑up/debounce logic

**Functionality and Usage**
- Configure guardrails via API/CLI/Portal using existing Azure Managed Prometheus rule groups
- Evaluate in preflight, canary, and post‑upgrade soak windows; on breach → pause/abort; optional agent pool rollback
- Works with AKS Blue/Green nodepool upgrades: guardrails gate canary and pre‑cutover phases

**Availability**
- Public Preview: agent pool upgrades (VMSS and VM node pools); control plane uses pause‑only (no rollback)
- GA target: adds built‑in policies and deeper Managed Prometheus integration
- Blue/Green nodepool upgrades available later this year; guardrails complement, not replace

## Proposal

Options considered (concise):
1) Status quo (manual). No change; risk persists.  
2) Portal‑only checks. UI convenience, no IaC/policy.  
3) Native guardrails (Managed Prometheus first; expand to Azure Monitor/self‑hosted later).  
4) Native guardrails (source‑agnostic from day one).

**Options and Trade‑offs (concise)**
| Option | Pros | Cons | Decision |
|-------|------|------|----------|
| 1. Status quo | Zero engineering | Incidents persist; no governance | Rejected |
| 2. Portal‑only | Faster UX uplift | No IaC/policy; not automatable | Rejected |
| 3. Managed‑first guardrails | Tighter integration, no external endpoints, leverages existing investments; Azure Managed Prometheus present on ~48% of clusters today → meaningful coverage from day one | Leaves Azure Monitor alerts and self‑hosted Prometheus for a later phase | Recommended |
| 4. Guardrails (source‑agnostic) | Meets all users (Managed + self‑hosted + external) | Broader integration surface slows delivery; more security surface | Defer |

Rationale for 3: Managed Prometheus adoption is material (~48% of clusters), providing broad immediate impact with lowest integration and security complexity. We can expand to Azure Monitor alerts and self‑hosted Prometheus endpoints incrementally without blocking the core value.

Breaking changes: None (opt‑in).  
Go‑to‑market: Preview (agent pools), iterate; GA with Azure Policy + deeper Managed Prometheus integration.  

Pricing: Included; standard Azure Monitor/Prometheus costs apply.

False positives/noise mitigation: consecutive breaches, warm‑up suppression, debounce windows, cooldowns, and customer‑selected signals only.

Security posture: Platform-native integration; no customer-managed endpoints or secrets required.

## Observability & Troubleshooting Experience

### Failure Visibility & Diagnostics

- **Manual Upgrades:**
  - Failures due to guardrail breaches are shown in CLI/Portal with clear error messages: which SLO(s) breached, metric, threshold, observed value, and evaluation window.
  - Diagnostic logs and gating decision summaries are available via `az aks upgrade-guards show` and in the Portal diagnostics blade.
  - Users can review the decision timeline, including timestamps, signals, and breach rationale.
  - Retry: after fixing the root cause (e.g., alert resolved), users can re-initiate the upgrade from CLI/Portal.

- **Auto-Upgrades:**
  - Failures are logged in the cluster's activity log and surfaced in Azure Monitor (event details, breach context).
  - Notifications can be sent via Action Groups if configured.
  - Retry: auto-upgrades do not auto-retry after a breach; customers must manually resume or re-trigger after review.

- **Level of Detail:**
  - Both manual and auto-upgrades provide: breached SLO name, metric, threshold, observed value, evaluation window, and recommended next steps.
  - Portal and CLI expose a diagnostics panel with evaluation history and links to rule groups.

## User Experience 

### API
Resource model (child resources) and operations

This feature is modeled as child resources of the cluster so that configuration and status are easy to discover and RBAC/policy can target them directly.

Resource types
- Microsoft.ContainerService/managedClusters/upgradeGuards (one per cluster; fixed name "default")
- Microsoft.ContainerService/managedClusters/upgradeGuards/evaluations/{upgradeRunId} (read‑only, per‑upgrade timeline)

Singleton explanation: there is at most one upgradeGuards resource per cluster, and its ARM path always ends with `/upgradeGuards/default` (you don’t choose a custom name).

Note: v1 scope is cluster‑level only (no per‑agentPool resource).

Operations (ARM)
- PUT managedClusters/{clusterName}/upgradeGuards/default — create/update config
- GET managedClusters/{clusterName}/upgradeGuards/default — get config + current status
- DELETE managedClusters/{clusterName}/upgradeGuards/default — remove config
- GET managedClusters/{clusterName}/upgradeGuards/default/evaluations — list evaluations for recent upgrade runs
- GET managedClusters/{clusterName}/upgradeGuards/default/evaluations/{upgradeRunId} — get one evaluation timeline
(Same shapes apply for the agent pool child resource path.)

Prometheus linkage and ID requirements
- `prometheus.ruleGroupIds` must be full ARM resource IDs of `Microsoft.AlertsManagement/prometheusRuleGroups`, for example: `/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.AlertsManagement/prometheusRuleGroups/{ruleGroupName}`. Short names or partial IDs are not accepted.
- Optional `prometheus.ruleNames[]` acts as an allowlist filter within the provided rule groups. If omitted, all alerting rules in those groups are eligible. Matching is by exact rule name.
- On PUT, AKS validates that each rule group exists and is readable with the caller’s/cluster’s identity. If not, the request fails with clear diagnostics.
- Multiple rule groups are supported (1–16). Duplicates are ignored.
- Policy can audit/require IDs via alias: `Microsoft.ContainerService/managedClusters/upgradeGuards.prometheus.ruleGroupIds[*]`.

Example: PUT (create/update) child resource
```http
PUT https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedClusters/{clusterName}/upgradeGuards/default?api-version=2024-09-01
Content-Type: application/json
{
  "properties": {
    "enabled": true,
    "evaluation": {
      "preflightMinutes": 10,
      "canaryMinutes": 20,
      "soakMinutes": 60,
      "consecutiveBreachesRequired": 2
    },
    "actions": {
      "onBreach": "pause",
      "onBreachAgentPool": { "rollbackEnabled": true }
    },
    "prometheus": {
      "ruleGroupIds": [
        "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.AlertsManagement/prometheusRuleGroups/{ruleGroupName}"
      ],
      "ruleNames": ["HighErrorRate", "P95LatencySpike"]
    }
  }
}
```

Example: GET child resource (config + status)
```http
GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedClusters/{clusterName}/upgradeGuards/default?api-version=2024-09-01
```
Response (excerpt)
```json
{
  "name": "default",
  "type": "Microsoft.ContainerService/managedClusters/upgradeGuards",
  "properties": {
    "enabled": true,
    "evaluation": { "preflightMinutes": 10, "canaryMinutes": 20, "soakMinutes": 60, "consecutiveBreachesRequired": 2 },
    "actions": { "onBreach": "pause", "onBreachAgentPool": { "rollbackEnabled": true } },
    "prometheus": {
      "ruleGroupIds": [
        "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.AlertsManagement/prometheusRuleGroups/{ruleGroupName}"
      ],
      "ruleNames": ["HighErrorRate", "P95LatencySpike"]
    },
    "status": {
      "phase": "canary",                      
      "decision": "continue",                 
      "currentUpgradeRunId": "{upgradeRunId}",
      "lastEvaluation": {
        "timestamp": "2025-08-13T10:00:00Z",
        "ruleStatuses": [
          { "name": "HighErrorRate", "firing": false, "consecutiveCount": 0 },
          { "name": "P95LatencySpike", "firing": false, "consecutiveCount": 0 }
        ]
      },
      "breaches": []
    }
  }
}
```

Example: LIST evaluations (per upgrade run)
```http
GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedClusters/{clusterName}/upgradeGuards/default/evaluations?api-version=2024-09-01
```
Response (excerpt)
```json
{
  "value": [
    {
      "name": "{upgradeRunId}",
      "properties": {
        "startedAt": "2025-08-13T09:58:00Z",
        "completedAt": "2025-08-13T11:20:00Z",
        "decision": "completed",
        "phaseDecisions": [
          { "phase": "preflight", "decision": "continue" },
          { "phase": "canary", "decision": "continue" },
          { "phase": "soak", "decision": "completed" }
        ],
        "breaches": []
      }
    }
  ]
}
```

Example: GET one evaluation (failure)
```http
GET https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedClusters/{clusterName}/upgradeGuards/default/evaluations/{upgradeRunId}?api-version=2024-09-01
```
Response (excerpt)
```json
{
  "name": "{upgradeRunId}",
  "properties": {
    "startedAt": "2025-08-13T09:58:00Z",
    "decision": "paused",
    "pauseReason": {
      "phase": "soak",
      "action": "pause",
      "breaches": [
        { "ruleName": "HighErrorRate", "firing": true, "observedValue": 0.12, "threshold": 0.05, "consecutiveCount": 2 }
      ]
    },
    "timeline": [
      { "time": "2025-08-13T10:00:00Z", "phase": "preflight", "decision": "continue" },
      { "time": "2025-08-13T10:40:00Z", "phase": "canary", "decision": "continue" },
      { "time": "2025-08-13T11:15:00Z", "phase": "soak", "decision": "pause" }
    ]
  }
}
```

Why a child resource?
- Clear status surface (GET on one resource shows spec + live status)
- Dedicated RBAC and Policy targeting
- Single cluster‑scope config that applies to all node pools
- Cleaner Portal/CLI mental model than burying state inside upgrade operations

**Contract: Customer vs AKS (Managed Prometheus scope)**
- Managed Prometheus (Customer provides): Rule group resource IDs (full ARM IDs of `Microsoft.AlertsManagement/prometheusRuleGroups`) in the connected workspace, and optionally a list of ruleNames within those groups to enforce. Docs: https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-rule-groups
- AKS Responsibilities: Poll rule status during preflight/canary/soak, apply consecutive breach logic, decide pause/abort/rollback, emit diagnostics. Never mutates customer rules or thresholds.
- AKS Non‑Responsibilities: Creating/editing alert rules, changing thresholds, auto‑remediation.

### Health Guard Properties (Merged Reference)

| Property | Description (Concise) | Type | Allowed / Range | Default (if omitted) | Required When | Mutable After Create / During Upgrade |
|----------|-----------------------|------|-----------------|----------------------|---------------|---------------------------------------|
| `healthGuards.enabled` | Master switch for SLO guardrails. | bool | true / false | false | Always (customer decides) | Yes (any time) |
| `evaluation.preflightMinutes` | Pre-upgrade warm-up / validation window; upgrade pauses immediately if a required alert is already firing at start. | int | 0–60 | 10 (if enabled) | `enabled=true` | Yes (until preflight starts) |
| `evaluation.canaryMinutes` | Limited early (partial) upgrade window to catch initial regressions. | int | 5–180 | 20 | `enabled=true` | Yes (only before canary phase begins) |
| `evaluation.soakMinutes` | Post-upgrade observation window for delayed / cascading issues. | int | 10–360 | 60 | `enabled=true` | Yes (only before soak phase begins) |
| `evaluation.consecutiveBreachesRequired` | Debounce: number of consecutive evaluations required to treat a firing signal as a breach. | int | 1–5 | 2 | `enabled=true` | Yes (any time; affects future decisions) |
| `actions.onBreach` | Action when breach threshold met: pause (halt & await user) or abort (terminate upgrade). Control plane forced to pause-only. | enum | `pause` \| `abort` | `pause` | `enabled=true` | No (immutable per in-progress upgrade) |
| `actions.onBreachAgentPool.rollbackEnabled` | Allows Blue/Green agent pool rollback on breach (when supported). | bool | true / false | false | Blue/Green scenario | No (immutable per in-progress upgrade) |
| `prometheus.ruleGroupIds[]` | Full resource IDs of Managed Prometheus rule groups to evaluate. All rules in these groups are eligible unless filtered by ruleNames. | array<string> | 1–16 IDs | – | `healthGuards.enabled=true` | Yes (cannot remove groups actively evaluating mid-phase) |
| `prometheus.ruleNames[]` | Optional filter: specific alert rule names within the provided rule groups to enforce. If omitted, all alerting rules in the groups apply. | array<string> | 0–64 names | – | Optional | Yes (cannot remove names actively breaching mid-phase) |
| `rollbackEnabled` (convenience alias of `actions.onBreachAgentPool.rollbackEnabled`) | Convenience alias for rollback toggle in Blue/Green upgrades. | bool | true / false | false | Blue/Green scenario | No (per in-progress upgrade) |

Notes:
- At least one `prometheus.ruleGroupIds` entry is required when `enabled=true`. `ruleNames` is optional and acts as an allowlist filter.
- Mutation guards: Values cannot be shortened/changed for a phase already underway (service returns 409).
- Control plane upgrades: `actions.onBreach` treated as `pause` regardless of supplied `abort`.
- Rollback only when agent pool Blue/Green supported.

### Use Case Scenarios

#### Managed Prometheus (Rule Groups)
**Prerequisites (Customer provides):**
- Managed Prometheus enabled (workspace connected to cluster)
- Prometheus rule group with alerting rules (e.g., HighErrorRate, P95LatencySpike)
- Rule names to enforce
**Where to find rule group IDs:** Portal: Monitor > Metrics (Prometheus) > Rule groups > select group > JSON view to copy Resource ID; or ARM/CLI lookup. Rule names appear under `properties.rules.name` if you choose to filter.
**Steps:**
1. Create / verify rule group (Docs: https://learn.microsoft.com/azure/azure-monitor/essentials/prometheus-metrics-rule-groups) with SLO rules.
2. Collect ruleGroupIds (full ARM IDs) and optional ruleNames to enforce.
3. Enable guardrails with ruleGroupIds and optional ruleNames filter:
   ```sh
   az aks upgrade -g myRG -n myCluster --kubernetes-version X --enable-upgrade-guards \
     --guards-prom-rule-group-ids \
       "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.AlertsManagement/prometheusRuleGroups/{ruleGroupName}" \
     --guards-prom-rule-names HighErrorRate P95LatencySpike \
     --guards-preflight 10 --guards-canary 20 --guards-soak 60 --guards-consecutive 2
   ```
4. AKS polls Managed Prometheus rule status; pauses on breaches.
5. Customer inspects alert (Portal: Monitor > Alerts or Prometheus rule groups blade), resolves issue, resumes.

API Example (Request - PATCH cluster):
```http
PATCH https://management.azure.com/subscriptions/{subId}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}?api-version=2024-09-01
Content-Type: application/json
{
  "properties": {
    "upgradePolicy": {
      "healthGuards": {
        "enabled": true,
        "evaluation": { "preflightMinutes": 10, "canaryMinutes": 20, "soakMinutes": 60, "consecutiveBreachesRequired": 2 },
        "actions": { "onBreach": "pause" },
        "prometheus": {
          "ruleGroupIds": [
            "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.AlertsManagement/prometheusRuleGroups/{ruleGroupName}"
          ],
          "ruleNames": ["HighErrorRate", "P95LatencySpike"]
        }
      }
    }
  }
}
```
API Example (Response excerpt - evaluation snapshot):
```json
{
  "properties": {
    "upgradePolicy": {
      "healthGuards": {
        "lastEvaluation": {
          "phase": "canary",
          "ruleStatuses": [
            {"name": "HighErrorRate", "firing": true, "consecutiveCount": 1},
            {"name": "P95LatencySpike", "firing": false, "consecutiveCount": 0}
          ],
          "decision": "continue"
        }
      }
    }
  }
}
```

### CLI Experience

New (concise) commands targeting the cluster‑level child resource:
- Create/Update:
  az aks upgrade-guards set -g {resourceGroupName} -n {clusterName} \
    --preflight 10 --canary 20 --soak 60 --consecutive 2 \
    --action pause \
    --prom-rule-group-ids \
      "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.AlertsManagement/prometheusRuleGroups/{ruleGroupName}" \
    --prom-rule-names HighErrorRate P95LatencySpike
- Show current config + status:
  az aks upgrade-guards show -g {resourceGroupName} -n {clusterName}
- Delete config:
  az aks upgrade-guards delete -g {resourceGroupName} -n {clusterName}
- List evaluations (upgrade runs):
  az aks upgrade-guards evaluations list -g {resourceGroupName} -n {clusterName}
- Show one evaluation:
  az aks upgrade-guards evaluations show -g {resourceGroupName} -n {clusterName} --run-id {upgradeRunId}

Output highlights
- show: phase, decision, current run id, last evaluation (ruleStatuses)
- evaluations list: startedAt/completedAt, per‑phase decisions, breaches summary

### Portal Experience

- Location: Cluster > Upgrades > Upgrade Guards (Preview)
- Configure (child resource):
  - Enable
  - Preflight/Canary/Soak minutes; Consecutive breaches; Action (pause|abort)
  - Managed Prometheus: select Rule Group (by Resource ID) and optional Rule names
- Status panel (read‑only):
  - Current phase, decision, last evaluation ruleStatuses, breaches (if any)
- Evaluations tab:
  - List recent upgrade runs with per‑phase decisions; open details for breach context
- Failure UX:
  - Upgrade page shows banner with phase, rule, observed vs threshold, and action taken

### Policy Experience

- Require child resource present and enabled for production
  - Alias: Microsoft.ContainerService/managedClusters/upgradeGuards.enabled
- Audit required Rule Group IDs
  - Alias: .../managedClusters/upgradeGuards.prometheus.ruleGroupIds[*]
- DeployIfNotExists: stamp org defaults (evaluation windows, action, rule group IDs)

# Definition of Success

## Expected Impact: Business, Customer, Technology

| No. | Outcome | Measure | Target | Priority |
|-----|---------|---------|--------|---------|
| 1 | Fewer upgrade‑induced incidents | Post‑upgrade Sev2+ tied to upgrades | -50% (6 months) | High |
| 2 | Safer, faster upgrades | Upgrades without manual pause | +30% (2 quarters) | High |
| 3 | Adoption | Prod clusters with guards configured | 70% (2 quarters) | High |
| 4 | Decision latency | Guard decision loop P95 | ≤2 min | Medium |

# Requirements

## Functional Requirements (concise)
| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | Cluster‑level child resource: upgradeGuards (PUT/GET/DELETE) | High |
| 2 | Managed Prometheus integration via ruleGroupIds (+ optional ruleNames filter) | High |
| 3 | Evaluation windows (preflight, canary, soak) + consecutive breach logic | High |
| 4 | Actions: pause | abort | High |
| 5 | Status surface on child resource; evaluations per upgrade run (LIST/GET) | High |
| 6 | Policy/RBAC targeting the child resource | Medium |

## Test Requirements (concise)
| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | E2E: set/show/delete config; run upgrade; success path | High |
| 2 | Breach path: trigger firing rule → pause/abort with correct diagnostics | High |
| 3 | Scale: concurrent guarded upgrades across many clusters | High |
| 4 | Validation: ruleGroupIds exist; ruleNames belong to groups | High |
| 5 | Resilience: fail‑closed behavior on transient errors/timeouts | High |

# Dependencies and risks

| No. | Requirement or Deliverable | Giver Team / Contact | Risk / Mitigation |
|-----|----------------------------|----------------------|-------------------|
| 1 | AlertsManagement Prometheus Rule Groups API (read-only) | Azure Monitor (Alerts/Prometheus) | API version drift; lock to preview api-version and add compat shims |
| 2 | AKS CLI commands (upgrade-guards + evaluations) | AKS CLI | Schedule slip; ship via extension first, then merge to core |
| 3 | Portal blade (Upgrade Guards + Evaluations) | AKS UX/Portal | Staged rollout; fall back to ARM/CLI if delayed |
| 4 | Built-in Policy definitions + aliases | Azure Policy | Start with samples; add built-ins once aliases finalize |
| 5 | RBAC read on rule groups | Customer tenancy | Validation + actionable diagnostics when permissions missing |
| 6 | Upgrade engine decision loop scale/SLO | AKS Service | Capacity planning, backoff, circuit breakers; fail-closed to pause |
| 7 | Optional rollback wiring to Blue/Green | AKS Blue/Green | Guardrails work without rollback; feature-flag coupling |

# Compete

## GKE
- Strengths: mature upgrade workflows (surge, PDB-aware), maintenance windows/exclusions, strong fleet policy story. (Refs: [Surge upgrades](https://cloud.google.com/kubernetes-engine/docs/how-to/node-pool-upgrade#surge-upgrades), [Pod Disruption Budgets](https://cloud.google.com/kubernetes-engine/docs/how-to/pod-disruption-budgets), [Maintenance windows/exclusions](https://cloud.google.com/kubernetes-engine/docs/how-to/maintenance-windows-and-exclusions), [Fleet/Anthos overview](https://cloud.google.com/anthos/fleet-management/docs/overview))
- Gap vs this feature: no first-class app SLO gating integrated into upgrade orchestration; customers wire Cloud Monitoring/Prometheus alerts via external CD gates.
- Positioning: AKS integrates app SLO signals natively into the upgrade engine with queryable status and policyable config.

## EKS
- Strengths: managed node group upgrades with maxUnavailable, health checks; broad ecosystem integrations (Argo CD, Flux). (Refs: [Managed node group update behavior](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-update-behavior.html), [Update config: maxUnavailable](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html#managed-node-group-update-config), [Argo CD on EKS](https://www.eksworkshop.com/docs/gitops/argocd/), [Flux on EKS](https://fluxcd.io/docs/use-cases/gitops-eks/))
- Gap vs this feature: no built-in app SLO gates in upgrade orchestration; typical pattern is CloudWatch/Prometheus alerts in pipelines/manual checks.
- Positioning: AKS offers built-in, policy-governed SLO guardrails that pause/abort upgrades without bespoke pipelines.

# Appendix: FAQ

- Why model this as a child resource instead of an inline cluster property?
  - Clear, queryable status (config + live state in one GET), first-class RBAC/policy targeting, independent lifecycle/versioning from the core cluster spec.

- Why is it a singleton with a fixed name "default" (no custom name)?
  - One source of truth per cluster avoids conflicting configs and name sprawl. A stable ARM path (/upgradeGuards/default) makes RBAC, Policy aliases, CLI/Portal, and automation simple and consistent. It also reduces drift and eases DeployIfNotExists stamping of org defaults. If we add pool-level resources or reusable profiles later, the cluster-level default remains a single, predictable anchor.

- Why only Azure Managed Prometheus in v1 and not self-hosted Prometheus or Azure Monitor alerts?
  - Adoption (~48% of clusters), lowest integration/identity complexity, fastest path to value. We can add Azure Monitor alerts and self‑hosted endpoints in later phases.

- Does this gate control plane upgrades?
  - Control plane honors pause-only semantics; no rollback. Agent pool upgrades can optionally rollback when Blue/Green is enabled.

- Do I have to specify rule names?
  - No. If omitted, all alerting rules in the provided rule groups are eligible. Use ruleNames to allowlist a subset.

- How do you reduce false positives/noise?
  - Consecutive breach counts, warm-up suppression in preflight, debounce windows, and explicit customer-selected signals.

- What happens if the rule group API is temporarily unavailable?
  - Fail-closed to pause with diagnostics; customers can retry once availability is restored.

- How do I find the rule group resource ID safely?
  - Copy from the rule group’s JSON in Portal/ARM. Use placeholders in docs. Provide full ARM IDs in automation (Policy/CLI/IaC).

- Can I reuse one guard configuration across many clusters?
  - Not in v1. Considered for the future via a reusable profile + cluster binding.

- Does this replace blue/green upgrades?
  - No. It complements them by adding app SLO gating to canary/soak phases and optional rollback.

