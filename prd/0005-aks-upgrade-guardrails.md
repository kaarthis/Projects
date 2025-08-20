---
title: AKS Upgrade Guardrails: SLO‑Gated, Metric‑Aware Upgrades
wiki: ""
pm-owners: [kaarthis]
feature-leads: []
authors: [kaarthis]
stakeholders: []
approved-by: []
status: Draft
last-updated: 2025-08-19
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
- Evaluate in preflight and canary within the gate; post‑upgrade observation/soak is configured outside the gate (Node Soak for rolling; Blue/Green pool soak for cutover). On breach → pause/abort; optional agent pool rollback.
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

API design (final)

Shared contract
- Signals: Azure Managed Prometheus only (v1). Customers provide full ARM IDs of rule groups and may include rule-level overrides.
- Surfaces: each cluster exposes live status per named gate under a child resource; per-upgrade timelines via evaluations; both include operationId, correlationId, scope, agentPool, requestedVersion.
- Identity in results: every rule has ruleGroupId (full ARM ID) + ruleName; observed vs threshold is returned.

Option 1 — Inline, named gate (cluster child)
- Contract (ARM):
  - Config/status at `managedClusters/{cluster}/upgradeGatesReferences/{gateName}`
  - Evaluations at `managedClusters/{cluster}/upgradeGatesReferences/{gateName}/evaluations/{upgradeRunId}`
  - PUT body: `properties.enabled`, `properties.evaluation` (preflightMinutes, canaryMinutes, consecutiveBreachesRequired), `properties.actions` (onBreach), `properties.prometheus.ruleGroups[]` where each item is `{ id, rules[]? }` and rules may specify per-rule `consecutiveBreachesRequired`.

Option 2 — Reusable gate + binding (preferred)
- Contract (ARM):
  - Reusable spec at `upgradeGates/{gateName}` (RG/sub scope; no status)
  - Cluster binds by setting `properties.upgradeGate.id` on `/managedClusters/{cluster}/upgradeGatesReferences/{gateName}`; spec is authoritative and snapshotted at run start.

Why Option 2 is preferred
- Fleet-scale governance: update one reusable gate to affect hundreds of clusters instead of N per-cluster writes.
- RBAC/policy: platform teams author reusable gates; clusters bind by ID. Policy can require binding to an allowed gate or to any gate.
- Drift control: snapshot-at-upgrade-start prevents mid-run drift; easy to audit which gate governed a run.
- Discoverability: status/evaluations remain on the cluster child; central spec has no status.

ARM operations
- Child (cluster, per named gate):
  - PUT /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGatesReferences/{gateName}?api-version=2024-09-01
  - GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGatesReferences/{gateName}?api-version=2024-09-01
  - DELETE /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGatesReferences/{gateName}?api-version=2024-09-01
  - GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGatesReferences/{gateName}/evaluations?api-version=2024-09-01
  - GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGatesReferences/{gateName}/evaluations/{upgradeRunId}?api-version=2024-09-01
- Reusable gates (spec only):
  - PUT/GET/DELETE /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/upgradeGates/{gateName}?api-version=2024-09-01

Notes
- The child resource is the status/diagnostics surface and the binding point (properties.upgradeGate.id). Reusable gates hold spec; no status.
- Evaluations are read-only and keyed by upgradeRunId; shapes include upgradeRef (operationId, correlationId, scope, agentPool, requestedVersion).
- Soak: gate controls preflight and canary. Post-upgrade observation is configured outside the gate (Node Soak for rolling upgrades, Blue/Green soak per operation); timeline phases omit soak.

Prometheus linkage and identity
- Provide full ARM IDs for `Microsoft.AlertsManagement/prometheusRuleGroups` via `prometheus.ruleGroups[].id`.
- Optional `prometheus.ruleGroups[].rules[].name` may be provided to identify rules and apply per-rule overrides; in v1 this does not restrict enforcement—ALL alerting rules in listed groups are enforced unless documented otherwise later. Unspecified rules inherit the gate-level default consecutive.
- Gate-level default: `evaluation.consecutiveBreachesRequired` applies when a rule has no override.
- On PUT, AKS validates each group exists and is readable; invalid/unauthorized IDs return clear 4xx errors.
- Multiple groups supported (1–16); duplicates ignored. Policy alias example (illustrative): `Microsoft.ContainerService/managedClusters/upgradeGatesReferences[*].prometheus.ruleGroups[*].id`.

