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
  - Prometheus (Azure Managed Prometheus rule groups)
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
- No fleet-wide or multi-cluster upgrade orchestration (no cross-cluster scheduling/ordering). Fleet-wide configuration governance is supported via reusable profiles + Azure Policy.
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

Managed Prometheus Adoption (Feb 16–Aug 13, 2025)
- Internal clusters:
  - Start: 12,695
  - End: 16,797
  - Growth: +4,102
- External clusters:
  - Start: 23,858
  - End: 31,536
  - Growth: +7,678

This strong and consistent growth across internal and external environments underscores increasing reliance on Managed Prometheus for observability at scale—making a compelling case for continued investment.

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

AKS upgrades can now honor your application SLOs. Reference Azure Managed Prometheus rule groups, configure canary/soak windows, and AKS will pause or abort upgrades on anomalies—no bespoke pipelines required. Public preview for agent pool upgrades this release; GA to follow after feedback.

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
  - Diagnostic logs and gating decision summaries are available via `az aks upgrade-gates show` and in the Portal diagnostics blade.
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

API Design options 

Shared contract
- Signals: Azure Managed Prometheus only (v1). Customers provide full ARM IDs of rule groups and may include ruleNames.
- Surfaces: cluster exposes live status; per-upgrade timelines via evaluations; both include operationId, correlationId, scope, agentPool, requestedVersion.
- Identity in results: every rule has ruleGroupId (full ARM ID) + ruleName; observed vs threshold is returned.

Option 1 — Cluster child (singleton)
- Contract (ARM):
  - Config/status at `managedClusters/{cluster}/upgradeGates/default`
  - Evaluations at `managedClusters/{cluster}/upgradeGates/default/evaluations/{upgradeRunId}`
  - PUT body: `properties.enabled`, `properties.evaluation`, `properties.actions`, `properties.prometheus.ruleGroupIds[]`, optional `properties.prometheus.ruleNames[]`
- Pros (customer): simple mental model; config + status in one GET; clean RBAC/Policy targeting; easy future pool-level override.
- Cons (customer): per-cluster updates; org-wide changes require many writes.

Option 2 — Reusable profile + binding (preferred)
- Contract (ARM):
  - Reusable spec at `upgradeGateProfiles/{profileName}` (RG/sub scope; no status)
  - Cluster binds by setting `properties.profile.id` on `/managedClusters/{cluster}/upgradeGates/default`; profile is authoritative and snapshotted at run start
- Pros (customer): manage once, reuse across hundreds of clusters; strong governance; fewer writes; consistent defaults; still get cluster-local status/evaluations.
- Cons (customer): indirection (profile + binding) to learn; profile lifecycle/versioning to manage.

Preferred design
- We prefer Option 2 for fleet-scale usability and governance while retaining the child for status/RBAC.

Why Option 2 is preferred (expanded)
- Fleet-scale configuration governance (not cross-cluster orchestration): update one profile to affect hundreds of clusters instead of N per-cluster writes.
 - Governance and RBAC: profiles can be authored by platform teams; clusters only bind by ID. Azure Policy can require a specific profile or any profile binding.
 - Consistency and drift control: binding + snapshot-at-upgrade-start prevents mid-run drift; easy to audit which profile governed a run.
 - Safer rollouts: profile versioning/rotation enables ring-based rollouts by rebinding subsets, without editing every cluster.
 - Operational efficiency: fewer ARM writes lowers risk of throttling and reduces operational toil.
 - Discoverability preserved: status and evaluations remain on the cluster child, so operators don’t chase central resources for live health.

ARM operations (Option 2 — profile + binding)
- Child (cluster):
  - PUT /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGates/default?api-version=2024-09-01
  - GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGates/default?api-version=2024-09-01
  - DELETE /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGates/default?api-version=2024-09-01
  - GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGates/default/evaluations?api-version=2024-09-01
  - GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGates/default/evaluations/{upgradeRunId}?api-version=2024-09-01
- Profiles (reusable spec):
  - PUT/GET/DELETE /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/upgradeGateProfiles/{profileName}?api-version=2024-09-01

Notes
- The child resource is the status/diagnostics surface and the binding point (properties.profile.id). Profiles hold reusable spec; no status.
- Evaluations are read-only and keyed by upgradeRunId; shapes include upgradeRef (operationId, correlationId, scope, agentPool, requestedVersion).

