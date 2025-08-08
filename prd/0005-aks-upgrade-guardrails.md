---
title: AKS Upgrade Guardrails: SLO‑Gated, Metric‑Aware Upgrades
wiki: ""
pm-owners: [kaarthis]
feature-leads: []
authors: [kaarthis]
stakeholders: []
approved-by: []
status: Draft
last-updated: 2025-08-08
---

# Overview

Before this feature, AKS customers had to hand‑craft blue/green flows and stitch alerts to decide whether to proceed or stop upgrades. Now, AKS customers can declare application SLO guardrails (Azure Monitor alerts and Prometheus rules) that the upgrade process enforces with canary and soak checks to automatically pause or abort on anomalies.

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
  - Azure Monitor alert rules (resource IDs)
  - Prometheus (Managed Prometheus or external) via rule names or PromQL
- Support preflight, canary, and post‑upgrade soak windows
- On breach: pause or abort; optionally trigger agent pool rollback when available
- Log gating decisions/breaches for audit and diagnostics
- Azure Policy enablement to require guardrails in production
- Scope: Applies to regular rolling upgrades and to Blue/Green agent pool upgrades when available
- Node pool coverage: Supported for VMSS and VM‑based node pools

### Non-Functional Goals
- Guard decision loop P95 ≤ 2 minutes
- Security: https endpoints only; domain allowlist for external Prom; MSI for Azure Monitor; secrets via Key Vault refs
- Reliability: guard evaluation availability ≥ 99.9% during upgrades
- Telemetry & Cost: adoption, latency, breach precision/false‑positive rate; publish per‑upgrade evaluator cost model (API calls/data scan, est. $/upgrade) for capacity planning

### Non-Goals
- No full blue/green traffic orchestration
- No control plane rollback (unsupported); agent pool rollback only when available
- No auto‑remediation of applications
- Does not replace AKS Blue/Green nodepool upgrades; complements them with SLO gating

