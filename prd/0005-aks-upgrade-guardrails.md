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

Before this feature, AKS customers had to hand‑craft blue/green flows and stitch alerts to decide whether to proceed or stop upgrades. Now, AKS customers can declare application SLO guardrails using Azure Managed Prometheus rule groups that the upgrade process enforces with preflight, canary, and post‑upgrade checks to automatically abort—or roll back for agent pools—on anomalies.

## Problem Statement / Motivation

AKS upgrades validate readiness signals (PDBs, probes, API breaks) but miss nuanced, post‑upgrade degradations that do not flip pod readiness immediately: latency regressions, error‑rate spikes, delayed OOMs after node moves, and cascading issues that surface over time. Customers either run quasi‑manual blue/green orchestrations with custom gates or rely on AKS Blue/Green nodepool upgrades rolling out later this year, which simplify cutover but are nodepool‑only and do not evaluate application SLO signals. Many lack the platform automation and observability maturity to do this reliably. We need upgrade‑integrated mechanisms to detect these problems and stop the operation.

Examples observed:
- Added application latency after an upgrade
- Increased error rate after version/image change
- Pods crashing/oomkilling minutes or hours after moving to upgraded nodes
- Cascading issues that manifest progressively across components

## Goals/Non-Goals

### Functional Goals

- Policy-driven upgrade guardrails that evaluate application SLOs during preflight, canary, and post-upgrade phases
- Multiple named gates per cluster via child resources: managedClusters/{cluster}/upgradeGatesReferences/{gateName}
- Reusable gate specs as peer resources: upgradeGates/{gateName}, bindable by many clusters for consistency
- Decision actions on breach: abort, or rollback for agent pools (rolling and blue/green) when configured
- Per-rule consecutive breach overrides to reduce noise; gate-level default when no override provided
- First-class governance: Azure Policy and RBAC targeting at the child resource path; audit of decisions and immutable breach events
- Maintenance window compatibility for predictable scheduling (defined separately)
- Node pool coverage for VMSS and VM-based pools; control plane is abort-only (no rollback)
- Reuse across services: same gate model applicable to AKS agent pool upgrades and Managed Mesh upgrades
- Separation of pace (soak) and safety (gates): Node/Nodepool soak lives in the upgrade engine; gates evaluate independently. In Blue/Green, rollback is only possible within the Nodepool Soak TTL; beyond TTL, breaches abort. Control plane remains abort-only.

- Declare SLO guardrails via existing monitoring investments:
  - Prometheus (Azure Managed Prometheus rule groups)
- Support preflight (checks before upgrade), canary (limited early upgrade phase), and post-upgrade windows (monitoring after upgrade/cutover to detect delayed problems)
- On breach: abort; optionally trigger agent pool rollback when available
- Log gating decisions/breaches for audit and diagnostics
- Azure Policy enablement to require guardrails in production
- Scope: Applies to regular rolling upgrades and to Blue/Green agent pool upgrades when available

### Non-Functional Goals
- Guard decision loop P95 ≤ 2 minutes
- Security: platform-native integration with Azure Monitor Managed Prometheus; no customer secrets or external endpoints required
- Reliability: guard evaluation availability ≥ 99.9% during upgrades
- Telemetry: adoption, latency, breach precision/false‑positive rate

### Non-Goals
- Signal sources: v1 supports Azure Managed Prometheus only; Azure Monitor alert rules and self‑hosted/external Prometheus are out of scope and deferred to a later phase
- No fleet-wide or multi-cluster upgrade orchestration (no cross-cluster scheduling/ordering). Fleet-wide configuration governance is supported via reusable gates + Azure Policy.
- No full blue/green traffic orchestration
- No control plane rollback (unsupported); agent pool rollback only when available
- No auto‑remediation of applications

## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Developer / Cluster Owner | Microsoft.ContainerService/managedClusters/write; Microsoft.AlertsManagement/prometheusRuleGroups/read | Reference existing Managed Prometheus alert rules; upgrade aborts or rolls back (agent pools) on breach. Success: No SLO breach escapes an upgrade. |
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

AKS upgrades can now honor your application SLOs. Reference Azure Managed Prometheus rule groups, configure preflight/canary/post‑upgrade windows, and AKS will abort—or roll back for agent pools—on anomalies. Public preview for agent pool upgrades this release; GA to follow after feedback.