Prometheus linkage and identity
- Provide full ARM IDs for `Microsoft.AlertsManagement/prometheusRuleGroups` in `prometheus.ruleGroupIds[]`.
- Optional `prometheus.ruleNames[]` may be included for clarity/validation; in v1 they do not restrict enforcement—ALL alerting rules in listed groups are enforced.
- On PUT, AKS validates each group exists and is readable; invalid/unauthorized IDs return clear 4xx errors.
- Multiple groups supported (1–16); duplicates ignored. Policy alias example: `Microsoft.ContainerService/managedClusters/upgradeGates.prometheus.ruleGroupIds[*]`.

Identity and RBAC
- Runtime reads are performed using the cluster’s managed identity (AKS service identity) during upgrades.
- Required permission: `Microsoft.AlertsManagement/prometheusRuleGroups/read` on each referenced rule group scope.
- Validation on PUT checks existence and readability by the runtime identity; failures return 400 (invalid ID) or 403 (forbidden) with actionable diagnostics.

Use case scenarios (Option 2 — profile + binding)
This section shows the complete contract with requests and responses, and answers:
- How customers provide alerts: create a reusable profile with ruleGroupIds (and optional ruleNames), then bind it on the cluster child.
- How operators manage hundreds of clusters: enforce binding via Azure Policy/IaC; rotate/replace the profile to change org defaults fleet-wide without touching each cluster.
- How customers see results and trace decisions: GET the child for live status/lastEvaluation/breaches with operationId/correlationId; GET evaluations/{upgradeRunId} for the full timeline; same via CLI/Portal.

0) Get reusable profile (response)
```http
GET https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.ContainerService/upgradeGateProfiles/prod-defaults?api-version=2024-09-01

HTTP/1.1 200 OK
Content-Type: application/json
{
  "name": "prod-defaults",
  "type": "Microsoft.ContainerService/upgradeGateProfiles",
  "properties": {
    "evaluation": { "preflightMinutes": 10, "canaryMinutes": 20, "soakMinutes": 60, "consecutiveBreachesRequired": 2 },
    "actions": { "onBreach": "pause" },
    "prometheus": {
      "ruleGroupIds": [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitor/providers/Microsoft.AlertsManagement/prometheusRuleGroups/slo-gates"
      ],
      "ruleNames": ["HighErrorRate", "P95LatencySpike"]
    }
  }
}
```

1) Create reusable profile (request)
```http
PUT https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.ContainerService/upgradeGateProfiles/prod-defaults?api-version=2024-09-01
Content-Type: application/json
{
  "properties": {
    "evaluation": { "preflightMinutes": 10, "canaryMinutes": 20, "soakMinutes": 60, "consecutiveBreachesRequired": 2 },
    "actions": { "onBreach": "pause" },
    "prometheus": {
      "ruleGroupIds": [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitor/providers/Microsoft.AlertsManagement/prometheusRuleGroups/slo-gates"
      ],
      "ruleNames": ["HighErrorRate", "P95LatencySpike"]
    }
  }
}
```

2) Bind profile on cluster (request → response)
```http
PUT https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-app/providers/Microsoft.ContainerService/managedClusters/cluster-a/upgradeGates/default?api-version=2024-09-01
Content-Type: application/json
{
  "properties": {
    "enabled": true,
    "profile": {
      "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.ContainerService/upgradeGateProfiles/prod-defaults"
    }
  }
}

HTTP/1.1 200 OK
Content-Type: application/json
{
  "name": "default",
  "type": "Microsoft.ContainerService/managedClusters/upgradeGates",
  "properties": {
    "enabled": true,
    "profile": {
      "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.ContainerService/upgradeGateProfiles/prod-defaults"
    },
    "status": { "phase": "idle", "decision": "n/a" }
  }
}
```

