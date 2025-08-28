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

Before this feature, AKS customers had to hand‑craft blue/green flows and stitch alerts to decide whether to proceed or stop upgrades. Now, AKS customers can declare application SLO guardrails using Azure Managed Prometheus rule groups that the upgrade process enforces with preflight, canary, and post‑upgrade checks to automatically abort—or roll back for agent pools—on anomalies.

## Problem Statement / Motivation

AKS validates readiness (PDBs, quota, API breaks) but misses nuanced or delayed post‑upgrade degradations. For many, an upgrade feels like an atomic, black‑box operation with limited control. In Rolling nodepool upgrades, operators must watch their own metrics and manually time an abort with higher toil and risk. The upcoming Blue/Green flow adds soak and batch drain/cutover mechanics, but it still lacks metrics‑based intervention; there are no first‑class gates to automate proceed/abort/rollback. The gap: upgrade‑integrated, SLO‑aware guardrails.

We also need first-class pre-upgrade gates for control plane upgrades (abort-only) so platform and application SLOs can be validated before any control plane changes are applied. Control plane gates are abort-only (no rollback) but allow operators to prevent risky control-plane operations when SLOs are not satisfied.

Example problems observed during/after upgrade:
- Latency regressions after upgrade
- Error‑rate spikes after version/image changes
- Pods crashing/oomkilling minutes or hours after node moves
- Cascading issues that surface progressively across components

## Goals/Non-Goals

### Functional Goals

- Deliver SLO-gated AKS upgrades across preflight, canary, and post-upgrade phases.
- Evaluate control plane upgrades with pre- and post- gates that make abort-only decisions (no rollback).
- Act on breaches with abort or, where supported, safe rollback for agent pools.
- Provide reusable, policy- and RBAC-governed guardrail configurations for consistency across clusters and services.
- Leverage Azure Managed Prometheus signals to declare SLOs without new instrumentation; support AKS-managed service mesh (Istio) with mesh-level SLOs exposed via Prometheus.
- Ensure resilient evaluation and a clear, durable audit of gating decisions and breaches.
- Offer first-class observability for gates: concise status, decision timelines, and exportable breach events available via CLI/Portal/APIs for audit and automation.
- Provide guided troubleshooting with root-cause hints and next steps, plus improved documentation (how-tos, examples, best practices) for authoring, tuning, and operating gates at scale.
- Work across upgrade strategies (rolling and blue/green) and agent pool types, independent of soak/pacing settings, and compatible with maintenance windows.

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
| 3. Managed‑first guardrails | Tighter integration, no external endpoints, leverages existing investments; Azure Managed Prometheus present on ~15% of clusters today → meaningful coverage from day one | Leaves Azure Monitor alerts and self‑hosted Prometheus for a later phase | Recommended |
| 4. Guardrails (source‑agnostic) | Meets all users (Managed + self‑hosted + external) | Broader integration surface slows delivery; more security surface | Defer |
+ | 5. ClusterHealth Custom Resource / HealthStatus API (Custom Resource approach) | Extensible, cluster-local aggregation of arbitrary health signals (CRs, health endpoints, Prom exporters); enables third parties and customer workloads to publish health entries directly into cluster; natural fit for controllers and runtime integrations | Requires kube-level controller, RBAC and lifecycle management; introduces additional runtime surface and operational complexity; ARM-only consumers need bridging; potential adoption friction for brownfield clusters without controllers | Consider as Phase-2 extension |

### Option 5 (details): ClusterHealth CR / HealthStatus API
Description:
- Introduce a small, versioned Kubernetes Custom Resource Definition (CRD) such as `ClusterHealthEntry` and an aggregator controller that synthesizes a `ClusterHealth` status. Any component (control plane, addon, third‑party operator, or customer workload) can create or update `ClusterHealthEntry` objects to signal local health. The Mesh/Upgrade RP (or Health Monitor) reads the aggregated `ClusterHealth` status during pre/during/post phases to drive gate decisions.

Pros:
- Generic & extensible: supports arbitrary health signals without adding n special-case hooks to the gate API.
- Runtime-friendly: cluster-local controller enables low-latency evaluations, works offline of ARM for rapid decisions, and is natural for third‑party integrations.
- Broad compatibility: can coexist with Prometheus rule‑group integration — a Prom exporter or small adapter can surface PromRuleGroup states as `ClusterHealthEntry` objects.
- Enables richer UX: customers can author CRs or use existing operators to report health; Gate definitions can reference aggregated ClusterHealth status or individual entry selectors.