**Addressing Key Challenges**
- Nuanced regressions (latency, error rate, delayed OOMs) missed by readiness checks
- High operational cost of bespoke blue/green pipelines; lack of governance
- Noise/false positives when alerts aren’t evaluated with warm‑up/debounce logic

**Functionality and Usage**
- Configure guardrails via API/CLI/Portal using existing Azure Managed Prometheus rule groups
- Evaluate in preflight, canary, and post-upgrade phases; on breach → abort, or rollback for agent pools when configured
- Works with AKS Blue/Green nodepool upgrades: guardrails gate canary, pre‑cutover, and post‑upgrade phases

**Availability**
- Public Preview: agent pool upgrades (VMSS and VM node pools); control plane uses abort-only (no rollback)
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

Soak vs Gate (concise)
- Rolling agent pools: Node Soak (inter-node delay) remains an upgrade engine setting and does not appear in the gate API; gates still run preflight/canary/post-upgrade on their timers.
- Blue/Green: Nodepool Soak TTL bounds rollback. Gates can monitor longer, but after TTL, breaches result in abort even if action=rollback.
- Control plane: Same gate schema; rollback unsupported. Canary may effectively be 0 (or a short stabilization window).

## Observability & Troubleshooting Experience

### Failure Visibility & Diagnostics

- **Manual Upgrades:**
  - Failures due to guardrail breaches are shown in CLI/Portal with clear error messages: which SLO(s) breached, metric, threshold, observed value, and evaluation window.
  - Diagnostic logs and gating decision summaries are available via `az aks upgrade-gates reference show -g {rg} -n {cluster} --gate {gateName}` and in the Portal diagnostics blade under Upgrade > Guardrails.
  - Users can review the decision timeline, including timestamps, signals, and breach rationale.
  - Retry: after fixing the root cause (e.g., alert resolved), users can re-initiate the upgrade from CLI/Portal.

- **Auto-Upgrades:**
  - Failures are logged in the cluster's activity log and surfaced in Azure Monitor (event details, breach context).
  - Notifications can be sent via Action Groups if configured.
  - Retry: auto-upgrades do not auto-retry after a breach; customers must manually re-trigger after review.

- **Level of Detail:**
  - Both manual and auto-upgrades provide: breached SLO name, metric, threshold, observed value, evaluation window, and recommended next steps.
  - Portal and CLI expose a diagnostics panel with evaluation history and links to rule groups.

## User Experience 

### Operator Journeys (Scenarios)
- Manual vs Auto Upgrades
  - Manual: Operator triggers upgrade; gate evaluates preflight, canary, and post-upgrade. On breach, upgrade aborts or rolls back (agent pools) per configuration; operator reviews diagnostics to decide next steps.
  - Auto: Policy/schedule initiates upgrade; on breach, gate aborts (or rolls back for agent pools if configured). Notification/event is emitted; operator intervention required.
- Rolling vs Blue/Green
  - Rolling: Gate runs preflight, then canary on a limited slice, then post-upgrade. If enabled/supported and configured, agent pool rollback can be invoked on breach; otherwise abort.
  - Blue/Green: Gate runs preflight/canary before cutover; after cutover, post-upgrade monitors nodepool health. If a breach occurs within the Nodepool Soak TTL (up to 7 days), rollback traffic to Blue (old pool). If no breach within TTL, the upgrade is successful and the service remains on Green (new pool).
- Abort vs Rollback
  - Abort: Default action when rollback is not supported (e.g., control plane) or not configured. Aborts stop the run; no automatic retries.
  - Rollback: Configure for agent pools when available (rolling and blue/green). Breach within policy and soak TTL reverts to last known good (blue or prior state). Outside TTL or on unsupported scope, we abort.
- Managed Prometheus signals (decision inputs)
  - Operator selects Managed Prometheus rule groups; the gate snapshots rules at session start. Decisions are made on firing alerts with optional per‑rule consecutive counts (debounce). Only signals in the snapshot influence the session; mid‑session edits don’t drift decisions.
- Control plane‑only manual upgrade
  - Gate evaluates preflight/canary/post-upgrade. Outcomes are abort-only (no rollback). Recommended: fix health, retry later, or disable the gate if risk‑accepted.