3) Start an upgrade (outside this contract) then check status (response includes upgrade operation IDs)
```http
GET https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-app/providers/Microsoft.ContainerService/managedClusters/cluster-a/upgradeGates/default?api-version=2024-09-01

HTTP/1.1 200 OK
Content-Type: application/json
{
  "name": "default",
  "type": "Microsoft.ContainerService/managedClusters/upgradeGates",
  "properties": {
    "enabled": true,
    "profile": { "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.ContainerService/upgradeGateProfiles/prod-defaults" },
    "status": {
      "phase": "preflight",
      "decision": "pause", 
      "currentUpgradeRunId": "77777777-8888-9999-aaaa-bbbbbbbbbbbb",
      "currentUpgradeRef": {
        "operationId": "99999999-aaaa-bbbb-cccc-dddddddddddd",
        "correlationId": "123e4567-e89b-12d3-a456-426614174000",
        "scope": "agentPool",
        "agentPool": "np1",
        "requestedVersion": "1.30.3"
      },
      "lastEvaluation": {
        "timestamp": "2025-08-14T09:05:00Z",
        "ruleStatuses": [
          { "ruleGroupId": "/subscriptions/000.../rg-monitor/providers/Microsoft.AlertsManagement/prometheusRuleGroups/slo-gates", "ruleName": "HighErrorRate", "firing": true,  "consecutiveCount": 2 },
          { "ruleGroupId": "/subscriptions/000.../rg-monitor/providers/Microsoft.AlertsManagement/prometheusRuleGroups/slo-gates", "ruleName": "P95LatencySpike", "firing": false, "consecutiveCount": 0 }
        ]
      },
      "breaches": [
        {
          "at": "2025-08-14T09:05:00Z",
          "ruleGroupId": "/subscriptions/000.../rg-monitor/providers/Microsoft.AlertsManagement/prometheusRuleGroups/slo-gates",
          "ruleName": "HighErrorRate",
          "observed": 7.8,
          "threshold": 5.0,
          "phase": "preflight",
          "action": "pause"
        }
      ]
    }
  }
}
```

4) Inspect the full timeline for this run
```http
GET https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-app/providers/Microsoft.ContainerService/managedClusters/cluster-a/upgradeGates/default/evaluations/77777777-8888-9999-aaaa-bbbbbbbbbbbb?api-version=2024-09-01

HTTP/1.1 200 OK
Content-Type: application/json
{
  "name": "77777777-8888-9999-aaaa-bbbbbbbbbbbb",
  "type": "Microsoft.ContainerService/managedClusters/upgradeGates/evaluations",
  "properties": {
    "startedAt": "2025-08-14T09:00:00Z",
    "completedAt": null,
    "upgradeRef": {
      "operationId": "99999999-aaaa-bbbb-cccc-dddddddddddd",
      "correlationId": "123e4567-e89b-12d3-a456-426614174000",
      "scope": "agentPool",
      "agentPool": "np1",
      "requestedVersion": "1.30.3"
    },
    "phases": [
      { "name": "preflight", "decision": "pause", "breaches": [ { "ruleGroupId": "/subscriptions/000.../slo-gates", "ruleName": "HighErrorRate", "observed": 7.8, "threshold": 5.0 } ] },
      { "name": "canary", "decision": "pending", "breaches": [] },
      { "name": "soak",   "decision": "pending", "breaches": [] }
    ]
  }
}
```

### CLI Experience

Preferred (profile binding)
- Create/Update (bind profile):
  az aks upgrade-gates set -g {resourceGroupName} -n {clusterName} --profile-id "/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.ContainerService/upgradeGateProfiles/{profileName}" --enable true
  - At scale: enforce profile binding via Azure Policy on the child path; rotate the profile to change defaults across fleets.

Alternate (inline)
- Create/Update (inline signals):
  az aks upgrade-gates set -g {resourceGroupName} -n {clusterName} --preflight 10 --canary 20 --soak 60 --consecutive 2 --action pause --prom-rule-group-ids "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.AlertsManagement/prometheusRuleGroups/{ruleGroupName}" --prom-rule-names HighErrorRate P95LatencySpike

Show current config + status:
- az aks upgrade-gates show -g {resourceGroupName} -n {clusterName}
+  az aks upgrade-gates show -g {resourceGroupName} -n {clusterName}

List/Show evaluations:
- az aks upgrade-gates evaluations list -g {resourceGroupName} -n {clusterName}
- az aks upgrade-gates evaluations show -g {resourceGroupName} -n {clusterName} --run-id {upgradeRunId}
+  az aks upgrade-gates evaluations list -g {resourceGroupName} -n {clusterName}
+  az aks upgrade-gates evaluations show -g {resourceGroupName} -n {clusterName} --run-id {upgradeRunId}

Delete config:
- az aks upgrade-gates delete -g {resourceGroupName} -n {clusterName}
+  az aks upgrade-gates delete -g {resourceGroupName} -n {clusterName}

### Portal Experience