Cons:
- Operational complexity: requires deploying and operating a controller, CRD lifecycle, RBAC scopes, versioning and upgrade management.
- Deployment surface: brownfield customers may not want additional controllers; adds burden for clusters without standard addon pipelines.
- ARM/RP bridging: ARM-native workflows (purely ARM + RP driven) must rely on a bridge/adapter to surface CR status to ARM APIs; adds integration work and failure modes.
- Security considerations: write access to health CRs becomes sensitive — need auth model, signer identity, and abuse mitigation.

UX and API implications (designer notes):
- Gate Definition: keep a single, simple gate resource that references one or more signal backends (e.g., PromRuleGroup IDs, ClusterHealth selector, webhook). Internally the Health Monitor will evaluate the referenced backends at pre/during/post points.
- Pre/During/Post semantics: data plane upgrades (agent pools, mesh) should evaluate gates at three points — preflight (baseline), during (per-batch/canary boundaries), and post-upgrade (soak). Control plane upgrades remain pre/post only (abort-only). The CR approach naturally supports this cadence by exposing current cluster health at evaluation time.
- Prometheus as a flavor: implement PromRuleGroup adapter that writes `ClusterHealthEntry` objects (or that the controller polls) so Prom integration is available immediately while preserving a path to generic CR-based signals.
- Minimal required ask from customers: none if they use Prom integration; for generic integrations, customers or vendors can implement an adapter or emit ClusterHealthEntry CRs via existing operators.

Recommendation & next steps:
- Keep PromRuleGroup integration as the Phase 1 delivery to maximize immediate adoption and minimize friction.
- Parallel design work: draft a minimal ClusterHealth CRD + aggregator controller design as Phase 2 exploration (include RBAC, auth, rate limits, and CR lifecycle). Prototype a Prom→CR adapter to validate the integration pattern.
- Surface the extensibility story in the PRD: add a short note that Prom is the first supported signal backend and that the gate model is extensible to CR-based and webhook-based signals in future phases.

Pricing: Included; standard Azure Monitor/Prometheus costs apply.

False positives/noise mitigation: consecutive breaches, warm‑up suppression, debounce windows, cooldowns, and customer‑selected signals only.

Security posture: Platform-native integration; no customer-managed endpoints or secrets required.

Soak vs Gate (concise)
- Rolling agent pools: Node Soak (inter-node delay) remains an upgrade engine setting and does not appear in the gate API; gates still run preflight/canary/post-upgrade on their timers.
- Blue/Green: Nodepool Soak TTL bounds rollback. Gates can monitor longer, but after TTL, any breach will abort even if action=rollback.
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

### Phases and batch sizing (clarification)
- Preflight
  - Validates baseline application and platform health before any changes are applied.
  - Reads existing SLO signals without modifying capacity.
  - Outcome: proceed or stop.

- Canary
  - Evaluates an explicit early slice to catch regressions before broad exposure.
    - Batch definition by strategy:
      - Rolling: a batch equals the MaxSurge set processed together.
      - Blue/Green: a batch equals the drainBatchSize drained from Blue and prepared on Green.
    - Modes:
      - Time-based: after the first batch, observe for canaryMinutes before proceeding.
      - Per-batch: gate the first N batches; pause at each batch boundary for canaryMinutes.
    - Outcome: proceed, abort, or rollback (agent pools) when supported; in Blue/Green, rollback is honored only within the Nodepool Soak TTL, otherwise abort.

- Post-upgrade
  - Observes the system after rollout/cutover to catch delayed failures (e.g., latency, errors, memory).
  - In blue/green, rollback is only possible within the configured soak period; beyond that, breaches stop the run.
  - Control plane is stop-only (no rollback).

- Operator guidance
  - Use minimal but meaningful observation windows; adjust as signal quality proves out.
  - Target only SLO-critical alerts to reduce noise.
  - Apply debounce/consecutive-breach patterns and tune alerts at the source when needed.


### Operator Journeys (Scenarios)

#### Examples with timelines (mock)


### API


ARM operations (multiple named gates per cluster)


Prometheus Linkage

Identity & RBAC


Sample (request → response)

### CLI Experience


### Portal Experience


### Policy Experience


# Definition of Success

## Expected Impact: Business, Customer, and Technology Outcomes, Experiments + Measures



# Requirements

## Functional Requirements



## Test Requirements



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