- Multiple gates and reuse across clusters
  - A cluster can bind multiple named gates (e.g., app-slo, platform, payments-critical). Each gate is an `upgradeGatesReferences/{gateName}` child. Reusable `upgradeGates/{gateName}` specs allow many clusters to bind to the same gate for consistent policy with minimal writes.

#### Examples with timelines (mock)
Assumptions used below unless stated: evaluation windows preflight=10m, canary=20m, postUpgrade=60m; gate-level consecutiveBreachesRequired=2; per‑rule override for HighErrorRate=1. Rules referenced: HighErrorRate, P95LatencySpike.

1) Rolling upgrade — action=abort (agent pool)
- Timeline
  - T+00m: Preflight starts (phase=preflight, decision=pending). No alerts fire.
  - T+06m: Preflight still healthy. At T+10m: proceed → phase moves to canary.
  - T+12m: Canary evaluating. P95LatencySpike fires first time (1/2). Decision remains pending.
  - T+18m: P95LatencySpike fires second consecutive time (2/2) → breach recorded.
  - T+18m: Decision=abort. Upgrade stops; remaining nodes are not touched.
- What the user sees
  - CLI: `az aks upgrade-gates reference show ... --gate app-slo` → status { phase: "canary", decision: "abort" } with breach details.
  - CLI: `az aks upgrade-gates evaluations show ... --gate app-slo --session-id {id}` → evaluations show two consecutive latency breaches at T+12/T+18.
  - Portal: Guardrails panel shows aborted during canary; breach banner lists P95LatencySpike with observed vs threshold.
- Notes
  - Control plane would also abort (rollback unsupported).

2) Rolling upgrade — action=rollback (agent pool)
- Timeline
  - T+00m: Preflight passes (no alerts).
  - T+10m: Canary starts. HighErrorRate fires (override consecutive=1) → immediate breach.
  - T+10m: Decision=rollback. Nodes upgraded so far are reverted to previous image/version; run concludes.
- What the user sees
  - CLI status shows { phase: "canary", decision: "rollback" }.
  - Evaluations include a single HighErrorRate breach with action=rollback.
  - Portal shows rollback initiated due to HighErrorRate (consecutive=1 override).
- Notes
  - If rollback is unavailable for this pool/type, action gracefully falls back to abort.

3) Blue/Green upgrade — post-upgrade breach within soak TTL → rollback to Blue
- Config
  - Preflight=5m, Canary(pre‑cutover)=10m, PostUpgrade=60m, action=rollback; Nodepool Soak TTL=7d.
- Timeline
  - T+00m: Preflight passes; canary passes without breaches.
  - T+20m: Cutover to Green completes; postUpgrade monitoring begins.
  - T+45m: HighErrorRate fires (consecutive=1) → breach during postUpgrade window and within soak TTL.
  - T+45m: Decision=rollback. Traffic rolls back to Blue; session ends.
- What the user sees
  - CLI/Portal status { phase: "postUpgrade", decision: "rollback" } and breach details (rule, observed, threshold).
  - Evaluations timeline shows stable preflight/canary, then postUpgrade breach at T+45m.
- Notes
  - If the breach occurred after the soak TTL, the system would abort further actions and require operator intervention.

4) Control plane upgrade — abort-only
- Config
  - Same evaluation windows; action=rollback configured but not supported for control plane.
- Timeline
  - T+00m–T+10m: Preflight healthy. T+12m: Canary P95LatencySpike fires twice (2/2).
  - T+18m: Decision=abort; no rollback attempted.
- What the user sees
  - Status shows decision=abort with a note in diagnostics: rollback unsupported for control plane; action fell back to abort.

Operational follow-ups for any aborted/rolled back session
- Fix underlying issue (e.g., tune alert, mitigate regression) and re-run the upgrade.
- Optionally disable a gate temporarily if risk is explicitly accepted, then re-enable after mitigation.

### API

API design 

Concepts (concise)
- Upgrade Gate Reference (cluster child): `managedClusters/{cluster}/upgradeGatesReferences/{gateName}` holds enablement, optional inline spec or binding, live status, and per‑session evaluations.
- Reusable Upgrade Gate (peer resource): `upgradeGates/{gateName}` is authored once and bound by many clusters; spec only, no status.
- Evaluation: Per‑session, per‑phase decision record captured under the child; separate from immutable Breach events.