Identity and RBAC
- Runtime reads are performed using the cluster’s managed identity during upgrades.
- Required permission: `Microsoft.AlertsManagement/prometheusRuleGroups/read` on each referenced rule group scope.
- Validation on PUT checks existence and readability by the runtime identity; failures return 400 (invalid ID) or 403 (forbidden) with actionable diagnostics.

+Concepts and Properties (Swagger-style overview)
+
+This section explains the core resources, their properties, and the “why” behind them before the sample requests/responses.
+
+Concepts
+- Reusable Gate (Microsoft.ContainerService/upgradeGates/{gateName}): a reusable specification authored once and bound to many clusters. Why: fleet governance, fewer writes, consistent defaults. No status on this resource.
+- Gate Binding (managedClusters/{cluster}/upgradeGatesReferences/{gateName}): a named child on the cluster that enables a gate and optionally binds to a reusable gate. Why: per-cluster status, RBAC/Policy targeting, multi-gate support.
+- Evaluation: a per-upgrade-run timeline captured under the child. Why: traceability and diagnostics per run.
+- Breach: an immutable event emitted when gating conditions are met. Why: durable audit, compact queryability, distinct from periodic evaluations.
+
+Reusable Gate schema (spec only)
+properties:
+  evaluation:
+    preflightMinutes: integer  // minutes to evaluate before upgrade begins; 0 disables preflight
+    canaryMinutes: integer     // minutes to evaluate during early rollout; 0 disables canary gating
+    consecutiveBreachesRequired: integer // default consecutive count for all rules (noise control)
+  actions:
+    onBreach: string enum ["pause", "abort"] // action when a breach is recorded
+  prometheus:
+    ruleGroups: array of {
+      id: string // ARM resource ID of Microsoft.AlertsManagement/prometheusRuleGroups
+      rules?: array of {
+        name: string // rule name for identification/override
+        consecutiveBreachesRequired?: integer // per-rule override; falls back to gate default
+      }
+    }
+
+Gate Binding schema (cluster child)
+properties:
+  enabled: boolean // enables gating on this cluster for the named child
+  upgradeGate?: { id: string } // bind to a reusable gate (preferred). Inline mode uses the same spec shape as above.
+  // inline spec (optional, when not binding): evaluation, actions, prometheus – same schema as Reusable Gate
+  status (read-only):
+    phase: string enum ["idle", "preflight", "canary"] // current gate phase for the active upgrade
+    decision: string enum ["n/a", "pending", "proceed", "pause", "abort"]
+    currentUpgradeRunId: string // stable run identifier
+    currentUpgradeRef: {
+      operationId: string
+      correlationId: string
+      scope: string enum ["agentPool", "cluster"]
+      agentPool?: string
+      requestedVersion: string
+    }
+    breaches: array of {
+      at: string (RFC3339)
+      ruleGroupId: string
+      ruleName: string
+      observed: number
+      threshold: number
+      phase: string // phase at time of breach
+      action: string // action applied (pause|abort)
+    }
+    updatedAt: string (RFC3339) // last time status was refreshed
+
+Evaluations schema (per run)
+properties:
+  startedAt: string (RFC3339)
+  completedAt?: string (RFC3339)
+  upgradeRef: {
+    operationId: string
+    correlationId: string
+    scope: string enum ["agentPool", "cluster"]
+    agentPool?: string
+    requestedVersion: string
+  }
+  phases: array of {
+    name: string enum ["preflight", "canary"]
+    decision: string enum ["pending", "proceed", "pause", "abort"]
+    breaches: array of {
+      ruleGroupId: string
+      ruleName: string
+      observed: number
+      threshold: number
+    }
+  }
+
+Phases and Decisions (concise semantics)
+- Phases: preflight validates baseline health before changes; canary validates early rollout on a subset to catch regressions before full deployment. Set minutes to 0 to disable a phase.
+- Transitions: idle → preflight (if enabled) → canary (if enabled) → upgrade proceeds. A breach in any enabled phase triggers the configured action.
+- Decisions: pending while evaluating; proceed when the phase completes without breach; pause/abort when a breach is recorded (fail-closed on telemetry outage → pause). Decisions are monotonic within a phase.
+- Soak: post-upgrade observation is configured outside the gate (Node Soak or Blue/Green soak) to keep the gate focused on preflight/canary.

Phase-to-Decision and Soak Mapping (concise)