- Location: Cluster > Upgrades > Upgrade Gates (Preview)
- Configure (child resource):
  - Choose Profile (preferred) or Inline
  - Enable
  - If Profile: pick `upgradeGateProfiles/{profileName}` by ARM ID or selector
  - If Inline: Preflight/Canary/Soak minutes; Consecutive breaches; Action (pause|abort); Managed Prometheus: select Rule Group (by Resource ID) and optionally rule names
- Status panel (read-only):
  - Current phase, decision, last evaluation ruleStatuses, breaches (if any)
  - Shows bound profile name and ARM ID
- Evaluations tab:
  - List recent upgrade runs with per-phase decisions; open details for breach context
  - Displays operationId and correlationId for end-to-end traceability; deep-links to the rule group where possible
- Failure UX:
  - Upgrade page shows banner with phase, rule, observed vs threshold, and action taken

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
| 1 | Cluster‑level child resource: upgradeGates (PUT/GET/DELETE) | High |
| 2 | Managed Prometheus integration via ruleGroupIds | High |
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
| 4 | Validation: ruleGroupIds exist; responses include `ruleGroupId` with each referenced rule | High |
| 5 | Resilience: fail‑closed behavior on transient errors/timeouts | High |

# Dependencies and risks

| No. | Requirement or Deliverable | Giver Team / Contact | Risk / Mitigation |
|-----|----------------------------|----------------------|-------------------|
| 1 | AlertsManagement Prometheus Rule Groups API (read-only) | Azure Monitor (Alerts/Prometheus) | API version drift; lock to preview api-version and add compat shims |
| 2 | AKS CLI commands (upgrade-gates + evaluations) | AKS CLI | Schedule slip; ship via extension first, then merge to core |
| 3 | Portal blade (Upgrade Gates + Evaluations) | AKS UX/Portal | Staged rollout; fall back to ARM/CLI if delayed |
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
  - One source of truth per cluster avoids conflicting configs and name sprawl. A stable ARM path (/upgradeGates/default) makes RBAC, Policy aliases, CLI/Portal, and automation simple and consistent. It also reduces drift and eases DeployIfNotExists stamping of org defaults. If we add pool-level resources or reusable profiles later, the cluster-level default remains a single, predictable anchor.

- Can I target specific alert rules within a rule group?
  - Not in v1. All alerting rules in the provided rule groups are enforced. Use granular rule groups to scope if needed.

- Why only Azure Managed Prometheus in v1 and not self-hosted Prometheus or Azure Monitor alerts?
  - Adoption (~48% of clusters), lowest integration/identity complexity, fastest path to value. We can add Azure Monitor alerts and self‑hosted endpoints in later phases.

- Does this gate control plane upgrades?
  - Control plane honors pause-only semantics; no rollback. Agent pool upgrades can optionally rollback when Blue/Green is enabled.

- How do you reduce false positives/noise?
  - Consecutive breach counts, warm-up suppression in preflight, debounce windows, and explicit customer-selected signals.

- What happens if the rule group API is temporarily unavailable?
  - Fail-closed to pause with diagnostics; customers can retry once availability is restored.

- How do I find the rule group resource ID safely?
  - Copy from the rule group’s JSON in Portal/ARM. Use placeholders in docs. Provide full ARM IDs in automation (Policy/CLI/IaC).

- Can I reuse one guard configuration across many clusters?
  - Yes. Use `Microsoft.ContainerService/upgradeGateProfiles/{profileName}` and bind clusters via `properties.profile.id` on the child resource (preferred).

- Does this replace blue/green upgrades?
  - No. It complements them by adding app SLO gating to canary/soak phases and optional rollback.

- Why have "breaches" in addition to "evaluations"?
  - Evaluations are periodic snapshots of rule status per phase used to drive the gate; breaches are immutable events recorded when a gating condition is met (after debounce/consecutive counts), including observed vs threshold and action.
  - Breaches provide durable auditability even if the alert clears by the next evaluation; they show exactly what triggered pause/abort with timestamps and upgrade identifiers.
  - Breaches are compact and queryable for automation/compliance (e.g., "did any breach occur in run X?"), whereas evaluations can be numerous and transient.
  - Breaches capture fail-closed cases (e.g., telemetry outage) as synthetic events with a reason; evaluations may be absent or partial in such cases.
  - UX separation: surface breaches in summary banners; use the evaluations timeline for deep-dive analysis.