Property rationale (Why)
- Upgrade Gate Reference (child): Cluster-scoped enable/disable and status live with the cluster, enabling Policy/RBAC targeting and localized state without mutating the reusable spec.
- Reusable Upgrade Gate (peer): Centralize a spec once and reuse across many clusters for consistency and minimal writes; avoids duplication and drift.
- enabled: Safe toggle to opt clusters in/out without deleting bindings; useful for incident response and staged rollouts.
- upgradeGate.id vs inline: Bind to reuse shared policy; inline for cluster-specific needs or experimentation. Both use the same schema to simplify tooling.
- evaluation.preflightMinutes: Timebox pre-upgrade checks to catch regressions early (before touching capacity); 0 disables if not needed.
- evaluation.canaryMinutes: Observe a small early slice to detect issues before full rollout; 0 disables when canary is impractical.
- evaluation.postUpgradeMinutes: Monitor after upgrade/cutover to detect delayed issues; 0 disables when post monitoring is not needed. For blue/green, aligns with Nodepool Soak TTL. Rollback is only possible within the Blue/Green Nodepool Soak TTL; beyond TTL, breaches result in abort even if action=rollback.
- evaluation.consecutiveBreachesRequired: Debounce noisy signals; gate-level default applies when a rule has no explicit override.
- actions.onBreach: Operator intent on breach—abort, or rollback (agent pools only). If set to rollback on unsupported scope (e.g., control plane), the service aborts. In Blue/Green, rollback is honored only within the Nodepool Soak TTL; outside TTL, the action falls back to abort.
- prometheus.ruleGroups[].id: Explicit ARM IDs ensure correct tenancy/scope and RBAC evaluation; prevents accidental rule drift.
- prometheus.ruleGroups[].rules[].name: Allows per-rule consecutive overrides without splitting rule groups; improves noise control.
- status.phase/decision: Single-glance live snapshot for UX and automation.
- status.currentUpgradeSessionId: Stable identifier for this upgrade session; used to correlate evaluations and breaches across the gate lifecycle; distinct from operationId/correlationId used by ARM/activity log.
- status.currentUpgradeRef: Adds operationId/correlationId/scope to link with Activity Logs and backend diagnostics for end-to-end traceability.
- breaches (in status) vs evaluations (child): Breaches are durable audit events of gating decisions; evaluations provide the detailed timeline per phase without bloating live status.
- evaluations child collection: Dedicated history surface keyed by upgradeSessionId for retrieval and compliance queries.

Properties (shape)
- Reusable Upgrade Gate schema (spec only)
  properties:
    evaluation:
      preflightMinutes: integer // 0 disables preflight
      canaryMinutes: integer // 0 disables canary
      postUpgradeMinutes: integer // 0 disables post-upgrade monitoring
      consecutiveBreachesRequired?: integer // default applied when a rule has no override
    actions:
      onBreach: string enum ["abort", "rollback"] // rollback applies to agent pools only; will fall back to abort if unsupported
    prometheus:
      ruleGroups: array of {
        id: string // ARM ID of Microsoft.AlertsManagement/prometheusRuleGroups
        rules?: array of {
          name: string // rule name for identification
          consecutiveBreachesRequired?: integer // per‑rule override (debounce)
        }
      }
- Gate Reference schema (cluster child)
  properties:
    enabled: boolean
    upgradeGate?: { id: string } // bind to reusable upgrade gate (preferred)
    // inline spec: same shape as reusable (evaluation, actions, prometheus)
    status (read‑only): {
      phase: enum ["idle","preflight","canary","postUpgrade"]
      decision: enum ["n/a","pending","proceed","abort","rollback"]
      currentUpgradeSessionId: string
      currentUpgradeRef: { operationId, correlationId, scope: enum ["agentPool","cluster"], agentPool?: string, requestedVersion: string }
      breaches: [{ at, ruleGroupId, ruleName, observed, threshold, phase, action }]
      updatedAt: RFC3339
    }
  evaluations (child, read‑only): keyed by upgradeSessionId with per‑phase decisions and breaches