| Phase/Step                        | In Gate? | Applies To                 | When it runs                                  | Window knob            | Signals used                            | Decisions                         | Action on breach (priority)                                                   | Decision surfaced at                         |
|-----------------------------------|----------|----------------------------|-----------------------------------------------|------------------------|-----------------------------------------|-----------------------------------|-------------------------------------------------------------------------------|-----------------------------------------------|
| Preflight                         | Yes      | Rolling, Blue/Green        | Before any change                             | preflightMinutes       | Gate snapshot (Managed Prom ruleGroups) | pending → proceed/pause/abort     | Gate actions.onBreach (pause or abort)                                        | Gate status + evaluations                     |
| Canary                            | Yes      | Rolling, Blue/Green        | Early subset rollout                          | canaryMinutes          | Gate snapshot (same as above)           | pending → proceed/pause/abort     | Gate actions.onBreach (pause or abort)                                        | Gate status + evaluations                     |
| Node Soak (per node/batch)        | No       | Rolling, Blue/Green        | After each node/batch reaches steady state    | nodeSoakMinutes (0=off)| Same snapshot as gate                   | proceed/pause/rollback             | If rollback supported+enabled → rollback agent pool; else → pause             | Upgrade run status (outside gate)             |
| Nodepool Soak (post cutover)      | No       | Blue/Green only            | After traffic cutover to green                | nodepoolSoakMinutes (0=off) | Same snapshot as gate               | proceed/pause/rollback             | Within soak TTL → rollback to blue; outside TTL or unsupported → pause        | Upgrade run status (outside gate)             |

Notes
- Soak uses the same rule snapshot captured at upgrade start to avoid mid-run drift.
- Abort during gate phases stops the run immediately; soak does not execute.
- Fail-closed on telemetry outage: gate → pause; soak → pause (rollback only when signals are available and the feature is enabled).
- Set any window to 0 to disable that phase/soak.

Soak (outside the gate)
- Node Soak (Rolling and Blue/Green): post-upgrade per-node/batch observation window to catch delayed regressions.
  - Configuration: nodeSoakMinutes on the upgrade operation or cluster settings (outside the gate). Default 10–20 minutes.
  - Decision on breach: rollback agent pool if supported and enabled; otherwise pause the upgrade.
- Nodepool Soak (Blue/Green only): post-cutover pool-level observation window while retaining blue for fast rollback.
  - Configuration: nodepoolSoakMinutes and a rollback TTL on the upgrade operation (outside the gate). Default 20–60 minutes.
  - Decision on breach: rollback to blue within the soak window; otherwise pause.

 Notes and rationale
 - Per-rule overrides let noisy rules require more consecutive confirmations without inflating the default for all rules.
 - Named gates separate concerns (e.g., app-vs-platform signals) and simplify policy scoping.
 - Snapshot-at-upgrade-start avoids mid-run drift when reusable gates are edited.
 - Soak is configured outside the gate (Node Soak or Blue/Green soak) to keep gate semantics focused and predictable.
 
 Use case scenarios (Option 2 — reusable gate + binding)
 This section shows the complete contract and answers:
- How customers provide alerts: create a reusable gate with ruleGroups (and optional per-rule overrides), then bind it on the cluster child.
- How operators manage hundreds of clusters: enforce binding via Azure Policy/IaC; rotate/replace the reusable gate to change org defaults fleet-wide without touching each cluster.
- How customers see results and trace decisions: GET the named child for live status and breaches with operationId/correlationId; GET evaluations/{upgradeRunId} for the full timeline; same via CLI/Portal.

0) Get reusable gate (response)
```http
GET https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.ContainerService/upgradeGates/prod-slo?api-version=2024-09-01

HTTP/1.1 200 OK
Content-Type: application/json
{
  "name": "prod-slo",
  "type": "Microsoft.ContainerService/upgradeGates",
  "properties": {
    "evaluation": { "preflightMinutes": 10, "canaryMinutes": 20, "consecutiveBreachesRequired": 2 },
    "actions": { "onBreach": "pause" },
    "prometheus": {
      "ruleGroups": [
        {
          "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitor/providers/Microsoft.AlertsManagement/prometheusRuleGroups/slo-gates",
          "rules": [
            { "name": "HighErrorRate", "consecutiveBreachesRequired": 3 },
            { "name": "P95LatencySpike" }
          ]
        }
      ]
    }
  }
}
```