## Narrative/Personas

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Developer / Cluster Owner | Microsoft.ContainerService/managedClusters/write; Microsoft.AlertsManagement/alerts/read | Reference existing alerts or Prom rules; upgrade pauses/aborts on breach. Success: No SLO breach escapes an upgrade. |
| Platform Operator | Microsoft.ContainerService/managedClusters/*; Microsoft.AlertsManagement/alerts/*; Microsoft.Insights/* | Define org defaults; enforce via policy; monitor compliance. Success: Safe upgrades at scale without bespoke pipelines. |

## Customers and Business Impact



Current Customer Impact (baseline):
- High number of upgrade-related support cases tied to workload breakage or post-upgrade latency/performance regressions (issues surface after completion rather than during).
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

AKS upgrades can now honor your application SLOs. Reference Azure Monitor alert rules or Prometheus rules, configure canary/soak windows, and AKS will pause or abort upgrades on anomalies—no bespoke pipelines required. Public preview for agent pool upgrades this release; GA to follow after feedback.

**Addressing Key Challenges**
- Nuanced regressions (latency, error rate, delayed OOMs) missed by readiness checks
- High operational cost of bespoke blue/green pipelines; lack of governance
- Noise/false positives when alerts aren’t evaluated with warm‑up/debounce logic

**Functionality and Usage**
- Configure guardrails via API/CLI/Portal using existing Azure Monitor alerts and/or Prometheus rules
- Evaluate in preflight, canary, and post‑upgrade soak windows; on breach → pause/abort; optional agent pool rollback
- Works with AKS Blue/Green nodepool upgrades: guardrails gate canary and pre‑cutover phases

**Availability**
- Public Preview: agent pool upgrades (VMSS and VM node pools); control plane uses pause‑only (no rollback)
- GA target: adds built‑in policies and Managed Prometheus first‑class integration
- Blue/Green nodepool upgrades available later this year; guardrails complement, not replace

## Proposal

Options considered (concise):
1) Status quo (manual). No change; risk persists.  
2) Portal‑only checks. UI convenience, no IaC/policy.  
3) Native guardrails (Managed Prometheus only). Simplifies integration but excludes self‑hosted/external alert sources.  
4) Native guardrails (source‑agnostic, recommended). Supports Azure Managed Prometheus, self‑hosted Prometheus, and external providers.

**Options and Trade‑offs (concise)**
| Option | Pros | Cons | Decision |
|-------|------|------|----------|
| 1. Status quo | Zero engineering | Incidents persist; no governance | Rejected |
| 2. Portal‑only | Faster UX uplift | No IaC/policy; not automatable | Rejected |
| 3. Managed‑only guardrails | Simpler integration; tighter UX | Excludes ~14–15% self‑hosted Prom users; large enterprises depend on self‑hosted; Managed Prom adoption is low (≈2%) | Rejected |
| 4. Guardrails (source‑agnostic) | Meets customers where they are (Managed + self‑hosted + external); uses existing alerts; IaC + policy; composable | Broader integration surface | Recommended |

Rationale for 4: Adoption reality (self‑hosted Prom widely used by large enterprises; Managed Prom lukewarm). Source‑agnostic design minimizes friction, leverages existing alerts, integrates with the upgrade lifecycle, and scales with policy without forcing stack migration.

Breaking changes: None (opt‑in).  
Go‑to‑market: Preview (agent pools), iterate; GA with Azure Policy + Managed Prometheus first‑class.  
Pricing: Included; standard Azure Monitor/Prometheus costs apply.

False positives/noise mitigation: consecutive breaches, warm‑up suppression, debounce windows, cooldowns, and customer‑selected signals only.

Security posture: External endpoints require https + allowlisted domains; auth via Key Vault or workload identity; Azure Monitor via MSI.

## User Experience 

### API
Delta on Managed Cluster/Agent Pool upgrade policy (abbreviated):

```json
{
  "properties": {
    "upgradePolicy": {
      "healthGuards": {
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
        "azureMonitor": {
          "scopeResourceId": "/subscriptions/.../resourceGroups/.../providers/Microsoft.ContainerService/managedClusters/...",
          "alertRuleIds": [
            "/subscriptions/.../providers/Microsoft.AlertsManagement/smartDetectorAlertRules/latency",
            "/subscriptions/.../providers/microsoft.insights/scheduledQueryRulesClients/error-rate"
          ]
        },
        "prometheus": {
          "mode": "managed",
          "ruleNames": ["HighErrorRate", "P95LatencySpike"]
        }
      }
    }
  }
}
```
**Property Explanations (concise)**
- healthGuards.enabled: Master switch for SLO‑gated upgrades.
- evaluation.preflightMinutes: Warm‑up/validation before any drain; avoids cold‑start noise.
- evaluation.canaryMinutes: Limited drain/traffic phase to catch early regressions.
- evaluation.soakMinutes: Post‑upgrade observation window to detect delayed/cascading issues.
- evaluation.consecutiveBreachesRequired: Debounce against transient spikes; reduces false positives.
- actions.onBreach: Pause or abort policy to control upgrade flow.
- actions.onBreachAgentPool.rollbackEnabled: If Blue/Green used, map breach to pool revert.
- azureMonitor.scopeResourceId: Scope for alert discovery/evaluation.
- azureMonitor.alertRuleIds: Concrete SLO signals to enforce (latency, error rate, etc.).
- prometheus.mode: managed or external source of rules.
- prometheus.ruleNames: Named alert/rules evaluated during upgrade (Prometheus).

Validation (musts):
- If enabled, at least one source (azureMonitor or prometheus) provided
- Control plane: onBreach → pause only; Agent pool: optional rollback
- External Prom: https + allowlisted domain; auth reference must resolve
- Agent pool rollback reverts to prior pool when supported

### CLI Experience
- Enable with Azure Monitor + Prometheus:
  - `az aks upgrade -g rg -n c --kubernetes-version X --enable-upgrade-guards \
     --guards-preflight 10 --guards-canary 20 --guards-soak 60 --guards-consecutive 2 \
     --guards-action pause \
     --guards-azmon-scope <resourceId> --guards-azmon-alert-ids id1 id2 \
     --guards-prom-mode managed --guards-prom-rule-names HighErrorRate P95LatencySpike \
     --guards-agentpool-rollback true`
- Inspect last decision/breach: `az aks upgrade-guards show -g rg -n c`

### Portal Experience
- Upgrade wizard: “SLO guardrails” toggle
- Select Azure Monitor alert rules and/or Prometheus rules
- Configure evaluation windows and breach action; optional agent pool rollback
- Preview panel shows checks and stop conditions; post‑run diagnostics blade shows decisions
- In Blue/Green nodepool mode, guardrails gate canary and pre‑cutover; on breach, abort or rollback to the previous pool

### Policy Experience
- Built‑ins:
  - Require healthGuards.enabled=true for env=prod (alias: Microsoft.ContainerService/managedClusters/upgradePolicy.healthGuards.enabled)
  - Audit missing critical alerts (latency/error rate) in prod (aliases: Microsoft.ContainerService/managedClusters/upgradePolicy.healthGuards.azureMonitor.alertRuleIds[*], Microsoft.ContainerService/managedClusters/upgradePolicy.healthGuards.prometheus.ruleNames[*])
  - Deny external endpoints not on org allowlist
  - DeployIfNotExists to stamp org defaults at subscription/management group (set via aliases: .../healthGuards.enabled, .../healthGuards.evaluation.preflightMinutes|canaryMinutes|soakMinutes|consecutiveBreachesRequired, .../healthGuards.azureMonitor.scopeResourceId, .../healthGuards.prometheus.mode)
- AKS Automatic upgrades (POV defaults):
  - Prod: enable guardrails by default with baseline windows (preflight=10m, canary=20m, soak=60m, consecutive=2) and required signals (latency + error rate). Opt‑out via policy exemption.
  - Non‑prod: disabled by default; allow opt‑in at cluster or policy scope.
  - Subscription/fleet policy may override with org‑specific windows and alert templates.

# Definition of Success 

## Expected Impact: Business, Customer, and Technology Outcomes, Experiments + Measures 

| No. | Outcome | Measure | Target | Priority |
|-----|---------|---------|--------|---------|
| 1 | Fewer upgrade‑induced incidents | Post‑upgrade Sev2+ tied to upgrades | -50% in 6 months | High |
| 2 | Safer, faster upgrades | % upgrades without manual pauses | +30% in 2 quarters | High |
| 3 | Adoption | % prod clusters with guardrails enabled | 70% in 2 quarters | High |
| 4 | Detection quality | Breach precision (TP/(TP+FP)) | ≥80% | High |
| 5 | Latency | Guard decision loop P95 | ≤2 min | Medium |

# Requirements 

## Functional Requirements 

| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | API/CLI/Portal to configure healthGuards on upgrades | High |
| 2 | Azure Monitor alert rule integration (IDs, scope) | High |
| 3 | Prometheus integration (Managed + external with secure auth) | High |
| 4 | Evaluation windows: preflight, canary, soak; consecutive breach logic | High |
| 5 | Actions: pause/abort; agent pool rollback toggle | High |
| 6 | Decision logging and diagnostics (who/what/why halted) | High |
| 7 | Policy controls (require/deny/audit/deployIfNotExists) | Medium |
| 8 | Safety levers: warm‑up suppression, debounce, cooldown | Medium |
| 9 | External endpoint security: TLS, domain allowlist, Key Vault auth | High |

## Test Requirements 

| No. | Requirement | Priority |
|-----|-------------|----------|
| 1 | E2E across sources (Azure Monitor/Managed Prom/external Prom) | High |
| 2 | Load: parallel upgrades with guardrails (1k pools) | High |
| 3 | False‑positive resilience: debounce/consecutive windows | High |
| 4 | Security: endpoint validation, secret access via KV/MI | High |
| 5 | Control plane vs agent pool behavior differences | Medium |
| 6 | Rollback path upon breach during agent pool upgrade | High |

# Dependencies and risks 

| No. | Requirement or Deliverable | Giver Team / Contact |
|-----|----------------------------|----------------------|
| 1 | Azure Monitor Alerts APIs and permissions model | Azure Monitor |
| 2 | Managed Prometheus rule/alert discovery APIs | Azure Monitor |
| 3 | ARM schema & SDK updates | ARM/SDK |
| 4 | CLI and Portal updates | Azure CLI / AKS Portal |
| 5 | Agent pool rollback integration for prior‑pool revert mapping | AKS Runtime |

Key risks and mitigations:
- False positives/noise → consecutive breaches, warm‑up, debounce, cooldown
- External endpoint reliability/security and operational failures → TLS + allowlist; read‑only creds via Key Vault; timeouts + backoff; default‑to‑pause on evaluator/connector errors; documented SRE runbook; RBAC/approval‑gated manual resume
- Control plane lack of rollback → pause with clear guidance; no auto‑rollback
- Alert quality variance → provide baseline templates for latency/error SLOs

# Compete 

## GKE 
- Surge/node pool upgrades and maintenance windows; no native app SLO‑gated upgrade integration with customer alerts
- Docs: https://cloud.google.com/kubernetes-engine/docs/how-to/node-pool-upgrade, https://cloud.google.com/kubernetes-engine/docs/concepts/maintenance-windows

## EKS
- Blue/green via add‑ons/partner tools; no first‑class upgrade gating on customer SLO alerts
- Docs: https://docs.aws.amazon.com/eks/latest/userguide/managed-node-update-behavior.html, https://docs.aws.amazon.com/eks/latest/userguide/migrate-stack-to-new-nodegroup.html

Competitive advantage: AKS integrates customer‑defined SLO guardrails directly into the managed upgrade workflow (API/CLI/Portal/Policy), reducing risk without bespoke pipelines.

## Appendix: FAQ (Concise)

Q: Why support self‑hosted Prometheus instead of only Azure Managed Prometheus?
- A: Customer reality and scale. ~14–15% run self‑hosted Prom today, including large enterprises (e.g., Kaiser, BlackRock, Morgan Stanley). Reasons: control, air‑gapped/regulatory environments, existing alert taxonomy, and cost locality. Guardrails must meet customers where they are while still offering first‑class Managed Prom integration.

Q: How is Azure Managed Prometheus adoption? Will this feature push it forward?
- A: Lukewarm as of Aug 2023 (≈2% external and ≈2% internal clusters; ref: AKS Observability Dashboard). Guardrails are source‑agnostic to avoid gating adoption on a single stack. We expect neutral to modest uplift via: (1) published SLO alert templates, (2) smoother rule discovery in Portal, (3) policy packs. Primary value is safety; not a Managed Prom growth lever by itself.

Q: What if customers do not host a Prom server in‑cluster and have no accessible endpoint?
- A: Options:
  1) Port critical alerts to Azure Monitor workspace alerts (Phase 2 with AzMon; documented mappings and templates).
  2) Use Container Insights‑based alerts where equivalent signals exist.
  3) Expose a secured endpoint (e.g., Private Link/allowlist) for evaluation. If none of the above is possible, guardrails cannot evaluate Prom‑based signals in Preview.

Q: Why not rely on liveness/readiness (healthz/livez) instead of BYO Prom/alerts?
- A: Probes are per‑pod and narrow in scope; they miss latency/error SLO regressions, delayed resource pressure, and cascading issues. Aggregated, SLO‑oriented alerts (Prom/Log‑based) are better discriminators for upgrade gating.

Q: Can external endpoints work with vendors beyond Prometheus (Datadog, etc.)?
- A: Yes. The API is vendor‑agnostic: any provider that can expose a boolean evaluation (breach true/false) over HTTPS can participate. Multiple endpoints are supported; future connectors can improve ergonomics.

Q: How do we authenticate and evaluate alerts behind private endpoints?
- A: Patterns:
  - HTTPS + allowlisted domain with auth via Key Vault secret or workload identity (when reachable).
  - Private Link exposure for evaluation traffic from AKS control plane.
  - Phase 2: in‑cluster evaluator job/add‑on (design analogous to kured) that runs checks locally and reports status back to the upgrade controller.

Q: How do we reduce false positives so upgrades don’t abort on unrelated signals?
- A: Design guardrails include warm‑up, debounce, cooldown, and consecutive breach thresholds. Additionally, platform correlation is recommended: AKS emits a binary metric for upgraded nodes (e.g., node.upgrade.inProgress{node}=1 during upgrade). Teams correlate their SLO alert with this metric to isolate upgrade‑attributed regressions (signal rises only on upgraded nodes). This materially increases precision over ambient alerts.

References:
- kured (reboot coordination) design patterns: https://kured.dev/