ARM operations (multiple named gates per cluster)
- Child (cluster, per gate name):
  - PUT /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGatesReferences/{gateName}?api-version=2024-09-01
  - GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGatesReferences/{gateName}?api-version=2024-09-01
  - DELETE /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGatesReferences/{gateName}?api-version=2024-09-01
  - GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGatesReferences/{gateName}/evaluations?api-version=2024-09-01
  - GET /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGatesReferences/{gateName}/evaluations/{upgradeSessionId}?api-version=2024-09-01
- Reusable upgrade gates (spec only):
  - PUT/GET/DELETE /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/upgradeGates/{gateName}?api-version=2024-09-01

Prometheus Linkage
- Provide full ARM IDs for rule groups in `prometheus.ruleGroups[].id`.
- Optional `rules[].name` enables per‑rule overrides; unspecified rules inherit the gate‑level default.
- Gate‑level `evaluation.consecutiveBreachesRequired` is optional debounce applied by the gate; it does not change alert sources. If you don’t want a rule to halt upgrades, tune it at source or override per‑rule here.

Identity & RBAC
- Runtime identity (cluster managed identity / AKS service identity) reads rule groups during evaluation.
- Required permission on each referenced rule group scope: `Microsoft.AlertsManagement/prometheusRuleGroups/read`.
- Validation on PUT checks existence/readability by the runtime identity; failures return 400 (invalid ID) or 403 (forbidden) with actionable diagnostics.

Sample (request → response)
- Bind a named gate reference to a reusable upgrade gate on a cluster

```http
PUT https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{cluster}/upgradeGatesReferences/prod-slo?api-version=2024-09-01
Content-Type: application/json
{
  "properties": {
    "enabled": true,
    "upgradeGate": {
      "id": "/subscriptions/{sub}/resourceGroups/{rgShared}/providers/Microsoft.ContainerService/upgradeGates/prod-slo"
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
    "upgradeGate": { "id": "/subscriptions/{sub}/resourceGroups/{rgShared}/providers/Microsoft.ContainerService/upgradeGates/prod-slo" },
    "status": { "phase": "idle", "decision": "n/a" }
  }
}
```

### CLI Experience

Reusable upgrade gates (peer resource)
- Create:
  az aks upgrade-gates reusable create -g {rgShared} -n {gateName} --preflight 10 --canary 20 --post-upgrade 60 --consecutive 2 --action abort --prom-rule-group-ids "/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.AlertsManagement/prometheusRuleGroups/{ruleGroupName}" --prom-rule-names HighErrorRate P95LatencySpike
- Update:
  az aks upgrade-gates reusable update -g {rgShared} -n {gateName} --action rollback
- Show/Delete:
  az aks upgrade-gates reusable show -g {rgShared} -n {gateName}
  az aks upgrade-gates reusable delete -g {rgShared} -n {gateName}

Cluster bindings (gate references on a cluster)
- Bind to a reusable gate:
  az aks upgrade-gates reference set -g {resourceGroupName} -n {clusterName} --gate {gateName} --gate-id "/subscriptions/{subscriptionId}/resourceGroups/{rgShared}/providers/Microsoft.ContainerService/upgradeGates/{gateName}" --enable true
- Create/Update with inline spec:
  az aks upgrade-gates reference set -g {resourceGroupName} -n {clusterName} --gate app-slo --enable true --preflight 10 --canary 20 --post-upgrade 60 --consecutive 2 --action abort --prom-rule-group-ids "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.AlertsManagement/prometheusRuleGroups/{ruleGroupName}" --prom-rule-names HighErrorRate P95LatencySpike
- List/Show current gate references:
  az aks upgrade-gates reference list -g {resourceGroupName} -n {clusterName}
  az aks upgrade-gates reference show -g {resourceGroupName} -n {clusterName} --gate {gateName}
- List/Show evaluations for a gate:
  az aks upgrade-gates evaluations list -g {resourceGroupName} -n {clusterName} --gate {gateName}
  az aks upgrade-gates evaluations show -g {resourceGroupName} -n {clusterName} --gate {gateName} --session-id {upgradeSessionId}
- Delete a gate reference:
  az aks upgrade-gates reference delete -g {resourceGroupName} -n {clusterName} --gate {gateName}

### Portal Experience