1) Create reusable gate (request)
```http
PUT https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.ContainerService/upgradeGates/prod-slo?api-version=2024-09-01
Content-Type: application/json
{
  "properties": {
    "evaluation": { "preflightMinutes": 10, "canaryMinutes": 20, "consecutiveBreachesRequired": 2 },
    "actions": { "onBreach": "pause" },
    "prometheus": {
      "ruleGroups": [
        {
          "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitor/providers/Microsoft.AlertsManagement/prometheusRuleGroups/slo-gates",
          "rules": [
            { "name": "HighErrorRate", "consecutiveBreachesRequired": 3 },
            { "name": "P95LatencySpike" }
          ]
        }
      ]
    }
  }
}
```

2) Bind gate on cluster (request → response)
```http
PUT https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-app/providers/Microsoft.ContainerService/managedClusters/cluster-a/upgradeGatesReferences/prod-slo?api-version=2024-09-01
Content-Type: application/json
{
  "properties": {
    "enabled": true,
    "upgradeGate": {
      "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.ContainerService/upgradeGates/prod-slo"
    }
  }
}

HTTP/1.1 200 OK
Content-Type: application/json
{
  "name": "prod-slo",
  "type": "Microsoft.ContainerService/managedClusters/upgradeGatesReferences",
  "properties": {
    "enabled": true,
    "upgradeGate": {
      "id": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.ContainerService/upgradeGates/prod-slo"
    },
    "status": { "phase": "idle", "decision": "n/a" }
  }
}
```

3) Start an upgrade (outside this contract) then check gate status
```http
GET https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-app/providers/Microsoft.ContainerService/managedClusters/cluster-a/upgradeGatesReferences/prod-slo?api-version=2024-09-01

HTTP/1.1 200 OK
Content-Type: application/json
{
  "name": "prod-slo",
  "type": "Microsoft.ContainerService/managedClusters/upgradeGatesReferences",
  "properties": {
    "enabled": true,
    "upgradeGate": { "id": "/subscriptions/000.../providers/Microsoft.ContainerService/upgradeGates/prod-slo" },
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
      "updatedAt": "2025-08-14T09:05:30Z",
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

4) Inspect the full timeline for this run (no soak phase in gate)
```http
GET https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-app/providers/Microsoft.ContainerService/managedClusters/cluster-a/upgradeGatesReferences/prod-slo/evaluations/77777777-8888-9999-aaaa-bbbbbbbbbbbb?api-version=2024-09-01

HTTP/1.1 200 OK
Content-Type: application/json
{
  "name": "77777777-8888-9999-aaaa-bbbbbbbbbbbb",
  "type": "Microsoft.ContainerService/managedClusters/upgradeGatesReferences/evaluations",
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
      { "name": "canary", "decision": "pending", "breaches": [] }
    ]
  }
}
```

5) Rolling — Node Soak breach triggers rollback (outside gate; illustrative)
```http
GET https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-app/providers/Microsoft.ContainerService/managedClusters/cluster-a/agentPools/np1/upgradeRuns/77777777-8888-9999-aaaa-bbbbbbbbbbbb?api-version=2024-09-01

HTTP/1.1 200 OK
Content-Type: application/json
{
  "name": "77777777-8888-9999-aaaa-bbbbbbbbbbbb",
  "type": "Microsoft.ContainerService/managedClusters/agentPools/upgradeRuns",
  "properties": {
    "mode": "Rolling",
    "phase": "nodeSoak",
    "decision": "rollback",
    "state": "RollingBack",
    "rollback": {
      "startedAt": "2025-08-14T09:22:10Z",
      "reason": {
        "ruleGroupId": "/subscriptions/000.../rg-monitor/providers/Microsoft.AlertsManagement/prometheusRuleGroups/slo-gates",
        "ruleName": "HighErrorRate",
        "observed": 6.2,
        "threshold": 5.0
      }
    }
  }
}
```

6) Blue/Green — Nodepool Soak breach triggers rollback to blue (outside gate; illustrative)
```http
GET https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-app/providers/Microsoft.ContainerService/managedClusters/cluster-a/agentPools/np1/upgradeRuns/88888888-9999-aaaa-bbbb-cccccccccccc?api-version=2024-09-01