- Reusable Upgrade Gates (resource level): Create and manage `upgradeGates/{gateName}` under a subscription/resource group. Form fields: name, evaluation windows (preflight/canary/post-upgrade), on-breach action (abort or rollback), Managed Prometheus rule groups, and optional per-rule consecutive overrides.
- Cluster Gate References (cluster level): Under a cluster’s Upgrade > Guardrails, manage `upgradeGatesReferences`. Add a gate by name, choose Bind to reusable gate (resource picker) or Inline configuration, toggle Enable, and save. Grid shows name, bound gate (if any), enablement, phase/decision, and last updated. Each row links to Evaluations history and diagnostics.
- Note: Rollback during post-upgrade is only possible within the Blue/Green Nodepool Soak TTL; if post-upgrade minutes exceed TTL, breaches will abort.

### Policy Experience

- Built-ins to: (1) require ≥1 gate reference on production clusters, (2) restrict allowed `upgradeGates` IDs for binding, (3) constrain `actions.onBreach` (e.g., disallow rollback in prod), and (4) enforce minimum preflight/canary/post-upgrade minutes.
- Aliases (illustrative):
  - Microsoft.ContainerService/managedClusters/upgradeGatesReferences[*].properties.enabled
  - Microsoft.ContainerService/managedClusters/upgradeGatesReferences[*].properties.upgradeGate.id
  - Microsoft.ContainerService/managedClusters/upgradeGatesReferences[*].properties.evaluation.preflightMinutes
  - Microsoft.ContainerService/managedClusters/upgradeGatesReferences[*].properties.evaluation.canaryMinutes
  - Microsoft.ContainerService/managedClusters/upgradeGatesReferences[*].properties.evaluation.postUpgradeMinutes
  - Microsoft.ContainerService/managedClusters/upgradeGatesReferences[*].properties.actions.onBreach

# Definition of Success

## Expected Impact: Business, Customer, and Technology Outcomes, Experiments + Measures

| No. | Outcome | Measure | Target | Priority |
|-----|---------|---------|--------|----------|
| 1 | Adoption in prod | % of prod clusters with ≥1 gate reference | ≥60% (Preview), ≥85% (GA) | P0 |
| 2 | Safer upgrades | Safe-completion rate without escaped SLO breach | +30% uplift vs baseline | P0 |
| 3 | Fast detection | Decision loop latency P95 | ≤2 minutes | P0 |
| 4 | Signal quality | False-positive breach rate | ≤5% | P1 |
| 5 | Auditability | % of upgrades with complete evaluations/breaches recorded | ≥99% | P1 |

# Requirements

## Functional Requirements

| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | Support multiple named `upgradeGatesReferences/{gateName}` per cluster | P0 |
| 2 | Bind to reusable `upgradeGates/{gateName}` or supply inline spec | P0 |
| 3 | Per-rule consecutive breach overrides with gate-level default | P0 |
| 4 | Expose evaluations history per upgrade session and gate | P0 |
| 5 | Fail-closed on telemetry unavailability with actionable diagnostics | P0 |
| 6 | Azure Policy/RBAC targeting on child path | P0 |
| 7 | Support post-upgrade phase with configurable minutes | P0 |
| 8 | Support on-breach actions: abort (all scopes) and rollback (agent pools) with graceful fallback | P0 |

## Test Requirements

| No. | Requirement | Priority |
|-----|-------------|----------|
-| 1 | End-to-end canary breach pauses/aborts per action policy | P0 |
+| 1 | End-to-end canary breach aborts or rolls back per action policy | P0 |
| 2 | Blue/green rollback within Nodepool Soak TTL triggers correctly | P0 |
| 3 | RBAC/validation rejects unreadable rule group IDs | P0 |
-| 4 | Evaluations/breaches are durable and queryable | P1 |
+| 4 | Evaluations/breaches are durable and queryable | P1 |

# Appendix: FAQ

- Why model this as a child resource instead of an inline cluster property?
  - Clear, queryable status (config + live state in one GET), first-class RBAC/policy targeting, independent lifecycle/versioning from the core cluster spec.

- Why support multiple named gates instead of a singleton?
  - Separation of concerns (e.g., platform vs app SLOs), incremental rollout by domain, and reuse of shared gates without forcing all signals into one gate. Policy can still constrain allowed names/ids to prevent sprawl.