HTTP/1.1 200 OK
Content-Type: application/json
{
  "name": "88888888-9999-aaaa-bbbb-cccccccccccc",
  "type": "Microsoft.ContainerService/managedClusters/agentPools/upgradeRuns",
  "properties": {
    "mode": "BlueGreen",
    "phase": "nodepoolSoak",
    "decision": "rollback",
    "state": "RolledBack",
    "rollback": {
      "target": "blue",
      "withinSoakWindow": true,
      "startedAt": "2025-08-14T10:05:00Z",
      "reason": {
        "ruleGroupId": "/subscriptions/000.../rg-monitor/providers/Microsoft.AlertsManagement/prometheusRuleGroups/slo-gates",
        "ruleName": "P95LatencySpike",
        "observed": 420,
        "threshold": 300
      }
    }
  }
}
```

Notes: Soak decisions surface on the upgrade run status (outside the gate). The gate resource continues to show preflight/canary only.

### CLI Experience

Preferred (reusable gate binding)
- Create/Update (bind reusable gate to a named child):
  az aks upgrade-gates set -g {resourceGroupName} -n {clusterName} --gate-name prod-slo --upgrade-gate-id "/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.ContainerService/upgradeGates/{gateName}" --enable true
  - At scale: enforce binding via Azure Policy on the child path; rotate the reusable gate to change defaults across fleets.

Alternate (inline)
- Create/Update (inline signals on a named child):
  az aks upgrade-gates set -g {resourceGroupName} -n {clusterName} --gate-name prod-slo --preflight 10 --canary 20 --consecutive 2 --action pause \
    --prom-rule-group "/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.AlertsManagement/prometheusRuleGroups/{ruleGroupName}" \
    --prom-rule "HighErrorRate:3" --prom-rule "P95LatencySpike"

Show current config + status (named gate):
- az aks upgrade-gates show -g {resourceGroupName} -n {clusterName} --gate-name prod-slo
- az aks upgrade-gates list -g {resourceGroupName} -n {clusterName}

List/Show evaluations (named gate):
- az aks upgrade-gates evaluations list -g {resourceGroupName} -n {clusterName} --gate-name prod-slo
- az aks upgrade-gates evaluations show -g {resourceGroupName} -n {clusterName} --gate-name prod-slo --run-id {upgradeRunId}

Delete a gate binding:
- az aks upgrade-gates delete -g {resourceGroupName} -n {clusterName} --gate-name prod-slo

### Portal Experience

- Location: Cluster > Upgrades > Upgrade Gates (Preview)
- Configure (child resource, multiple named gates):
  - Add Gate → choose Reusable (preferred) or Inline
  - Enable
  - If Reusable: pick `upgradeGates/{gateName}` by ARM ID or selector
  - If Inline: Preflight/Canary minutes; Consecutive breaches (default); Action (pause|abort); Managed Prometheus: select Rule Group (by Resource ID) and optionally per-rule overrides
- Status panels (read-only):
  - One card per gate: current phase, decision, breaches (if any), and last updated timestamp
  - Shows bound reusable gate name and ARM ID when applicable
- Evaluations tab:
  - Select a gate to list recent upgrade runs with per-phase decisions; open details for breach context
  - Displays operationId and correlationId for end-to-end traceability; deep-links to the rule group where possible
- Failure UX:
  - Upgrade page shows banner with gate name, phase, rule, observed vs threshold, and action taken

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
| 1 | Cluster‑level child resources: upgradeGatesReferences (named; PUT/GET/DELETE/LIST) | High |
| 2 | Managed Prometheus integration via ruleGroups[].id and optional rules[].name with per-rule overrides | High |
| 3 | Evaluation windows in-gate: preflight, canary; post-upgrade soak configured outside the gate | High |
| 4 | Actions: pause | abort | High |
| 5 | Status surface on each named child; evaluations per gate and upgrade run (LIST/GET) | High |
| 6 | Policy/RBAC targeting the child path (wildcard gate name) | Medium |

## Test Requirements (concise)
| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | E2E: set/show/delete config; run upgrade; success path | High |
| 2 | Breach path: trigger firing rule → pause/abort with correct diagnostics | High |
| 3 | Scale: concurrent guarded upgrades across many clusters | High |
| 4 | Validation: ruleGroups[].id exist; responses include `ruleGroupId` with each rule; per-rule override precedence validated | High |
| 5 | Resilience: fail‑closed behavior on transient errors/timeouts | High |

# Dependencies and risks

| No. | Requirement or Deliverable | Giver Team / Contact | Risk / Mitigation |
|-----|----------------------------|----------------------|-------------------|
| 1 | AlertsManagement Prometheus Rule Groups API (read-only) | Azure Monitor (Alerts/Prometheus) | API version drift; lock to preview api-version and add compat shims |
| 2 | AKS CLI commands (upgrade-gates + evaluations; named gates) | AKS CLI | Schedule slip; ship via extension first, then merge to core |
| 3 | Portal blade (Upgrade Gates + Evaluations; multiple gates) | AKS UX/Portal | Staged rollout; fall back to ARM/CLI if delayed |
| 4 | Built-in Policy definitions + aliases (child wildcard path) | Azure Policy | Start with samples; add built-ins once aliases finalize |
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

- Why named gates instead of a singleton default?
  - Different concerns benefit from separate gates (e.g., app SLOs vs platform signals). Named children enable clear scoping, targeted policy, and phased rollout without conflicting configs. A wildcardable path keeps RBAC/Policy manageable. We will keep a temporary legacy mapping from `default` for backward compatibility but do not require a singleton going forward.

- Can I target specific alert rules within a rule group?
  - In v1, all alerting rules in the provided groups are enforced. You can specify rule names to attach per-rule overrides (e.g., higher consecutive count). If you need strict selection, create more granular rule groups.

- Why only Azure Managed Prometheus in v1 and not self-hosted Prometheus or Azure Monitor alerts?
  - Adoption (~48% of clusters), lowest integration/identity complexity, fastest path to value. We can add Azure Monitor alerts and self‑hosted endpoints in later phases.

- Does this gate control plane upgrades?
  - Control plane honors pause-only semantics; no rollback. Agent pool upgrades can optionally rollback when Blue/Green is enabled.

- How do you reduce false positives/noise?
  - Consecutive breach counts, warm‑up suppression in preflight, debounce windows, and explicit customer-selected signals.

- What happens if the rule group API is temporarily unavailable?
  - Fail-closed to pause with diagnostics; customers can retry once availability is restored.

- How do I find the rule group resource ID safely?
  - Copy from the rule group’s JSON in Portal/ARM. Use placeholders in docs. Provide full ARM IDs in automation (Policy/CLI/IaC).

- Can I reuse one guard configuration across many clusters?
  - Yes. Use `Microsoft.ContainerService/upgradeGates/{gateName}` and bind clusters via `properties.upgradeGate.id` on the named child (preferred).

- Does this replace blue/green upgrades?
  - No. It complements them by adding app SLO gating to canary/soak phases and optional rollback.

- Why have "breaches" in addition to "evaluations"?
  - Evaluations are periodic snapshots of rule status per phase used to drive the gate; breaches are immutable events recorded when a gating condition is met (after debounce/consecutive counts), including observed vs threshold and action.
  - Breaches provide durable auditability even if the alert clears by the next evaluation; they show exactly what triggered pause/abort with timestamps and upgrade identifiers.
  - Breaches are compact and queryable for automation/compliance (e.g., "did any breach occur in run X?"), whereas evaluations can be numerous and transient.
  - Breaches capture fail-closed cases (e.g., telemetry outage) as synthetic events with a reason; evaluations may be absent or partial in such cases.
  - UX separation: surface breaches in summary banners; use the evaluations timeline for deep-dive analysis.

- How do I bypass a gate in an emergency?
  - v1 does not support force-continue. You can disable or unbind the named gate, or temporarily raise thresholds in the reusable gate and re-run. All actions are audited via breaches/evaluations and activity logs.

- Where is soak configured now?
  - Outside the gate. Use Node Soak for rolling upgrades and Blue/Green pool soak for cutover. The gate governs preflight and canary; post-upgrade observation time is provided by these mechanisms.

- How do per-rule overrides interact with the gate-level default?
  - If a rule specifies `consecutiveBreachesRequired`, it wins. Otherwise the gate-level `evaluation.consecutiveBreachesRequired` applies.

- How does this relate to Fleet and Service Fabric upgrade gates?
  - Fleet: this is configuration governance, not orchestration; use reusable gates + Policy for fleet-wide consistency. See Azure Kubernetes Fleet Manager overview: [Fleet Manager](https://learn.microsoft.com/azure/aks/fleet/).
  - Service Fabric: we adopt the upgrade-gate concept (named gates, per-rule override, durable breaches) and fill gaps with ARM-first governance and AKS-native status/evaluations surfaces. See [Service Fabric cluster upgrades](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-upgrade) and [Service Fabric application upgrades](https://learn.microsoft.com/azure/service-fabric/service-fabric-application-upgrade).