- Can I target specific alert rules within a rule group?
  - Not in v1. All alerting rules in the provided rule groups are enforced. Use granular rule groups to scope if needed.

- Why only Azure Managed Prometheus in v1 and not self-hosted Prometheus or Azure Monitor alerts?
  - Adoption (~48% of clusters), lowest integration/identity complexity, fastest path to value. We can add Azure Monitor alerts and self‑hosted endpoints in later phases.

- Does this gate control plane upgrades?
  - Control plane honors abort-only semantics; no rollback. Agent pool upgrades can optionally rollback when Blue/Green is enabled.

- How do you reduce false positives/noise?
  - Consecutive breach counts, warm‑up suppression in preflight, debounce windows, and explicit customer-selected signals.
  
- What should I do if a noisy alert keeps blocking upgrades?
  - a) Reconfigure the Prometheus alert appropriately (e.g., adjust thresholds, duration/for, lookback, labels/routing) to better reflect SLO intent.
  - b) Remove the alert from the gate’s inputs by updating API references: stop referencing the rule group containing that alert, or split it into a granular rule group not referenced by the gate, then update the gate reference accordingly.

- What happens if the rule group API is temporarily unavailable?
  - Fail-closed to abort with diagnostics; customers can retry once availability is restored.

- How do I find the rule group resource ID safely?
  - Copy from the rule group’s JSON in Portal/ARM. Use placeholders in docs. Provide full ARM IDs in automation (Policy/CLI/IaC).

- Can I reuse one guard configuration across many clusters?
  - Yes. Author a reusable `Microsoft.ContainerService/upgradeGates/{gateName}` and bind clusters via the child `upgradeGatesReferences/{gateName}` with `properties.upgradeGate.id`.

- Does this replace blue/green upgrades?
  - No. It complements them by adding app SLO gating to preflight/canary/post‑upgrade phases and optional rollback.

- Why have "breaches" in addition to "evaluations"?
  - Evaluations are periodic snapshots of rule status per phase used to drive the gate; breaches are immutable events recorded when a gating condition is met (after debounce/consecutive counts), including observed vs threshold and action.
  - Breaches provide durable auditability even if the alert clears by the next evaluation; they show exactly what triggered abort/rollback with timestamps and upgrade identifiers.
  - Breaches are compact and queryable for automation/compliance (e.g., "did any breach occur in session X?"), whereas evaluations can be numerous and transient.
  - Breaches capture fail-closed cases (e.g., telemetry outage) as synthetic events with a reason; evaluations may be absent or partial in such cases.
  - UX separation: surface breaches in summary banners; use the evaluations timeline for deep-dive analysis.

- How does this relate to Fleet and Service Fabric upgrade gates?
  - Fleet Manager: Fleet provides orchestration and policy at fleet scope. Our gates focus on per-cluster upgrade safety with ARM‑first governance; reusable gates enable fleet‑wide consistency without cross‑cluster orchestration.
    - References: [Azure Kubernetes Fleet Manager documentation](https://learn.microsoft.com/azure/kubernetes-fleet/), [Overview](https://learn.microsoft.com/azure/kubernetes-fleet/overview)
  - Service Fabric: Similar gate concept (named gates, per‑rule semantics, durable events) but AKS surfaces gates as ARM child resources with Managed Prometheus integration and Kubernetes‑specific phases (preflight/canary with soak handled outside the gate).
    - References: [Service Fabric application upgrades](https://learn.microsoft.com/azure/service-fabric/service-fabric-application-upgrade), [Service Fabric cluster upgrades](https://learn.microsoft.com/azure/service-fabric/service-fabric-cluster-upgrade)

- How do gates interact with node and nodepool soak?
  - Separation of concerns: Soak controls pacing; gates control safety. There are no soak knobs in the gate API.
  - Rolling agent pools: Per-node Node Soak is configured on the upgrade engine and only affects speed; gate decisions are independent.
  - Blue/Green: Nodepool Soak TTL bounds rollback. Post-upgrade monitoring can exceed TTL, but after TTL any breach will abort even if action=rollback. For rollback coverage, set post-upgrade minutes ≤ TTL.
  - Control plane: No rollback. Gates still evaluate preflight/post-upgrade (canary optional or 0); any configured rollback falls back to abort.

